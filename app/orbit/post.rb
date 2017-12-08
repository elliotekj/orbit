require 'date'
require 'fileutils'
require 'yaml'

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
