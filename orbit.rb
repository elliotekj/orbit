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

require 'CGI'
require 'date'
require 'fileutils'
require 'webrick'
require 'xmlrpc/server'
require 'yaml'

class OrbitServlet < XMLRPC::WEBrickServlet
  attr_accessor :token

  def initialize(token)
    super()

    @token = token
  end

  def service(req, res)
    params = CGI.parse(req.query_string)
    raise XMLRPC::FaultException.new(0, 'Login invalid') unless params['token'][0] == @token

    super
  end
end

class OrbitDB
  def initialize(src_path, output_path = nil)
    @posts = []
    @categories = []
    @src_path = src_path
    @output_path = output_path
  end

  def build
    read_all_posts(File.join(@src_path, 'content/post'))
    sort_posts_by_date
    make_categories_unique

    {
      'src_path' => @src_path,
      'posts' => @posts,
      'categories' => @categories
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

class Post
  def self.parse(path)
    file_contents = read_file_contents(path)
    frontmatter = read_frontmatter(file_contents)
    return if frontmatter.empty?
    post_body = file_contents[frontmatter.length+7..-1] # +7 because we stripped out "---\n---"
    frontmatter = YAML.load(frontmatter)

    # Filter posts without a date:
    return unless frontmatter.key?('date')

    other_frontmatter = []
    frontmatter.each do |key, value|
      next if key == 'title'
      next if key == 'link'
      next if key == 'date'
      next if key == 'date_modified'
      next if key == 'categories'

      other_frontmatter.push(key => value)
    end

    # https://codex.wordpress.org/XML-RPC_MetaWeblog_API
    {
      'postid' => path,
      'title' => frontmatter['title'] || '',
      'description' => post_body.strip!,
      'link' => frontmatter['link'] || '',
      'dateCreated' => frontmatter['date'],
      'categories' => frontmatter['categories'] || [],
      'otherFrontmatter' => other_frontmatter || []
    }
  end

  def self.create(base_path, struct)
    now = DateTime.now
    filename = now.strftime('%Y-%m-%d-%H-%M-%S.md')
    path = File.join(base_path, 'content/post', filename)

    post = {
      'postid' => path,
      'title' => struct['title'] || '',
      'description' => struct['description'] || '',
      'link' => struct['link'] || '',
      'dateCreated' => now.rfc3339.to_s,
      'categories' => struct['categories'] || [],
      'otherFrontmatter' => []
    }

    write(post)
    post
  end

  def self.update(post, struct)
    unless FileTest.exist?(post['postid'])
      raise XMLRPC::FaultException.new(0, 'Post doesn’t exist')
    end

    post['title'] = struct['title'] || ''
    post['description'] = struct['description'] || ''
    post['link'] = struct['link'] || ''
    post['categories'] = struct['categories'] || ''

    write(post)
  end

  def self.write(post)
    dir_structure = File.dirname(post['postid'])
    FileUtils.mkpath(dir_structure) unless File.exist?(dir_structure)

    if post['dateCreated'].class == Time
      date_created = post['dateCreated'].to_datetime.rfc3339 # because YAML
    else
      date_created = post['dateCreated']
    end

    File.open(post['postid'], 'w') do |file|
      file.truncate(0) # Empty the file

      file.write("---\n")
      file.write("title: #{post['title']}\n")
      file.write("link: #{post['link']}\n") unless post['link'] == ''
      file.write("date: #{date_created}\n")
      file.write("date_modified: #{Time.now.to_datetime.rfc3339}\n")
      file.write("categories: #{post['categories']}\n")
      post['otherFrontmatter'].each do |hash|
        file.write("#{hash.keys[0]}: #{hash.values[0]}\n")
      end
      file.write("---\n\n")
      file.write(post['description'])
    end

    true
  end

  def self.read_file_contents(path)
    File.read(path)
  end

  def self.read_frontmatter(contents)
    frontmatter = contents.match(/\A---(.+)\n---/m)

    return '' unless frontmatter
    frontmatter[1]
  end
end

class Media
  def self.save(base_path, name, date)
    ymd_structure = DateTime.now.strftime('%Y/%m/%d')
    dir_structure = File.join(base_path, 'content/images', ymd_structure)
    FileUtils.mkpath(dir_structure) unless File.exist?(dir_structure)
    file_path = File.join(dir_structure, name)

    File.open(file_path, 'w') do |file|
      file.write(date)
    end

    '/images/' + ymd_structure + '/' + name
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

  def newPost(_, _, _, struct, _)
    post = Post.create(db['src_path'], struct)
    db['posts'].unshift(post)
    post['postid']
  end

  def getPost(post_id, _, _)
    db['posts'].each do |p|
      next unless p['postid'] == post_id
      return p
    end
  end

  def editPost(post_id, _, _, struct, _publish)
    post = getPost(post_id, _, _)
    Post.update(post, struct)
  end

  def getRecentPosts(_, _, _, post_count)
    return db['posts'] if post_count > db['posts'].length
    db['posts'][0, post_count.to_i]
  end

  # +--------------------------------------------------------------------------+
  # | Categories
  # +--------------------------------------------------------------------------+

  def getCategories(_, _, _)
    db['categories']
  end

  # +--------------------------------------------------------------------------+
  # | Media
  # +--------------------------------------------------------------------------+

  def newMediaObject(_, _, _, data)
    path = Media.save(db['src_path'], data['name'], data['bits'])

    {
      'url' => path
    }
  end
end

# ---

puts 'Starting Orbit…'

token = 'e1b22248-f2b7-4009-bfd0-2ceb743075b9'

db = OrbitDB.new('/Users/elliot/Desktop/elliotekj-com-hugo', '').build
metaWeblog_api = MetaWeblogAPI.new(db)

servlet = OrbitServlet.new(token)
servlet.add_handler('metaWeblog', metaWeblog_api)

# --

# servlet.set_service_hook do |obj, *args|
#   name = (obj.respond_to? :name) ? obj.name : obj.to_s
#   STDERR.puts "calling #{name}(#{args.map{|a| a.inspect}.join(", ")})"
#   begin
#     ret = obj.call(*args)  # call the original service-method
#     STDERR.puts "   #{name} returned " + ret.inspect[0,2000]

#     if ret.inspect.match(/[^\"]nil[^\"]/)
#       STDERR.puts "found a nil in " + ret.inspect
#     end
#     ret
#   rescue
#     STDERR.puts "  #{name} call exploded"
#     STDERR.puts $!
#     STDERR.puts $!.backtrace
#     raise XMLRPC::FaultException.new(-99, "error calling #{name}: #{$!}")
#   end
# end

# servlet.set_default_handler do |name, *args|
#   STDERR.puts "** tried to call missing method #{name}( #{args.inspect} )"
#   raise XMLRPC::FaultException.new(-99, "Method #{name} missing or wrong number of parameters!")
# end

# --

server = WEBrick::HTTPServer.new(:Port => 4040)
server.mount('/xmlrpc.php', servlet)

['INT', 'TERM', 'HUP'].each { |signal|
  trap(signal) { server.shutdown }
}

server.start
