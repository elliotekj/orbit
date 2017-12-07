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

# Imports

require 'rubygems'
require 'bundler/setup'

require 'date'
require 'yaml'
require 'webrick'
require 'xmlrpc/server'

class OrbitUtilities
  def self.check_auth(username, password)
    if username != 'admin' || password != admin
      raise XMLRPC::FaultException.new(0, 'Login invalid')
    end
  end
end

class OrbitDB
  attr_accessor :src_path, :content, :categories, :output_path

  def initialize(src_path, output_path = nil)
    self.content = []
    self.categories = []
    self.src_path = src_path
    self.output_path = output_path
  end

  def build
    read_all_content
    sort_content_by_date

    {
      'content' => content,
      'categories' => categories.uniq!
    }
  end

  private

  def read_all_content
    sections = read_content_sections

    sections.each do |section|
      walk_section(section['path'], section)
    end
  end

  def read_content_sections
    sections = []
    sections_path = File.join(src_path, '/content')

    Dir.foreach(sections_path) do |section|
      next if section =~ /^\.+$/ # Filter out `.` and `..`
      next if section =~ /^[\.]/ # Filter out hidden files

      # TODO: Don't hard-filter these out, add an option or something:
      next if section == 'images' || section == 'wp-content'

      full_section_path = File.join(sections_path, section)

      if File.directory? full_section_path
        sections.push(
          'name' => section,
          'path' => full_section_path
        )
      end
    end

    sections
  end

  def walk_section(path, section)
    Dir.foreach(path) do |path_item|
      next if path_item =~ /^\.+$/ # Filter out `.` and `..`
      next if path_item =~ /^[\.]/ # Filter out hidden files

      full_path = File.join(path, path_item)

      if File.directory? full_path
        walk_section(full_path, section)
      elsif File.file? full_path
        next unless path_item =~ /^.+(md|markdown|txt)$/

        single_content = OrbitContent.new(full_path, section['name']).build

        next if single_content.nil?

        content.push(single_content)
        categories.concat(single_content['categories'])
      end
    end
  end

  def sort_content_by_date
    content.sort_by { |hash| hash['dateCreated'].to_s }.reverse!
  end
end

class OrbitContent
  attr_accessor :path, :section_name

  def initialize(path, section_name)
    self.path = path
    self.section_name = section_name
  end

  def build
    file_contents = read_file_contents(path)
    frontmatter = read_frontmatter(file_contents)
    return if frontmatter.empty?
    description = file_contents[frontmatter.length+7..-1] # +7 because we stripped out "---\n---"
    frontmatter = YAML.load(frontmatter)

    # Filter out posts without a datetime:
    return unless frontmatter.key?('date')

    # Ref: https://codex.wordpress.org/XML-RPC_MetaWeblog_API
    {
      'postid' => path,
      'title' => frontmatter['title'] || '',
      'description' => description.strip!,
      'dateCreated' => frontmatter['date'],
      'categories' => frontmatter['categories'] || [],
      'post_status' => read_post_status(frontmatter),
      'custom_fields' => {
        'section' => section_name
      }
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

  def read_post_status(frontmatter)
    # Ref: https://codex.wordpress.org/Post_Status_Transitions
    return 'publish' unless frontmatter.key?('draft') && frontmatter['draft'] == true
    return 'draft'
  end
end

class MetaWeblogAPI
  attr_accessor :db

  def initialize(db)
    self.db = db.build
  end

  # +--------------------------------------------------------------------------+
  # | MetaWeblog API
  # +--------------------------------------------------------------------------+

  def newPost(blog_id, username, password, struct, publish)
    # OrbitUtilities.check_auth(username, password)

    ''
  end

  def getPost(_post_id, _username, _password)
    # OrbitUtilities.check_auth(username, password)

    {}
  end

  def editPost(post_id, _username, _password, _struct, _publish)
    # OrbitUtilities.check_auth(username, password)

    true
  end

  def getCategories(_blog_id, _username, _password)
    # OrbitUtilities.check_auth(username, password)

    db['categories']
  end

  def getRecentPosts(_blog_id, _username, _password, post_count)
    # OrbitUtilities.check_auth(username, password)

    db['content'][0..post_count]
  end
end

# ---

puts 'Starting Orbit…'

db = OrbitDB.new('/Users/elliot/dev/elliotekj-com-hugo', '')
meta_weblog = MetaWeblogAPI.new(db)

servlet = XMLRPC::WEBrickServlet.new
servlet.add_handler('metaWeblog', meta_weblog)

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
