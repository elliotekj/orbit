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

  # def getUserInfo(app_id, username, password)
  #   STDOUT.puts(app_id)
  #   STDOUT.puts(username)
  #   STDOUT.puts(password)
  # end
end
