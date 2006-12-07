
require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift "lib"

require 'future/storage'
require 'fileutils'

class TestBasicStorage < Test::Unit::TestCase

  def setup
    @tmpdir = File.join(File.dirname(File.expand_path(__FILE__)), "storage-#{Process.pid}")
    FileUtils.rm_rf @tmpdir
    @store = Future::BasicStore.new(@tmpdir)
  end

  DATA = "foo " * 1000
  def test_store
    ret = @store.store("foo.txt", DATA)
    assert_kind_of(Future::BasicStore::FileSelector, ret)
    assert_equal("e65ed8dde2b3df94e9a63c509a62b356b82de03f", ret.sha1digest)
    assert_equal("e6/5e/d8dde2b3df94e9a63c509a62b356b82de03f/data", ret.path)
  end

  def test_store_parts
    html = "foo"
    ret = @store.store("foo.gif", "1234", :sha1digest => Digest::SHA1.hexdigest(html),
                       :preserve_name => true)
    assert_equal(true, @store.include?(ret))
    assert_equal("0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33", ret.sha1digest)
    assert_equal("0b/ee/c7b5ea3f0fdbc95d0dd47f3c5bc275da8a33/foo.gif", ret.path)
    ret = @store.store("foo.baz", "5678", :sha1digest => Digest::SHA1.hexdigest(html),
                       :preserve_name => true)
    assert_equal(true, @store.include?(ret))
    assert_equal("0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33", ret.sha1digest)
    assert_equal("0b/ee/c7b5ea3f0fdbc95d0dd47f3c5bc275da8a33/foo.baz", ret.path)
  end

  def test_read
    ret = @store.store("foo.txt", "foo " * 1000)
    assert_equal(DATA, @store.read(ret))
    sel = Future::BasicStore::FileSelector.new(:sha1digest => ret.sha1digest)
    assert_equal(DATA, @store.read(sel))
  end

  def test_open
    ret = @store.store("foo.txt", "foo " * 1000)
    assert_equal(DATA, @store.open(ret).read)
  end

  def test_include?
    ret = @store.store("foo.txt", "foo " * 1000)
    assert_equal(true, @store.include?(ret))
  end

  def teardown
    FileUtils.rm_rf @tmpdir
  end
end

