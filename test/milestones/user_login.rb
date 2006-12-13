require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class TestLogin < Test::Unit::TestCase
include Future

  def register
    Users.register("foo", "bar")
  end
  
  def login
    Users.login("foo", "bar", "my_session")
  end

  def logout
    Users.logout("foo", "my_session")
  end
  
  def test_user_login
    assert(!Users.find(:name => 'foo'))
    register
    assert(Users.find(:name => 'foo'))
    assert(!Sessions.find(:session_id => 'my_session', 'user.name' => 'foo'))
    login
    assert(Sessions.find(:session_id => 'my_session', 'user.name' => 'foo'))
    logout
    assert(!Sessions.find(:session_id => 'my_session', 'user.name' => 'foo'))
  end
  
end


