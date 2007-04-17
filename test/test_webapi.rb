require 'future/web/webapi_1'
require 'test/unit'

Req = Struct.new(:relative_path, :get, :post, :cookies)
class Req
  def initialize(rp, get=nil, post=nil, cookies=nil)
    get.each{|k,v| get[k] = [v] unless v.is_a?(Array) } if get
    post.each{|k,v| post[k] = [v] unless v.is_a?(Array) } if post
    super(rp, get, post, cookies)
  end
end

module MuryuDispatch
  module TileInfo
    def self.[](key)
      Ti.new
    end
    
    def self.view(q,r)
      r.body = %w(tileinfo1 tileinfo2 tileinfo3)
    end
    
    class Ti
      def view(q,r)
        r.body = 'tile_info'
      end
    end
  end
  
  module Items
    def self.[](key)
      It.new
    end
    
    def self.view(q,r)
      r.body = %w(items1 items2 items3)
    end
    
    class It
      def view(q,r)
        r.body = 'items'
      end
    end
  end
end

class TestDispatch < Test::Unit::TestCase
  def test_single
    r = Req.new('items/foo/2007/12-01/bob.jpg')
    rv = MuryuDispatch.dispatch(r)
    assert_equal(rv.body, 'items')
    r = Req.new('tile_info/x0.38y1.29z39w38h39')
    rv = MuryuDispatch.dispatch(r)
    assert_equal(rv.body, 'tile_info')
  end
  
  def test_list
    r = Req.new('items/')
    rv = MuryuDispatch.dispatch(r)
    assert_equal(rv.body, %w(items1 items2 items3))
  end
  
  def no_list
    r = Req.new('tile_info/')
    assert_raise(NoListQuery) {
      MuryuDispatch.dispatch(r)
    }
  end
end

