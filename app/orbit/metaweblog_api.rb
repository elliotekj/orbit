require_relative 'post.rb'
require_relative 'media.rb'

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
