require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  attr_reader :user, :user2

  def setup
    @user = Users.register("foo_list_items", 'bar')
    @user2 = Users.register("baz_list_items", "qux")
  end

  def teardown
    Users.delete_all
  end

  def test_item_visibility
    (1..10).each do |i|
      item = {:user => user, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.add_tag 'list_items'
    end
    (1..50).each do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.add_tag 'list_items'
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
      it.add_tag 'list_items'
    end
    assert_equal(
      30, Items.rfind_all(user).size
    )
    assert_equal(
      70, Items.rfind_all(user2).size
    )
  end

  def test_item_tag_search
    (1..50).each do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.add_tag 'tag_items'
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
      it.add_tag 'list_items'
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
      it.add_tag 'list_items'
      it.add_tag 'tag_items'
    end
    assert_equal(
      40, Items.rfind_all(user2, "tags.name" => "list_items").size
    )
    assert_equal(
      70, Items.rfind_all(user2, "tags.name" => "tag_items").size
    )
    assert_equal(
      20, Items.rfind_all(user2, "tags.name" => +["list_items", "tag_items"]).size
    )
    assert_equal(
      90, Items.rfind_all(user2, "tags.name" => ["list_items", "tag_items"]).size
    )
  end

  def test_item_full_text_search
    (1..5).each do |i|
      item = {:user => user2, :text => "one",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..30).each do |i|
      item = {:user => user2, :text => "one two",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "two",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      35, Items.rfind_all(user2, :text => "one").size
    )
    assert_equal(
      50, Items.rfind_all(user2, :text => "two").size
    )
    assert_equal(
      30, Items.rfind_all(user2, :text => "one two").size
    )
    assert_equal(
      0, Items.rfind_all(user2, :text => "two one").size
    )
    assert_equal(
      30, Items.rfind_all(user2, :text => +["two", "one"]).size
    )
  end

  def test_item_dont_show_deleted
    d = 0
    ud = 0
    (1..50).each do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.deleted = true if i < 20
      ud += 1 if i >= 20
      d += 1 if i < 20
    end
    assert_equal(
      ud, Items.rfind_all(user2).size
    )
    assert_equal(
      d, Items.rfind_all(user2, :deleted => true).size
    )
  end

  def test_item_select_by_set
    s1 = Sets.rfind_or_create(user2, :name => 'one')
    s2 = Sets.rfind_or_create(user2, :name => 'two')
    (1..5).each do |i|
      item = {:user => user2, :text => "one", :sets => [s1],
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..30).each do |i|
      item = {:user => user2, :text => "one two", :sets => [s1, s2],
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "two", :sets => [s2],
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      35, Items.rfind_all(user2, "sets.name" => "one").size
    )
    assert_equal(
      50, Items.rfind_all(user2, "sets.name" => "two").size
    )
    assert_equal(
      30, Items.rfind_all(user2, "sets.name" => +["one", "two"]).size
    )
    assert_equal(
      55, Items.rfind_all(user2, "sets.name" => ["one", "two"]).size
    )
    assert_equal(
      5, Items.rfind_all(user2, "sets.name" => [["one"], -["two"]]).size
    )
  end

  def test_item_select_by_group
    g1 = Groups.rfind_or_create(user2, :name => 'one')
    g2 = Groups.rfind_or_create(user2, :name => 'two')
    (1..5).each do |i|
      item = {:user => user2, :text => "one",
              :groups => [[user.group, false], [g1, false]]}
      it = Uploader.upload item
    end
    (1..30).each do |i|
      item = {:user => user2, :text => "one two",
              :groups => [[user.group, false], [g1, false], [g2, false]]}
      it = Uploader.upload item
    end
    (1..20).each do |i|
      item = {:user => user2, :text => "two",
              :groups => [[user.group, false], [g2, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      35, Items.rfind_all(user2, "groups.name" => "one").size
    )
    assert_equal(
      50, Items.rfind_all(user2, "groups.name" => "two").size
    )
    assert_equal(
      30, Items.rfind_all(user2, "groups.name" => +["one", "two"]).size
    )
    assert_equal(
      55, Items.rfind_all(user2, "groups.name" => ["one", "two"]).size
    )
    assert_equal(
      5, Items.rfind_all(user2, "groups.name" => [["one"], -["two"]]).size
    )
  end

  def test_item_sort_by_creation_date
    its = (1..30).map do |i|
      item = {:user => user2, :text => "one two"}
      it = Uploader.upload item
      it.created_at = "2006-10-#{i}"
      it
    end
    assert_equal(its, Items.rfind_all(user2, :order_by => [['created_at', :asc]]))
    assert_equal(its.reverse, Items.rfind_all(user2, :order_by => [['created_at', :desc]]))
  end

end