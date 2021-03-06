require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  attr_reader :user, :user2

  def setup
    Items.delete_all
    @user = Users.register("foo_list_items", 'bar')
    @user2 = Users.register("baz_list_items", "qux")
    Future.image_cache.batch_start
  end

  def teardown
    Items.delete_all
    Future.image_cache.batch_end
  end

  def test_item_visibility
    user_posts = (1..1).map do |i|
      item = {:user => user, :text => "Private post #{i}"}
      it = Uploader.upload item
    end
    user2_posts = (1..5).map do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      it = Uploader.upload item
    end
    shared_posts = (1..2).map do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      3, Items.rfind_all(user).size
    )
    assert_equal(
      7, Items.rfind_all(user2).size
    )
    assert_equal(
      user2_posts[3, 2],
      Items.rfind_all(user2,
                      :order_by => [["id", :asc]], :limit => 2, :offset => 3)
    )
  end

  def test_item_tag_search
    (1..5).each do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.add_tag 'tag_items'
    end
    (1..2).each do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
      it.add_tag 'list_items'
    end
    (1..2).each do |i|
      item = {:user => user2, :text => "Private post #{i}",
              :groups => [[user.group, false]]}
      it = Uploader.upload item
      it.add_tag 'list_items'
      it.add_tag 'tag_items'
    end
    assert_equal(
      4, Items.rfind_all(user2, "tags.name" => "list_items").size
    )
    assert_equal(
      7, Items.rfind_all(user2, "tags.name" => "tag_items").size
    )
    assert_equal(
      2, Items.rfind_all(user2, "tags.name" => +["list_items", "tag_items"]).size
    )
    assert_equal(
      9, Items.rfind_all(user2, "tags.name" => ["list_items", "tag_items"]).size
    )
  end

  def test_item_dont_show_deleted
    d = []
    ud = []
    (1..5).each do |i|
      item = {:user => user2, :text => "Private post #{i}"}
      it = Uploader.upload item
      it.deleted = true if i <= 20
      ud << it if i > 20
      d << it if i <= 20
    end
    assert_equal(
      ud, Items.rfind_all(user2).sort
    )
    assert_equal(
      d, Items.rfind_all(user2, :deleted => true).sort
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
    (1..3).each do |i|
      item = {:user => user2, :text => "one two", :sets => [s1, s2],
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    (1..4).each do |i|
      item = {:user => user2, :text => "two", :sets => [s2],
              :groups => [[user.group, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      8, Items.rfind_all(user2, "sets.name" => "one").size
    )
    assert_equal(
      7, Items.rfind_all(user2, "sets.name" => "two").size
    )
    assert_equal(
      3, Items.rfind_all(user2, "sets.name" => +["one", "two"]).size
    )
    assert_equal(
      12, Items.rfind_all(user2, "sets.name" => ["one", "two"]).size
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
    (1..3).each do |i|
      item = {:user => user2, :text => "one two",
              :groups => [[user.group, false], [g1, false], [g2, false]]}
      it = Uploader.upload item
    end
    (1..4).each do |i|
      item = {:user => user2, :text => "two",
              :groups => [[user.group, false], [g2, false]]}
      it = Uploader.upload item
    end
    assert_equal(
      8, Items.rfind_all(user2, "groups.name" => "one").size
    )
    assert_equal(
      7, Items.rfind_all(user2, "groups.name" => "two").size
    )
    assert_equal(
      3, Items.rfind_all(user2, "groups.name" => +["one", "two"]).size
    )
    assert_equal(
      12, Items.rfind_all(user2, "groups.name" => ["one", "two"]).size
    )
    assert_equal(
      5, Items.rfind_all(user2, "groups.name" => [["one"], -["two"]]).size
    )
  end

  def test_item_sort_by_creation_date
    its = (1..3).map do |i|
      item = {:user => user2, :text => "one two"}
      it = Uploader.upload item
      it.created_at = "2006-10-#{i}"
      it
    end
    assert_equal(its, Items.rfind_all(user2, :order_by => [['created_at', :asc]]))
    assert_equal(its.reverse, Items.rfind_all(user2, :order_by => [['created_at', :desc]]))
  end

end