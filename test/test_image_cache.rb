require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/config'
require "future/imaging/image_cache"
require 'ostruct'
Thread.abort_on_exception = true

class ImageCacheTest < Test::Unit::TestCase
include Future

  def cache_setup name, type='tga'
    cache_path = Pathname.new(File.dirname(__FILE__)) + "data/image_cache_#{name}"
    cache_path.rmtree if cache_path.exist?
    @image_cache = ImageCache.new cache_path, type
  end

  def item(thumbnail, deleted=false)
    OpenStruct.new(:thumbnail => thumbnail, :deleted => deleted)
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
    (0..10).each do |i|
      ts << Thread.new do
        @image_cache.update_cache_at(
          i%11,
          item(File.join(File.dirname(__FILE__), "data/images/#{i%11}.png"), false)
        )
      end
    end
    (0..10).each do |i|
      ts << Thread.new do
        @image_cache.update_cache_at(
          i%11,
          item(File.join(File.dirname(__FILE__), "data/images/#{10-(i%11)}.png"), false)
        )
      end
    end
    ts.each{|t| t.join }
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

