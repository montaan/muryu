require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/config'
require "future/imaging/image_cache"
require 'ostruct'


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

  def test_add_image
    cache_setup 'add'
    (0..10).each do |i|
      @image_cache.update_cache_at(
        i,
        item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
      )
    end
  end

  def test_update_image
    cache_setup 'update'
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

  def test_delete_image
    cache_setup 'delete'
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

  def test_tile_span
    cache_setup 'tile_span'
    (0..10).each do |i|
      @image_cache.update_cache_at(
        2**i,
        item(File.join(File.dirname(__FILE__), "data/images/#{i}.png"), false)
      )
    end
  end

end

