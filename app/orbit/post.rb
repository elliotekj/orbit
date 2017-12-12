require 'date'
require 'fileutils'
require 'time'
require 'yaml'

class Post
  # Public: Get a post from its path.
  #
  # path - The path String to the post
  #
  # Returns a MetaWeblog compatible hash.
  def self.get(path)
    p = read(path)
    frontmatter, body = parse(p)
    return nil if frontmatter.nil? || body.nil?

    post_hash = process_frontmatter(frontmatter)
    post_hash['postid'] = path
    post_hash['description'] = body

    post_hash
  end

  # Public: Create a post.
  #
  # path - The path String where the post will be written
  # metaweblog_struct - The post data hash
  #
  # Returns a post Hash.
  def self.create(path, metaweblog_struct)
    now = DateTime.now
    filename = now.strftime('%Y-%m-%d-%H-%M-%S.md')

    post_id = File.join(path, filename)
    body = metaweblog_struct['description'] || ''
    frontmatter = {
      'title' => metaweblog_struct['title'] || '',
      'link' => metaweblog_struct['link'] || '',
      'dateCreated' => now.rfc3339,
      'categories' => metaweblog_struct['categories'] || []
    }

    write(post_id, frontmatter, body)
    get(post_id)
  end

  def self.merge_metaweblog_struct(post, metaweblog_struct)
    unless FileTest.exist?(post['postid'])
      raise XMLRPC::FaultException.new(0, 'Post doesn’t exist')
    end

    post['title'] = metaweblog_struct['title'] || ''
    post['description'] = metaweblog_struct['description'] || ''
    post['link'] = metaweblog_struct['link'] || ''
    if post['categories'].include?('[Orbit - Draft]')
      post['dateCreated'] = Time.now.to_datetime.rfc3339
    end
    post['categories'] = metaweblog_struct['categories'] || []

    post
  end

  def self.write(post_id, frontmatter, body)
    dir_structure = File.dirname(post_id)
    FileUtils.mkpath(dir_structure) unless File.exist?(dir_structure)

    # We'll handle inserting these ourselves:
    date_created = frontmatter.delete('dateCreated') if frontmatter.key?('dateCreated')
    date_modified = frontmatter.delete('date_modified') if frontmatter.key?('date_modified')

    # Remove the `postid`:
    frontmatter.delete('postid') if frontmatter.key?('postid')

    # Merge `otherFrontmatter` into the `frontmatter`:
    if frontmatter.key?('otherFrontmatter')
      other_frontmatter = frontmatter.delete('otherFrontmatter')
      frontmatter = frontmatter.merge(other_frontmatter.reduce({}, :update))
    end

    # Set a post's draft status:
    if frontmatter['categories'].include?('[Orbit - Draft]')
      date_created = nil
      date_modified = nil
      frontmatter['draft'] = true
      frontmatter['categories'] -= ['[Orbit - Draft]']
    else
      frontmatter.delete('draft') if frontmatter.key?('draft')
      date_modified = Time.now.to_datetime.rfc3339
    end


    File.open(post_id, 'w') do |file|
      file.truncate(0) # Empty the file

      file.write(frontmatter.to_yaml)
      file.write("date: #{date_created}\n") unless date_created == nil
      file.write("date_modified: #{date_created}\n") unless date_modified == nil
      file.write("---\n\n")
      file.write(body)
    end
  end

  def self.delete(path)
    FileUtils.rm(path) if File.exist?(path)
  end

  # Private: Read the contents of a post path.
  #
  # path - The path to read
  #
  # Returns the post as a String.
  def self.read(path)
    File.read(path)
  end

  # Private: Parse the contents of a post file.
  #
  # post_string - The String to parse
  #
  # Returns an Array composed of the frontmatter and body.
  def self.parse(post_string)
    frontmatter = read_frontmatter(post_string)
    return nil if frontmatter.nil?
    body = read_body(post_string)
    return nil if body.nil?

    [frontmatter, body]
  end

  # Private: Find the frontmatter in a post and parse it as YAML.
  #
  # post_string - The String to search
  #
  # Returns the frontmatter as YAML or nil if no frontmatter is found.
  def self.read_frontmatter(post_string)
    frontmatter = post_string.match(/\A---\n((.|\n)+)\n---/)
    return nil unless frontmatter
    YAML.load(frontmatter[1])
  end

  # Private: Find the body of a post.
  #
  # post_string - The String to search
  #
  # Returns the body as a String or nil.
  def self.read_body(post_string)
    frontmatter = post_string.match(/\A---(.+)\n---/m)
    return nil unless frontmatter
    frontmatter_char_count = frontmatter[1].length
    frontmatter_char_count += 7 # The len of "---\n---"
    body = post_string[frontmatter_char_count..-1]
    body.strip!
  end

  # Private: Separate the frontmatter that MetaWeblog doesn't handle so that we don't lose it.
  #
  # frontmatter - The YAML to process
  #
  # Returns a Hash with the processed frontmatter.
  def self.process_frontmatter(frontmatter)
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

    {
      'title' => frontmatter['title'] || '',
      'link' => frontmatter['link'] || '',
      'dateCreated' => frontmatter['date'] || Time.parse(DateTime.now.rfc3339.to_s),
      'categories' => categories,
      'otherFrontmatter' => other_frontmatter || []
    }
  end
end
