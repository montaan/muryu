require File.join(File.dirname(__FILE__), "../set_include_path.rb")

require 'future/config'
require "future/imaging/tile_drawer"
require 'ostruct'
require 'benchmark'

include Future

def cache_setup name, type='tga'
  cache_path = Pathname.new(File.dirname(__FILE__)) + "tmp/tile_drawer_cache_#{name}"
  cache_path.rmtree if cache_path.exist?
  @image_cache = ImageCache.new cache_path, type
end

def item(thumbnail, deleted=false)
  OpenStruct.new(:thumbnail => thumbnail, :deleted => deleted)
end

def draw_1x1_tile
  cache_setup 'perf'
  photos = Dir[File.join(File.dirname(__FILE__), "data/images/*.JPG")][0,8]
  @image_cache.batch do
    photos.each_with_index do |photo, i|
      @image_cache.update_cache_at(
        i,
        item(photo, false)
      )
    end
  end
  indexes = (0...8).to_a*8192
  td = TileDrawer.new(@image_cache)
  x,y,w,h = 0, 0, 256, 256
  pn = Pathname.new(File.dirname(__FILE__)).join("data", "tile_drawer_perf.jpg")
  pn.unlink if pn.exist?
  Benchmark.bm do |re|
    re.report do
      tile = td.draw_tile(indexes, :rows, x, y, 0, w, h, 0, 256, 256)
      tile.save(pn.to_s)
    end
  end
end

draw_1x1_tile
