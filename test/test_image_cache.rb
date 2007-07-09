require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/config'
require "future/imaging/image_cache"
require 'ostruct'
require 'digest/md5'

Thread.abort_on_exception = true

class ImageCacheTest < Test::Unit::TestCase
include Future

  def cache_setup name
    cache_path = Pathname.new(File.dirname(__FILE__)) + "data/image_cache_#{name}"
    cache_path.rmtree if cache_path.exist?
    @image_cache = ImageCache.new cache_path
  end

  def item(thumbnail, deleted=false)
    OpenStruct.new(:thumbnail => thumbnail, :deleted => deleted)
  end
  
  def test_read_empty
    cache_setup 'empty'
    assert_equal(@image_cache.read_images_as_jpeg(5, [0]), "\000\000\000\000")
    assert_equal(@image_cache.read_images_as_jpeg(6, [0]), "\000\000\000\000")
    assert_equal(@image_cache.read_images_as_jpeg(7, [0]), "\000\000\000\000")
  end

  def test_add_image
    cache_setup 'add'
    @image_cache.batch do
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
        )
      end
    end
  end

  def test_multiple_threads
    cache_setup 'threads'
    ts = []
    @image_cache.batch do
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
        )
      end
    end
    raws = (0..10).map{|i| @image_cache.read_images_as_string(3, [i]) }
    jpegs = (0..10).map{|i| @image_cache.read_images_as_jpeg(5, [i]) }
    (0..20).each do |i|
      ts << Thread.new do
        @image_cache.update_cache_at(
          i*100,
          item(File.join(File.dirname(__FILE__), "data/images/#{i % 11}.png"), false)
        )
        assert_equal(
          raws[i % 11], @image_cache.read_images_as_string(3, [i*100])
        )
        assert_equal(
          jpegs[i % 11], @image_cache.read_images_as_jpeg(5, [i*100])
        )
      end
    end
    ts.each{|t| t.join }
  end

  def test_jpeg_span
    cache_setup 'threads'
    ts = []
    @image_cache.use_db = false
    @image_cache.batch do
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
        )
      end
    end
    jpegs = (0..10).map{|i| @image_cache.read_images_as_jpeg(7, [i]) }
    10.downto(0) do |i|
      @image_cache.update_cache_at(
        2040+i,
        item(File.join(File.dirname(__FILE__), "data/images/#{i % 11}.png"), false)
      )
      assert_equal(
        jpegs[i % 11], @image_cache.read_images_as_jpeg(7, [2040+i])
      )
    end
    10.downto(0) do |i|
      @image_cache.update_cache_at(
        4090+i,
        item(File.join(File.dirname(__FILE__), "data/images/#{i % 11}.png"), false)
      )
      assert_equal(
        jpegs[i % 11], @image_cache.read_images_as_jpeg(7, [4090+i])
      )
    end
    0.upto(10) do |i|
      @image_cache.update_cache_at(
        4090+i,
        item(File.join(File.dirname(__FILE__), "data/images/#{i % 11}.png"), false)
      )
      assert_equal(
        jpegs[i % 11], @image_cache.read_images_as_jpeg(7, [4090+i])
      )
    end
    td = TileDrawer.new(@image_cache)
    jp = @image_cache.instance_variable_get("@jpeg_pyramid")
    (0..2).each{|i|
      jp.open_at(7, i*2048, 'rb'){|f,sz|
        len = f.stat.size
        f.seek(0)
        header = f.read(2048*4).unpack("N*")
        prev = header.shift
        assert_equal(2048*4, prev, "First index should be at end of header")
        idx = 2048*i
        until header.empty?
          f.seek(prev)
          jlen = f.read(4).unpack("I")[0]
          nxt = header.shift || len
          assert_equal(
            nxt-prev, jlen+4, "File #{i}, at index #{idx}: #{jlen+4}"
          )
          prev = nxt
          idx += 1
        end
      }
    }
    assert_equal(
      jpegs[0,8].join.size,
      @image_cache.read_span_as_jpeg(7, 2040, 2047).size
    )
    assert_equal(
      jpegs[8,3].join.size,
      @image_cache.read_span_as_jpeg(7, 2048, 2050).size
    )
    assert_equal(
      jpegs.join.size,
      @image_cache.read_span_as_jpeg(7, 2040, 2050).size
    )
    assert_equal(
      jpegs.join.size,
      @image_cache.read_span_as_jpeg(7, 4090, 4100).size
    )
    assert_equal(
      jpegs.join.size*2+2039*4,
      @image_cache.read_span_as_jpeg(7, 2040, 4100).size
    )
    assert_equal(
      Digest::MD5.new(jpegs[0,8].join).hexdigest,
      Digest::MD5.new(@image_cache.read_span_as_jpeg(7, 2040, 2047)).hexdigest
    )
    assert_equal(
      Digest::MD5.new(jpegs[8,3].join).hexdigest,
      Digest::MD5.new(@image_cache.read_span_as_jpeg(7, 2048, 2050)).hexdigest
    )
    assert_equal(
      Digest::MD5.new(jpegs.join).hexdigest,
      Digest::MD5.new(@image_cache.read_span_as_jpeg(7, 2040, 2050)).hexdigest
    )
    assert_equal(
      Digest::MD5.new(jpegs.join).hexdigest,
      Digest::MD5.new(@image_cache.read_span_as_jpeg(7, 4090, 4100)).hexdigest
    )
    assert_equal(
      Digest::MD5.new(jpegs.join).hexdigest,
      Digest::MD5.new(@image_cache.read_images_as_jpeg(7, (2040..2044).to_a+(4095..4100).to_a)).hexdigest
    )
    assert_equal(
      Digest::MD5.new(jpegs.join+("\000\000\000\000"*2039)+jpegs.join).hexdigest,
      Digest::MD5.new(@image_cache.read_span_as_jpeg(7, 2040, 4100)).hexdigest
    )
  end

  def test_update_image
    cache_setup 'update'
    @image_cache.batch do
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
        )
      end
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{10-i}.png"), false)
        )
      end
    end
  end

  def test_delete_image
    cache_setup 'delete'
    @image_cache.batch do
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
        )
      end
      (0..10).each do |i|
        @image_cache.update_cache_at(
          i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), true)
        )
      end
    end
  end

  def test_tile_span
    cache_setup 'tile_span'
    @image_cache.batch do
      (0..10).each do |i|
        @image_cache.update_cache_at(
          2**i,
          item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
        )
      end
    end
  end

  def test_photographs
    cache_setup 'photos'
    photos = Dir[File.join(File.dirname(__FILE__), "data/images/*.JPG")]
    @image_cache.batch do
      photos.each_with_index do |photo, i|
        @image_cache.update_cache_at(
          i,
          item(photo, false)
        )
      end
    end
  end

end

