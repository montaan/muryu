require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def setup
    @user = Users.register('foo', 'bar')
    populate_db
  end

  def test_user_session
    look_at_urgent_todo_for_work_and_home
    remove_all_done_items_from_urgent
    create_new_todo_post
    upload_a_wikipedia_article_and_some_images
    find_all_items_related_to_the_article
    search_for_mountain_pictures
    view_the_third_mountain_picture
  end

  def look_at_urgent_todo_for_work_and_home
    Items.rsearch(@user, 'set:urgent set:todo tag:work|home')
  end

  def remove_all_done_items_from_urgent
    Items.rdelete_search(@user, 'set:urgent set:done !set:todo')
  end

  def create_new_todo_post
    Uploader.upload :text => "Fix all bugs", :user => @user, :sets => ['todo']
  end

  def upload_a_wikipedia_article_and_some_images
    @article = Uploader.upload wikipedia_article
    Uploader.upload image1
    Uploader.upload image2
  end

  def find_all_items_related_to_the_article
    @article.related_items
  end

  def search_for_mountain_pictures
    Items.rsearch(@user, 'mountain')
  end

  def view_the_third_mountain_picture
    Items.rsearch(@user, 'mountain', :offset => 3, :limit => 1)
  end

end