require 'future/web/webapi_1'
require 'test/unit'

Req = Struct.new(:relative_path, :get, :post)

class MuryuDispatch
  class TileInfo
    def self.[](key)
      new
    end
    
    def self.view(q)
      %w(tileinfo1 tileinfo2 tileinfo3)
    end
    
    def view(q)
      'tile_info'
    end
  end
  
  class Items
    def self.[](key)
      new
    end
    
    def self.view(q)
      %w(items1 items2 items3)
    end
    
    def view(q)
      'items'
    end
  end
end

class TestDispatch < Test::Unit::TestCase
  def test_single
    r = Req.new('items/foo/2007/12-01-Mon/bob.jpg')
    rv = MuryuDispatch.dispatch(r)
    assert_equal(rv, 'items')
    r = Req.new('tile_info/x0.38y1.29z39w38h39')
    rv = MuryuDispatch.dispatch(r)
    assert_equal(rv, 'tile_info')
  end
  
  def test_list
    r = Req.new('items/')
    rv = MuryuDispatch.dispatch(r)
    assert_equal(rv, %w(items1 items2 items3))
  end
  
  def no_list
    r = Req.new('tile_info/')
    assert_raise(NoListQuery) {
      MuryuDispatch.dispatch(r)
    }
  end
end

class TestMuryuQuery < Test::Unit::TestCase
  def test_default
    q = MuryuQuery.new(Req.new('items/foo/2007/12-01-Mon/bob.jpg'))
    q2 = MuryuQuery.new(Req.new('items/48821'))
    q3 = MuryuQuery.new(Req.new('items'))
    q4 = MuryuQuery.new(Req.new('items/'))
    assert_equal(q.method, 'view')
    assert_equal(q2.method, 'view')
    assert_equal(q3.method, 'view')
    assert_equal(q4.method, 'view')
  end
  
  def test_simple
    q = MuryuQuery.new(Req.new('items/foo/2007/12-01-Mon/bob.jpg/json'))
    assert_equal(q.path, 'items/foo/2007/12-01-Mon/bob.jpg/json')
    assert_equal(q.method, 'json')
    assert_equal(q.list_query, false)
    assert_equal(q.get, nil)
    assert_equal(q.post, nil)
    assert_equal(q.key, 'foo/2007/12-01-Mon/bob.jpg')
    assert_equal(q.type, 'items')
  end
  
  def test_list_query
    q = MuryuQuery.new(Req.new('items/json', ''))
    assert_equal(q.path, 'items/json')
    assert_equal(q.method, 'json')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
    q = MuryuQuery.new(Req.new('items/delete', ''))
    assert_equal(q.method, 'delete')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
    q = MuryuQuery.new(Req.new('items', ''))
    assert_equal(q.method, 'view')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
    q = MuryuQuery.new(Req.new('items/', ''))
    assert_equal(q.method, 'view')
    assert_equal(q.list_query, true)
    assert_equal(q.get, '')
    assert_equal(q.key, nil)
    assert_equal(q.type, 'items')
  end
  
  def test_no_list_query
    assert_raise(MuryuQuery::NoListQuery){
      q = MuryuQuery.new(Req.new('users/', ''))
    }
    assert_raise(MuryuQuery::NoListQuery){
      q = MuryuQuery.new(Req.new('users', ''))
    }
    assert_raise(MuryuQuery::NoListQuery){
      q = MuryuQuery.new(Req.new('users/view', ''))
    }
    assert_raise(MuryuQuery::NoListQuery){
      q = MuryuQuery.new(Req.new('users/json', ''))
    }
    q = MuryuQuery.new(Req.new('users/bob/json', ''))
    assert_equal(q.path, 'users/bob/json')
    assert_equal(q.method, 'json')
    assert_equal(q.list_query, false)
    assert_equal(q.get, '')
    assert_equal(q.key, 'bob')
    assert_equal(q.type, 'users')
  end
  
  def test_bad_type
    assert_raise(MuryuQuery::UnknownType){
      q = MuryuQuery.new(Req.new('userz/', ''))
    }
    assert_raise(MuryuQuery::UnknownType){
      q = MuryuQuery.new(Req.new('userz/foo', ''))
    }
    assert_raise(MuryuQuery::UnknownType){
      q = MuryuQuery.new(Req.new('userzo', ''))
    }
  end
  
  def test_good_verb
    MuryuQuery.type_methods['users'].each{|m|
      q = MuryuQuery.new(Req.new('users/bob/'+m, ''))
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
      MuryuQuery.new(Req.new('items/039485'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('items/bob/foo.jpg'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('items/bob/200/10-10-Thu/foo.jpg'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('items/bob/2005/1-10-Thu/foo.jpg'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('items/bob/2005/10-10-Thu/foo.jpg/bats'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('users/bob/foo.jpg'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('tile_info/x0y0z0w0h0'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('tile_info/x0.0y0z0.0w0h0'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('tile/x0.0y0.0z0w0.0h0'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('tile/jbobjoakim'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('tile/x0.gyn.0z00.0h0'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('files/x0.0y0.0z0w0.0h0'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('files/039485'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('files/39485'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('files/bob/200/10-10-Thu/foo.jpg'))
    }
    assert_raise(MuryuQuery::BadKey){
      MuryuQuery.new(Req.new('files/bob/200/10-10-Thu/foo.jpg/bats'))
    }
  end
  
  def test_good_key
    MuryuQuery.new(Req.new('items/bob/2005/10-10-Thu/Foo.jpg'))
    MuryuQuery.new(Req.new('items/38682'))
    MuryuQuery.new(Req.new('files/bob/2005/10-10-Thu/Foo.jpg'))
    MuryuQuery.new(Req.new('users/bob'))
    MuryuQuery.new(Req.new('users/bob-badaluk'))
    MuryuQuery.new(Req.new('users/bob_badaluk'))
    MuryuQuery.new(Req.new('users/bob.badaluk'))
    MuryuQuery.new(Req.new('users/Bob.Badamuk'))
    MuryuQuery.new(Req.new('users/Bob.Badamuk-08_227'))
    MuryuQuery.new(Req.new('sets/bob/badamuk'))
    MuryuQuery.new(Req.new('sets/bob.b/adamuk-08227'))
    MuryuQuery.new(Req.new('sets/Bob.Badamuk-08_227/b-zark'))
    MuryuQuery.new(Req.new('sets/public/inter_worship'))
    MuryuQuery.new(Req.new('groups/badamuk'))
    MuryuQuery.new(Req.new('groups/adamuk-08227'))
    MuryuQuery.new(Req.new('groups/b-zark'))
    MuryuQuery.new(Req.new('groups/inter_worship'))
    MuryuQuery.new(Req.new('tile/x0.0y0.0z10w256h256'))
    MuryuQuery.new(Req.new('tile/x1.25y5.375z5w256h256'))
    MuryuQuery.new(Req.new('tile_info/x0.0y0.0z10w256h256'))
    MuryuQuery.new(Req.new('tile_info/x1.25y5.375z10w256h256'))
  end
  
  def test_good_items_get
    MuryuQuery.new(Req.new('items/', {
      'q' => 'set:bank user:bob account details'
    }))
    MuryuQuery.new(Req.new('items/json', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'audio_format,title,owner'
    }))
    MuryuQuery.new(Req.new('items/json', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'all'
    }))
    MuryuQuery.new(Req.new('items/json', {
      'q' => 'set:bank user:bob account details'
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/json', {
      'columns' => 'audio_format,title,owner'
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/json', {
      'columns' => 'all'
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/json', {}))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/view', {}))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/thumbnail', {}))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/file', {}))
    MuryuQuery.new(Req.new('files/foo/2007/10-10-Thu/bob.jpg'))
    MuryuQuery.new(Req.new('files/', {
      'q' => 'set:bank user:bob account details'
    }))
  end

  def test_good_items_post
    MuryuQuery.new(Req.new('items/upload', nil, {
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/edit', nil, {
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/delete', nil, {
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/undelete', nil, {
    }))
    MuryuQuery.new(Req.new('items/foo/2007/10-10-Thu/bob.jpg/purge', nil, {
      'password' => 'oi9825jau'
    }))
  end

  def test_good_sets_get
    MuryuQuery.new(Req.new('sets/', {
      'namespace' => 'bob', 'name' => 'bank'
    }))
    MuryuQuery.new(Req.new('sets/', {
      'namespace' => 'bob'
    }))
    MuryuQuery.new(Req.new('sets/', {
      'name' => 'bank'
    }))
    MuryuQuery.new(Req.new('sets/bob/bank/json', {
    }))
    MuryuQuery.new(Req.new('sets/bob/bank/view', {
    }))
    MuryuQuery.new(Req.new('sets/bob/bank/', {
    }))
  end

  def test_good_sets_post
    MuryuQuery.new(Req.new('sets/create', nil, {
      'name' => 'bank'
    }))
    MuryuQuery.new(Req.new('sets/bob/bank/edit', nil, {
      'name' => 'Bank'
    }))
    MuryuQuery.new(Req.new('sets/bob/Bank/delete', nil, {
    }))
    MuryuQuery.new(Req.new('sets/bob/Bank/undelete', nil, {
    }))
  end
  
  def test_good_users_get
    MuryuQuery.new(Req.new('users/bob/json', {
    }))
    MuryuQuery.new(Req.new('users/bob/view', {
    }))
    MuryuQuery.new(Req.new('users/bob', {
    }))
  end

  def test_good_users_post
    MuryuQuery.new(Req.new('users/create', nil, {
      'name' => 'bob', 'password' => 'oi9825jau'
    }))
    MuryuQuery.new(Req.new('users/bob/logout', nil, {
    }))
    MuryuQuery.new(Req.new('users/login', nil, {
      'name' => 'bob', 'password' => 'oi9825jau'
    }))
    MuryuQuery.new(Req.new('users/bob/edit', nil, {
      'password' => 'oi9825jau', 'new_password' => 'fo3004bat'
    }))
    MuryuQuery.new(Req.new('users/bob/delete', nil, {
      'password' => 'fo3004bat'
    }))
  end

  def test_good_groups_get
    MuryuQuery.new(Req.new('groups/bobonite/json', {
    }))
    MuryuQuery.new(Req.new('groups/bobonite/view', {
    }))
    MuryuQuery.new(Req.new('groups/bobonite', {
    }))
  end

  def test_good_groups_post
    MuryuQuery.new(Req.new('groups/create', nil, {
      'name' => 'babonite', 'public' => 'true'
    }))
    MuryuQuery.new(Req.new('groups/bobonite/edit', nil, {
      'name' => 'babanite', 'public' => 'false'
    }))
    MuryuQuery.new(Req.new('groups/bobonite/edit', nil, {
      'public' => 'true'
    }))
    MuryuQuery.new(Req.new('groups/bobonite/edit', nil, {
      'name' => 'bobonite'
    }))
    MuryuQuery.new(Req.new('groups/bobonite/delete', nil, {
    }))
    MuryuQuery.new(Req.new('groups/bobonite/undelete', nil, {
    }))
  end

  def test_good_tile_get
    MuryuQuery.new(Req.new('tile/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details'
    }))
    MuryuQuery.new(Req.new('tile_info/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'audio_format,title,owner'
    }))
    MuryuQuery.new(Req.new('tile_info/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details',
      'columns' => 'all'
    }))
    MuryuQuery.new(Req.new('tile_info/x1.25y5.375z10w256h256', {
      'q' => 'set:bank user:bob account details'
    }))
  end

end

