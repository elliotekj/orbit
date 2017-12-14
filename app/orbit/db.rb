require_relative 'post.rb'

class OrbitDB
  attr_accessor :posts, :categories, :src_path, :content_folder

  def initialize(options)
    @content_path = File.join(options['src_path'], "content/#{options['content_folder']}")
    @post_minimal_metadata = []
    @categories = []
  end


  # Public: Gets all of the data for the first `n` paths in @post_minimal_metadata.
  #
  # n - The number Integer of posts to return
  #
  # Returns an Array of posts in a metaWeblog compatible hash.
  def fetch_first(n)
    refresh_post_paths

    metaweblog_hashes = []
    posts_to_read = if n > @post_minimal_metadata.length
                      @post_minimal_metadata
                    else
                      @post_minimal_metadata[0..n]
                    end

    posts_to_read.each do |metadata|
      metaweblog_hashes.push(Post.get(metadata['path']))
    end

    metaweblog_hashes
  end

  private

  # Private: Rebuild the `post_minimal_metadata` array.
  def refresh_post_paths
    @post_minimal_metadata = []
    gather_post_minimal_metadata(@content_path)
  end

  # Private: Sets `@post_minimal_metadata`.
  #
  # path - The path String to recusively search
  #
  # Returns an Array of minimal metadata Hashes ordered by the `date` in the frontmatter.
  def gather_post_minimal_metadata(path)
    walk_posts_path(path)

    @post_minimal_metadata.sort_by! { |hash| hash['dateCreated'].strftime('%s').to_i }
    @post_minimal_metadata.reverse!

    @categories.unshift('[Orbit - Draft]')
    @categories.uniq!
  end

  # Private: Recursively walk the passed path looking for markdown files.
  #
  # path - The path String to recusively search
  def walk_posts_path(path)
    Dir.foreach(path) do |path_item|
      next if path_item =~ /^\.+$/ # Filter out `.` and `..`
      next if path_item =~ /^[\.]/ # Filter out hidden files

      full_path = File.join(path, path_item)

      if File.directory? full_path
        walk_posts_path(full_path)
      elsif File.file? full_path
        next unless path_item =~ /^.+(md|markdown|txt)$/
        single_markdown_file(full_path)
      end
    end
  end

  # Private: Handle a single markdown file found by `walk_posts_path`.
  #
  # path - The path String to the markdown file
  def single_markdown_file(path)
    frontmatter = Post.get_frontmatter(path)
    return if frontmatter.nil?

    @post_minimal_metadata.push(
      'path' => path,
      'dateCreated' => frontmatter['dateCreated']
    )

    @categories.concat(frontmatter['categories'])
  end
end
