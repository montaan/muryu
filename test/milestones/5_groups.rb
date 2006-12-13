require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class TestGroups < Test::Unit::TestCase
include Future

  def register
    Users.register("foo", "bar")
    Users.register("baz", "qux")
  end
  
  def login
    @user = Users.login("foo", "bar", "my_session")
    @user2 = Users.login("baz", "qux", "mah_session")
  end

  def setup
    register
    login
  end

  def teardown
    @user.logout
    @user2.logout
    unregister
  end

  def test_group
    assert(Groups.find_all(@user, :name => 'foo fighters').empty?)
    assert(Groups.find_all(@user2, :name => 'foo fighters').empty?)

    ff = Groups.create(:name => 'foo fighters', :owner => @user, :public => false)
    assert(Groups.find_all(@user, :name => 'foo fighters').size == 1)
    assert(Groups.find_all(@user2, :name => 'foo fighters').empty?)
    
    bb = Groups.create(:name => 'baz buzzers', :owner => @user2, :public => true)
    assert(Groups.find_all(@user, :name => 'baz buzzers').size == 1)
    assert(Groups.find_all(@user2, :name => 'baz buzzers').size == 1)

    ff.add_member @user2
    assert(Groups.find_all(@user2, :name => 'foo fighters').size == 1)
    
    ff.remove_member @user2
    assert(Groups.find_all(@user2, :name => 'foo fighters').empty?)

    Groups.delete(:name => 'baz buzzers')
    assert(Groups.find_all(@user, :name => 'baz buzzers').size == 0)
    assert(Groups.find_all(@user2, :name => 'baz buzzers').size == 0)
  end
  
end


