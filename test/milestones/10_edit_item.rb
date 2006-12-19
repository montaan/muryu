require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def test_item_permissions
    user = Users.register('foo', 'bar')
    user2 = Users.register("baz", "qux")

    itemh = {:user => user, :text => "Private post"}
    item = Uploader.upload itemh
    assert_equal(item, Items.rfind(user, :id => item))
    assert_equal(nil, Items.rfind(user2, :id => item))
    item.write(user) do
      item.add_tag 'super'
    end
    assert_equal(['super'], item.tags.map{|t|t.name})
    assert_raise(PermissionError) do
      item.write(user2) do
        item.add_tag 'bad'
      end
    end
    
    itemh = {:user => user, :text => "Public post",
            :groups => [[Groups.public, true]]}
    item = Uploader.upload itemh
    assert_equal(item, Items.rfind(user, :id => item))
    assert_equal(item, Items.rfind(user2, :id => item))
    item.write(user) do
      item.add_tag 'super'
    end
    assert_equal(['super'], item.tags.map{|t|t.name})
    item.write(user2) do
      item.add_tag 'bad'
    end
    assert_equal(['bad','super'], item.tags.map{|t|t.name}.sort)
  end

  def test_item_delete
    user = Users.register('foo', 'bar')
    Items.delete_all
    itemh = {:user => user, :text => "Private post"}
    item = Uploader.upload itemh
    assert(Items.rfind_all(user).include?(item))
    
    item.rdelete(user)
    assert(!Items.rfind_all(user).include?(item))

    item.rundelete(user)
    assert(Items.rfind_all(user).include?(item))
  end

end