class TestMuryuQuery < Test::Unit::TestCase
  def mq(*args)
    MuryuQuery.new(Req.new(*args))
  end

  class MockFile < Hash
    def initialize
      super
      self[:filename] = self[:tempfile] = true
    end
  end

  def test_default
    q = mq('items/foo/2007/12-01/bob.jpg')
    q2 = mq('items/48821')
    q3 = mq('items')
    q4 = mq('items/')
    assert_equal(q.method, 'view')
    assert_equal(q2.method, 'view')
    assert_equal(q3.method, 'view')
    assert_equal(q4.method, 'view')
  end
  
  def test_simple
    q = mq('items/foo/2007/12-01/bob.jpg/json')
    assert_equal(q.path, 'items/foo/2007/12-01/bob.jpg/json')
    assert_equal(q.method, 'json')
    assert_equal(q.list_query, false)
    assert_equal(q.get, nil)
    assert_equal(q.post, nil)
    assert_equal(q.key, 'foo/2007/12-01/bob.jpg')
    assert_equal(q.type, 'items')
  end
  
  def test_list_query
    q = mq('items/json', '')
    assert_equal(q.path, 'items/json')
    assert_equal(q.method, 'json')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
    q = mq('items/delete', '')
    assert_equal(q.method, 'delete')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
    q = mq('items', '')
    assert_equal(q.method, 'view')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
    q = mq('items/', '')
    assert_equal(q.method, 'view')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
  end
  
  def test_no_list_query
    assert_raise(MuryuQuery::NoListQuery){
      q = mq('users/', '')
    }
    assert_raise(MuryuQuery::NoListQuery){
      q = mq('users', '')
    }
    assert_raise(MuryuQuery::NoListQuery){
      q = mq('users/view', '')
    }
    assert_raise(MuryuQuery::NoListQuery){
      q = mq('users/json', '')
    }
    q = mq('users/bob/json', '')
    assert_equal(q.path, 'users/bob/json')
    assert_equal(q.method, 'json')
    assert_equal(q.list_query, false)
    assert_equal(q.get, '')
    assert_equal(q.key, 'bob')
    assert_equal(q.type, 'users')
  end
  
  def test_bad_type
    assert_raise(MuryuQuery::UnknownType){
      q = mq('userz/', '')
    }
    assert_raise(MuryuQuery::UnknownType){
      q = mq('userz/foo', '')
    }
    assert_raise(MuryuQuery::UnknownType){
      q = mq('userzo', '')
    }
  end
  
  def test_good_verb
    MuryuQuery.type_methods['users'].each{|m|
      q = mq('users/bob/'+m, '')
      assert_equal(q.path, 'users/bob/'+m)
      assert_equal(q.method, m)
      assert_equal(q.list_query, false)
      assert_equal(q.get, '')
      assert_equal(q.key, 'bob')
      assert_equal(q.type, 'users')
    }
  end

  def test_bad_key
    assert_raise(MuryuQuery::BadKey){
      mq('items/039485')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('items/bob/foo.jpg')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('items/bob/200/10-10/foo.jpg')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('items/bob/2005/1-10/foo.jpg')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('items/bob/2005/10-10/foo.jpg/bats')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('users/bob/foo.jpg')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('tile_info/x0y0z0w0h0')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('tile_info/x0.0y0z0.0w0h0')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('tile/x0.0y0.0z0w0.0h0')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('tile/jbobjoakim')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('tile/x0.gyn.0z00.0h0')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('files/x0.0y0.0z0w0.0h0')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('files/039485')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('files/39485')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('files/bob/200/10-10/foo.jpg')
    }
    assert_raise(MuryuQuery::BadKey){
      mq('files/bob/200/10-10/foo.jpg/bats')
    }
  end
  
  def test_good_key
    mq('items/bob/2005/10-10/Foo.jpg')
    mq('items/38682')
    mq('files/bob/2005/10-10/Foo.jpg')
    mq('users/bob')
    mq('users/bob-badaluk')
    mq('users/bob_badaluk')
    mq('users/bob.badaluk')
    mq('users/Bob.Badamuk')
    mq('users/Bob.Badamuk-08_227')
    mq('sets/bob/badamuk')
    mq('sets/bob.b/adamuk-08227')
    mq('sets/Bob.Badamuk-08_227/b-zark')
    mq('sets/public/inter_worship')
    mq('groups/badamuk')
    mq('groups/adamuk-08227')
    mq('groups/b-zark')
    mq('groups/inter_worship')
    mq('tile/x0.0y0.0z10w256h256')
    mq('tile/x1.25y5.375z5w256h256')
    mq('tile_info/x0.0y0.0z10w256h256')
    mq('tile_info/x1.25y5.375z10w256h256')
  end
  
  def test_good_items_get
    mq('items/', {
      'q' => 'set:bank user:bob account details'
    })
    mq('items/json', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'metadata,owner'
    })
    mq('items/json', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'all'
    })
    mq('items/json', {
      'q' => 'set:bank user:bob account details'
    })
    mq('items/foo/2007/10-10/bob.jpg/json', {
      'columns' => 'metadata,owner'
    })
    mq('items/foo/2007/10-10/bob.jpg/json', {
      'columns' => 'all'
    })
    mq('items/foo/2007/10-10/bob.jpg/json', {})
    mq('items/foo/2007/10-10/bob.jpg/view', {})
    mq('items/foo/2007/10-10/bob.jpg/thumbnail', {})
    mq('items/foo/2007/10-10/bob.jpg/file', {})
    mq('files/foo/2007/10-10/bob.jpg')
    mq('files/', {
      'q' => 'set:bank user:bob account details'
    })
  end

  def test_good_items_post
    mq('items/upload', nil, {
    })
    mq('items/foo/2007/10-10/bob.jpg/edit', nil, {
    })
    mq('items/foo/2007/10-10/bob.jpg/delete', nil, {
    })
    mq('items/foo/2007/10-10/bob.jpg/undelete', nil, {
    })
    mq('items/foo/2007/10-10/bob.jpg/purge', nil, {
      'password' => 'oi9825jau'
    })
    mq('items/upload', nil, {
      'local_file' => MockFile.new,
      'local_archive' => MockFile.new,
    })
  end

  def test_bad_items_get
    assert_raise(MuryuQuery::BadGet){
      mq('items/foo/2007/10-10/bob.jpg/json', {
        'badamuk' => 'badaluk'})
    }
    assert_raise(MuryuQuery::BadGet){
      mq('items/foo/2007/10-10/bob.jpg/view', {
        'badamuk' => 'badaluk'})
    }
    assert_raise(MuryuQuery::BadGet){
      mq('items/foo/2007/10-10/bob.jpg/thumbnail', {
        'badamuk' => 'badaluk'})
    }
    assert_raise(MuryuQuery::BadGet){
      mq('items/foo/2007/10-10/bob.jpg/file', {
        'badamuk' => 'badaluk'})
    }
  end

  def test_bad_items_post
    assert_raise(MuryuQuery::BadPost){
      mq('items/foo/2007/10-10/bob.jpg/edit', nil, {
        'badamuk' => 'badaluk'})
    }
    assert_raise(MuryuQuery::BadPost){
      mq('items/upload', nil, {
        'local_file' => 'bababad'
      })
    }
    assert_raise(MuryuQuery::BadPost){
      mq('items/upload', nil, {
        'local_archive' => 'bababad'
      })
    }
  end
  
  def test_good_sets_get
    mq('sets/', {
      'owner' => 'bob', 'name' => 'bank'
    })
    mq('sets/', {
      'owner' => 'bob'
    })
    mq('sets/', {
      'name' => 'bank'
    })
    mq('sets/bob/bank/json', {
    })
    mq('sets/bob/bank/view', {
    })
    mq('sets/bob/bank/', {
    })
  end

  def test_good_sets_post
    mq('sets/create', nil, {
      'name' => 'bank'
    })
    mq('sets/bob/bank/edit', nil, {
      'name' => 'Bank'
    })
    mq('sets/bob/Bank/delete', nil, {
    })
    mq('sets/bob/Bank/undelete', nil, {
    })
  end
  
  def test_good_users_get
    mq('users/bob/json', {
    })
    mq('users/bob/view', {
    })
    mq('users/bob', {
    })
  end

  def test_good_users_post
    mq('users/create', nil, {
      'username' => 'bob', 'password' => 'oi9825jau'
    })
    mq('users/bob/logout', nil, {
    })
    mq('users/login', nil, {
      'username' => 'bob', 'password' => 'oi9825jau'
    })
    mq('users/bob/edit', nil, {
      'password' => 'oi9825jau', 'new_password' => 'fo3004bat'
    })
    mq('users/bob/delete', nil, {
      'password' => 'fo3004bat'
    })
  end

  def test_good_groups_get
    mq('groups/bobonite/json', {
    })
    mq('groups/bobonite/view', {
    })
    mq('groups/bobonite', {
    })
  end

  def test_good_groups_post
    mq('groups/create', nil, {
      'name' => 'babonite', 'public' => 'true'
    })
    mq('groups/bobonite/edit', nil, {
      'name' => 'babanite', 'public' => 'false'
    })
    mq('groups/bobonite/edit', nil, {
      'public' => 'true'
    })
    mq('groups/bobonite/edit', nil, {
      'name' => 'bobonite'
    })
    mq('groups/bobonite/delete', nil, {
    })
    mq('groups/bobonite/undelete', nil, {
    })
  end

  def test_good_tile_get
    mq('tile/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details'
    })
    mq('tile_info/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'metadata,owner'
    })
    mq('tile_info/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'all'
    })
    mq('tile_info/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details'
    })
  end

end

