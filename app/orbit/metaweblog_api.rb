require_relative 'post.rb'
require_relative 'media.rb'

class MetaWeblogAPI
  def initialize(db)
    @db = db
  end

  # +--------------------------------------------------------------------------+
  # | Posts
  # +--------------------------------------------------------------------------+

  def newPost(_, _, _, metaweblog_struct, _)
    post = Post.create(@db.src_path, metaweblog_struct)
    @db.posts.unshift(post)
    post['postid']
  end

  def getPost(post_id, _, _)
    Post.get(post_id)
  end

  def editPost(post_id, _, _, metaweblog_struct, _publish)
    post = Post.get(post_id)
    post = Post.merge_metaweblog_struct(post, metaweblog_struct)

    @db.posts.map! do |p|
      if p['postid'] == post['postid']
        post
      else
        p
      end
    end

    body = post.delete('description')
    Post.write(post_id, post, body)

    post_id
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
