require_relative 'post.rb'
require_relative 'media.rb'

class MetaWeblogAPI
  def initialize(db)
    @db = db
  end

  # +--------------------------------------------------------------------------+
  # | Posts
  # +--------------------------------------------------------------------------+

  def newPost(_, _, _, struct, _)
    post = Post.create(@db.src_path, struct)
    @db.posts.unshift(post)
    post['postid']
  end

  def getPost(post_id, _, _)
    Post.find(post_id, @db)
  end

  def editPost(post_id, _, _, struct, _publish)
    post = getPost(post_id, _, _)

    updated_post, was_draft = Post.update(post, struct)
    db_post_index = @db.posts.index do |p|
      p['postid'] == updated_post['postid']
    end
    @db.posts[db_post_index] = updated_post

    Post.write(updated_post, was_draft)
    updated_post['postid']
  end

  def getRecentPosts(_, _, _, post_count)
    return @db.posts if post_count > @db.posts.length
    @db.posts[0, post_count.to_i]
  end

  # +--------------------------------------------------------------------------+
  # | Categories
  # +--------------------------------------------------------------------------+

  def getCategories(_, _, _)
    @db.categories
  end

  # +--------------------------------------------------------------------------+
  # | Media
  # +--------------------------------------------------------------------------+

  def newMediaObject(_, _, _, data)
    path = Media.save(@db.src_path, data['name'], data['bits'])

    {
      'url' => path
    }
  end
end
