require 'date'
require 'fileutils'
require'time'
require 'yaml'

class Post
  def self.parse(path)
    file_contents = read_file_contents(path)
    frontmatter = read_frontmatter(file_contents)
    return if frontmatter.empty?
    post_body = file_contents[frontmatter.length+7..-1] # +7 because we stripped out "---\n---"
    frontmatter = YAML.load(frontmatter)

    # Load draft posts with a special category:
    categories = frontmatter['categories'] || []
    if frontmatter.key?('draft') && frontmatter['draft'] == true
      categories.unshift('[Orbit - Draft]')
    end

    # Preserve any other frontmatter that isn't handled by MarsEdit:
    other_frontmatter = []
    frontmatter.each do |key, value|
      next if key == 'title'
      next if key == 'link'
      next if key == 'date'
      next if key == 'date_modified'
      next if key == 'categories'
      next if key == 'draft'

      other_frontmatter.push(key => value)
    end

    # https://codex.wordpress.org/XML-RPC_MetaWeblog_API
    # [1] Because YAML parses `rfc3339` as a Time
    {
      'postid' => path,
      'title' => frontmatter['title'] || '',
      'description' => post_body.strip!,
      'link' => frontmatter['link'] || '',
      'dateCreated' => frontmatter['date'] || Time.parse(DateTime.now.rfc3339.to_s), #[1]
      'categories' => categories,
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
      'dateCreated' => now.rfc3339,
      'categories' => struct['categories'] || [],
      'otherFrontmatter' => []
    }

    write(post, true)
    post
  end

  def self.update(post, struct)
    unless FileTest.exist?(post['postid'])
      raise XMLRPC::FaultException.new(0, 'Post doesn’t exist')
    end

    was_draft = false

    STDOUT.puts("\n\nUP IN\n\n")
    STDOUT.puts(struct)
    STDOUT.puts("\n\n")

    post['title'] = struct['title'] || ''
    post['description'] = struct['description'] || ''
    post['link'] = struct['link'] || ''
    if post['categories'].include?('[Orbit - Draft]')
      was_draft = true
      post['dateCreated'] = Time.now.to_datetime.rfc3339
    end
    post['categories'] = struct['categories'] || []

    STDOUT.puts("\n\nUP OUT\n\n")
    STDOUT.puts(post)
    STDOUT.puts("\n\n")

    [post, was_draft]
  end

  def self.write(post, was_draft)
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
      file.write("title: #{post['title']}\n") unless post['title'] == ''
      file.write("link: #{post['link']}\n") unless post['link'] == ''

      if post['categories'].include?('[Orbit - Draft]')
        file.write("draft: true\n")
        post['categories'] -= ['[Orbit - Draft]']
      else
        file.write("date: #{date_created}\n")
        file.write("date_modified: #{Time.now.to_datetime.rfc3339}\n") unless was_draft
      end

      file.write("categories: #{post['categories']}\n") unless post['categories'] == []
      post['otherFrontmatter'].each do |hash|
        file.write("#{hash.keys[0]}: #{hash.values[0]}\n")
      end
      file.write("---\n\n")
      file.write(post['description'])
    end

    true
  end

  def self.delete(path)
    FileUtils.rm(path) if File.exist?(path)
  end

  def self.find(post_id, db)
    p = {}

    db.posts.each do |post|
      next unless post['postid'] == post_id
      return post
    end

    STDOUT.puts("\n\nFIND\n\n")
    STDOUT.puts(p)
    STDOUT.puts("\n\n")
    p
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
