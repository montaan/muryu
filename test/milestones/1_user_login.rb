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

  def test_user_login
    u = register
    assert(Users.find(:name => 'foo'))
    u.terminate_all_sessions
    assert(!Sessions.find(:session_id => 'my_session', 'user.name' => 'foo'))
    user = login
    assert(Sessions.find(:session_id => 'my_session', 'user.name' => 'foo'))
    user.logout
    assert(!Sessions.find(:session_id => 'my_session', 'user.name' => 'foo'))
  end
  
end


