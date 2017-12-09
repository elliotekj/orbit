require_relative 'post.rb'

class OrbitDB
  attr_accessor :posts, :categories, :src_path

  def initialize(options)
    @posts = []
    @categories = []
    @src_path = options['src_path']

    build_posts_db(File.join(@src_path, "content/#{options['content_folder']}"))
    build_categories_db
  end

  private

  def build_posts_db(path)
    walk_post_path(path)

    @posts.compact!
    @posts.sort_by! { |hash| hash['dateCreated'].strftime('%s').to_i }
    @posts.reverse!
  end

  def build_categories_db
    @categories.unshift('[Orbit - Draft]')
    @categories.uniq!
  end

  def walk_post_path(path)
    Dir.foreach(path) do |path_item|
      next if path_item =~ /^\.+$/ # Filter out `.` and `..`
      next if path_item =~ /^[\.]/ # Filter out hidden files

      full_path = File.join(path, path_item)

      if File.directory? full_path
        build_posts_db(full_path)
      elsif File.file? full_path
        next unless path_item =~ /^.+(md|markdown|txt)$/

        post = Post.get(full_path)
        next if post.nil?

        @posts.push(post)
        @categories.concat(post['categories'])
      end
    end
  end
end
