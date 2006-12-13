require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def test_create_text_post
    user = Users.login('foo', 'bar', 'my_session')
    item = {:user => user, :text => "Hello, World!"}
    i = Uploader.upload item
    assert(Items.find(:id => i))
    assert_equal(i.read, "Hello, World!")
  end

end