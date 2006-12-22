require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  attr_reader :user, :user2

  def setup
    @user = Users.register("foo_list_items", 'bar')
    @user2 = Users.register("baz_list_items", "qux")
    Future.image_cache.batch_start
  end

  def teardown
    Users.delete_all
    Future.image_cache.batch_end
  end

  def test_item_full_text_search
    (1..5).each do |i|
      item = {:user => user2, :text => "one",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..3).each do |i|
      item = {:user => user2, :text => "one two",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..4).each do |i|
      item = {:user => user2, :text => "two",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      8, Items.rfind_all_fts(user2, "one").size
    )
    assert_equal(
      7, Items.rfind_all_fts(user2, "two").size
    )
#     assert_equal(
#       3, Items.rfind_all(user2, :text => "one two").size
#     )
#     assert_equal(
#       0, Items.rfind_all(user2, :text => "two one").size
#     )
    assert_equal(
      3, Items.rfind_all_fts(user2, "two&one").size
    )
  end


end
