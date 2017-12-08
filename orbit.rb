#!/usr/bin/ruby

# Reference
#
# - http://xmlrpc.scripting.com/metaWeblogApi.html
# - https://cyber.harvard.edu/rss/rss.html#hrelementsOfLtitemgt
# - https://github.com/tominsam/jekyll-metaweblog
# - https://gist.github.com/brentsimmons/9398899
# - https://github.com/stevenschobert/inkplate
# - https://codex.wordpress.org/XML-RPC_MetaWeblog_API
# - https://web.archive.org/web/20051103060716/http://www.xmlrpc.com:80/spec
# - https://codex.wordpress.org/XML-RPC_WordPress_API

# Imports

require 'rubygems'
require 'bundler/setup'

require 'date'
require 'CGI'
require 'yaml'
require 'webrick'
require 'xmlrpc/server'

class OrbitDB
  attr_accessor :posts, :categories, :src_path, :output_path

  def initialize(src_path, output_path = nil)
    self.posts = []
    self.categories = []
    self.src_path = src_path
    self.output_path = output_path
  end

  def build
    read_all_posts(src_path)
    self.posts = sort_posts_by_date(posts)
    self.categories = process_categories(categories)

    {
      'posts' => posts,
      'categories' => categories
    }
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

        single_content = Post.new(full_path).build

        next if single_content.nil?

        posts.push(single_content)
        categories.concat(single_content['categories'])
      end
    end
  end

  def sort_posts_by_date(posts)
    posts.sort_by { |hash| hash['dateCreated'].to_s }.reverse!
    posts
  end

  def process_categories(categories)
    categories.uniq
  end
end

class Post
  attr_accessor :path

  def initialize(path)
    self.path = path
  end

  def build
    file_contents = read_file_contents(path)
    frontmatter = read_frontmatter(file_contents)
    return if frontmatter.empty?
    post_body = file_contents[frontmatter.length+7..-1] # +7 because we stripped out "---\n---"
    frontmatter = YAML.load(frontmatter)

    # Filter posts without a date:
    return unless frontmatter.key?('date')

    # https://codex.wordpress.org/XML-RPC_MetaWeblog_API
    {
      'postid' => path,
      'title' => frontmatter['title'] || '',
      'description' => post_body.strip!,
      'link' => frontmatter['link'] || '',
      'dateCreated' => frontmatter['date'],
      'categories' => frontmatter['categories'] || []
    }
  end

  private

  def read_file_contents(path)
    File.read(path)
  end

  def read_frontmatter(contents)
    frontmatter = contents.match(/\A---(.+)\n---/m)

    return '' unless frontmatter
    frontmatter[1]
  end
end

class MetaWeblogAPI
  attr_accessor :db

  def initialize(db)
    self.db = db
  end

  # +--------------------------------------------------------------------------+
  # | Posts
  # +--------------------------------------------------------------------------+

  def newPost(blog_id, _, _, struct, publish)
    ''
  end

  def getPost(_post_id, _, _password)
    {}
  end

  def editPost(post_id, _, _, _struct, _publish)
    true
  end

  def getRecentPosts(_, _, _, post_count)
    db['posts'][0, post_count.to_i]
  end

  # +--------------------------------------------------------------------------+
  # | Categories
  # +--------------------------------------------------------------------------+

  def getCategories(_, _, _)
    db['categories']
  end
end

class OrbitServlet < XMLRPC::WEBrickServlet
  attr_accessor :token

  def initialize(token)
    super()

    self.token = token
  end

  def service(req, res)
    params = CGI.parse(req.query_string)
    raise XMLRPC::FaultException.new(0, 'Login invalid') unless params['token'][0] == token

    super
  end
end

# ---

puts 'Starting Orbit…'

token = 'e1b22248-f2b7-4009-bfd0-2ceb743075b9'

db = OrbitDB.new('/Users/elliot/Google Drive/Documents/elliotekj.com/post', '').build
metaWeblog_api = MetaWeblogAPI.new(db)

servlet = OrbitServlet.new(token)
servlet.add_handler('metaWeblog', metaWeblog_api)

# --

servlet.set_service_hook do |obj, *args|
  name = (obj.respond_to? :name) ? obj.name : obj.to_s
  STDERR.puts "calling #{name}(#{args.map{|a| a.inspect}.join(", ")})"
  begin
    ret = obj.call(*args)  # call the original service-method
    STDERR.puts "   #{name} returned " + ret.inspect[0,2000]

    if ret.inspect.match(/[^\"]nil[^\"]/)
      STDERR.puts "found a nil in " + ret.inspect
    end
    ret
  rescue
    STDERR.puts "  #{name} call exploded"
    STDERR.puts $!
    STDERR.puts $!.backtrace
    raise XMLRPC::FaultException.new(-99, "error calling #{name}: #{$!}")
  end
end

servlet.set_default_handler do |name, *args|
  STDERR.puts "** tried to call missing method #{name}( #{args.inspect} )"
  raise XMLRPC::FaultException.new(-99, "Method #{name} missing or wrong number of parameters!")
end

# --

server = WEBrick::HTTPServer.new(:Port => 4040)
server.mount('/xmlrpc.php', servlet)

['INT', 'TERM', 'HUP'].each { |signal|
  trap(signal) { server.shutdown }
}

server.start
