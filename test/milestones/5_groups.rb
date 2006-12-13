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
  end

  def test_group
    UsersGroups.delete_all("group.namespace" => 'groups')
    Groups.delete_all(:namespace => 'groups')
    assert(Groups.rfind_all(@user, :name => 'foo fighters').empty?)
    assert(Groups.rfind_all(@user2, :name => 'foo fighters').empty?)

    ff = Groups.rcreate(:name => 'foo fighters', :owner => @user, :public => false)
    assert_equal(ff, Groups.rfind(@user, :name => 'foo fighters'))
    assert_equal(nil, Groups.rfind(@user2, :name => 'foo fighters'))
    
    bb = Groups.rcreate(:name => 'baz buzzers', :owner => @user2, :public => true)
    assert(Groups.rfind(@user, :name => 'baz buzzers'))
    assert(Groups.rfind(@user2, :name => 'baz buzzers'))

    ff.add_member @user, @user2
    assert(Groups.rfind(@user2, :name => 'foo fighters'))
    
    ff.remove_member @user, @user2
    assert_equal([], Groups.rfind_all(@user2, :name => 'foo fighters'))

    Groups.rdelete(@user2, :name => 'baz buzzers')
    assert_equal([], Groups.rfind_all(@user, :name => 'baz buzzers'))
    assert_equal([], Groups.rfind_all(@user2, :name => 'baz buzzers'))
  end
  
end


