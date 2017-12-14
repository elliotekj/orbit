require_relative 'post.rb'
require_relative 'media.rb'

class MetaWeblogAPI
  def initialize(db, user_passed_update_cmd)
    @db = db
    @user_passed_update_cmd = user_passed_update_cmd
  end

  # +--------------------------------------------------------------------------+
  # | Posts
  # +--------------------------------------------------------------------------+

  def newPost(_, _, _, metaweblog_struct, _)
    post = Post.create(@db.content_path, metaweblog_struct)
    @db.refresh_post_paths
    system(@user_passed_update_cmd) unless @user_passed_update_cmd.nil?
    post['postid']
  end

  def getPost(post_id, _, _)
    Post.get(post_id)
  end

  def editPost(post_id, _, _, metaweblog_struct, _publish)
    post = Post.get(post_id)
    post = Post.merge_metaweblog_struct(post, metaweblog_struct)

    body = post.delete('description')
    Post.write(post_id, post, body)

    @db.refresh_post_paths

    system(@user_passed_update_cmd) unless @user_passed_update_cmd.nil?
    post_id
  end

  def getRecentPosts(_, _, _, post_count)
    @db.fetch_first(post_count)
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

    system(@user_passed_update_cmd) unless @user_passed_update_cmd.nil?
    {
      'url' => path
    }
  end
end
