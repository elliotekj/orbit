require_relative 'post.rb'

class BloggerAPI
  def initialize(db)
    @db = db
  end

  # +--------------------------------------------------------------------------+
  # | Posts
  # +--------------------------------------------------------------------------+

  def deletePost(_, post_id, _, _, _)
    Post.delete(post_id)
    @db.posts.delete_if { |post| post['postid'] == post_id }
    true
  end
end
