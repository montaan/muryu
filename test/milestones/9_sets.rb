require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def setup
    @foo = Users.register('foo', 'bar')
    @baz = Users.register('baz', 'qux')
  end

  def teardown
    Users.delete_all # delete cascade wipes the whole database
  end

  def test_set_create
    s = Sets.rfind_or_create(@foo, :name => 'todo')
    t1 = Uploader.upload :user => @foo, :text => "Write a todo", :sets => [s]
    t2 = Uploader.upload :user => @foo, :text => "Remove the first item", :sets => [s]
    assert_equal([t1,t2], s.items.sort)
  end

  def test_set_visibility
    s = Sets.rfind_or_create(@foo, :name => 'todo')
    s2 = Sets.rfind_or_create(@baz, :name => 'todo')

    assert_equal([s], Sets.rfind_all(@foo, :name => 'todo'))
    assert_equal([s2], Sets.rfind_all(@baz, :name => 'todo'))

    s3 = Sets.rfind_or_create(@foo, :name => 'todo', :public => true)
    assert_equal([s, s3], Sets.rfind_all(@foo, :name => 'todo').sort)
    assert_equal([s2, s3], Sets.rfind_all(@baz, :name => 'todo').sort)
  end

  def test_set_delete
    s = Sets.rfind_or_create(@foo, :name => 'todo')
    assert_equal([s], Sets.rfind_all(@foo, :name => 'todo'))
    s.rdelete(@foo)
    assert_equal([], Sets.rfind_all(@foo, :name => 'todo'))
    assert_equal([s], Sets.rfind_all(@foo, :name => 'todo', :deleted => true))
    s.rundelete(@foo)
    assert_equal([s], Sets.rfind_all(@foo, :name => 'todo'))
  end

  def test_set_edit
    s = Sets.rfind_or_create(@foo, :name => 'todo')
    t1 = Uploader.upload :user => @foo, :text => "Write a todo", :sets => [s]
    t2 = Uploader.upload :user => @foo, :text => "Remove the first item", :sets => [s]
    assert_equal([t1,t2], s.items.sort)
    
    s.name = 'my todo'
    s = Sets.rfind_or_create(@foo, :name => 'my todo')
    assert_equal([t1,t2], s.items.sort)
    assert !Sets.rfind(@foo, :name => 'todo')
  end

end