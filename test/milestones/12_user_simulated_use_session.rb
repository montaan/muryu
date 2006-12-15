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
    Sets[@user, 'urgent'] &
    Sets[@user, 'todo'] &
    Tags[@user, ['work', 'home']]
    %Q(
      SELECT *
      FROM items i,
           items_sets is, sets s,
           items_sets isd, sets sd,
           items_tags it, tags t
           
      WHERE i.id = is.item_id
        AND s.id = is.set_id
        AND s.name = 'urgent'
        
        AND i.id = isd.item_id
        AND sd.id = isd.set_id
        AND sd.name = 'todo'
        
        AND i.id = it.item_id
        AND t.id = it.tag_id
        AND t.name IN ('work', 'home') -- yes, work | home
    )
  end

  def remove_all_done_items_from_urgent
    Items.rdelete_search(@user, 'set:urgent set:done !set:todo')
    Sets[@user, 'urgent'] &
    Sets[@user, 'done'] &
    ~Sets[@user, 'todo']
    %Q(
      SELECT *
      FROM items i, items_sets is, sets s, items_sets isd, sets sd
      WHERE i.id = is.item_id
        AND s.id = is.set_id
        AND s.name = 'urgent'
        AND i.id = isd.item_id
        AND sd.id = isd.set_id
        AND sd.name = 'done'
        AND i.id NOT IN (SELECT id
                         FROM items i2, items_sets is2, sets s2
                          WHERE i2.id = is2.item_id
                            AND s2.id = is2.set_id
                            AND s2.name IN ('todo'))
    )
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
    Items.search('mountain')
  end

  def view_the_third_mountain_picture
  end

end