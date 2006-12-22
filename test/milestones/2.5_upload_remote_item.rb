require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future
  DATADIR = File.expand_path(File.dirname(__FILE__) + "/../data")
  def setup
    Users.register('foo', 'bar')
  end

  def test_upload_eigenclass_dot_org
    user = Users.login('foo', 'bar', 'my_session')
    2.times do 
      item = {:user => user, :source => "http://eigenclass.org"}
      i = Uploader.upload item
      assert(Items.find(:id => i))
      assert_equal(nil, i.read[/store_remote_item_error/],
                   "Some references couldn't be resolved.")
    end
  end
end
