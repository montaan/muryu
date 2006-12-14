require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def test_item_visibility
    user = Users.register('foo', 'bar')
    user2 = Users.register("baz", "qux")

    item = {:user => user, :text => "Private post"}
    i = Uploader.upload item
    assert_equal(i, Items.rfind(user, :id => i))
    assert_equal(nil, Items.rfind(user2, :id => i))
    
    item = {:user => user, :text => "Public post",
            :groups => [[Groups.public, false]]}
    j = Uploader.upload item
    assert_equal(j, Items.rfind(user, :id => j))
    assert_equal(j, Items.rfind(user2, :id => j))
  end

end