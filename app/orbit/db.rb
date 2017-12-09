require_relative 'post.rb'

class OrbitDB
  attr_accessor :posts, :categories, :src_path

  def initialize(src_path)
    @posts = []
    @categories = []
    @src_path = src_path

    read_all_posts(File.join(@src_path, 'content/post'))
    sort_posts_by_date
    make_categories_unique
  end

  private

  def read_all_posts(path)
    Dir.foreach(path) do |path_item|
      next if path_item =~ /^\.+$/ # Filter out `.` and `..`
      next if path_item =~ /^[\.]/ # Filter out hidden files

      full_path = File.join(path, path_item)

      if File.directory? full_path
        read_all_posts(full_path)
      elsif File.file? full_path
        next unless path_item =~ /^.+(md|markdown|txt)$/

        single_content = Post.parse(full_path)

        next if single_content.nil?

        @posts.push(single_content)
        @categories.concat(single_content['categories'])
      end
    end
  end

  def sort_posts_by_date
    @posts.compact!
    @posts.sort_by! { |hash| hash['dateCreated'].strftime('%s').to_i }
    @posts.reverse!
  end

  def make_categories_unique
    @categories.uniq!
  end
end
