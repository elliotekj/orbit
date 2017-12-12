require_relative 'post.rb'

class BloggerAPI
  def initialize(db, user_passed_update_cmd)
    @db = db
    @user_passed_update_cmd = user_passed_update_cmd
  end

  # +--------------------------------------------------------------------------+
  # | Posts
  # +--------------------------------------------------------------------------+

  def deletePost(_, post_id, _, _, _)
    Post.delete(post_id)
    @db.posts.delete_if { |post| post['postid'] == post_id }
    system(@user_passed_update_cmd) unless @user_passed_update_cmd.nil?
    true
  end
end
