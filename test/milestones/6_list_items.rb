require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def test_item_visibility_in_tag_search
    user = Users.register("foo_list_items", 'bar')
    user2 = Users.register("baz_list_items", "qux")

    Items.delete_all

    (1..10).each do |i|
      item = {:user => user, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.add_tag 'list_items'
    end
    (1..50).each do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      Uploader.upload item
      it.add_tag 'list_items'
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      Uploader.upload item
      it.add_tag 'list_items'
    end
    assert_equal(
      30, Items.rfind_all(user, "tags.name" => 'list_items').size
    )
    assert_equal(
      70, Items.rfind_all(user2, "tags.name" => 'list_items').size
    )
  end

  def test_item_full_text_search
    assert false
  end

  def test_item_dont_show_deleted
    assert false
  end

  def test_item_select_by_set
    assert false
  end

  def test_item_select_by_group
    assert false
  end

  def test_item_sort_by_creation_date
    assert false
  end

end