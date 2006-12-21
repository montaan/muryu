require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/config'
require "future/imaging/tile_drawer"
require 'ostruct'


class TileDrawerTest < Test::Unit::TestCase
include Future

  def cache_setup name, type='png'
    cache_path = Pathname.new(File.dirname(__FILE__)) + "data/tile_drawer_cache_#{name}"
    cache_path.rmtree if cache_path.exist?
    @image_cache = ImageCache.new cache_path, type
  end

  def item(thumbnail, deleted=false)
    OpenStruct.new(:thumbnail => thumbnail, :deleted => deleted)
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
    td = TileDrawer.new(@image_cache)
    indexes = (0...photos.size).to_a
    x,y,w,h = 0, 0, 256, 256
    zoom = 4
    tilefile = Pathname.new(File.dirname(__FILE__)) +
               "data/tile_drawer_test_photographs.jpg"
    tile = td.draw_tile(:rows, indexes, x, y, zoom, w, h)
    tile.save(tilefile.to_s)
  end

end

