require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/config'
require "future/imaging/tile_drawer"
require 'ostruct'


class TileDrawerTest < Test::Unit::TestCase
include Future

  def cache_setup name
    cache_path = Pathname.new(File.dirname(__FILE__)) + "data/tile_drawer_cache_#{name}"
    cache_path.rmtree if cache_path.exist?
    @image_cache = ImageCache.new cache_path
  end

  def item(thumbnail, deleted=false)
    OpenStruct.new(:thumbnail => thumbnail, :deleted => deleted)
  end

  def test_photographs
    cache_setup 'photos'
    photos = Dir[File.join(File.dirname(__FILE__), "data/images/*")].sort
    @image_cache.batch do
      photos.each_with_index do |photo, i|
        @image_cache.update_cache_at(
          i,
          item(photo, false)
        )
      end
    end
    td = TileDrawer.new(@image_cache)
    td.reload_image_cache
    rindexes = (0...photos.size).to_a.map{|i| [i,0]}
    indexes = [rindexes.size].pack("N") + rindexes.transpose.map{|ix| ix.pack("I*") }.join
    palette = {0=>[0,0,0,0]}
    x,y,w,h = 0, 0, 256, 256
    pn = Pathname.new(File.dirname(__FILE__)).join("data", "tile_drawer_output")
    pn.rmtree if pn.exist?
    pn.mkdir
    (0..11).each{|zoom|
      (0..9).each{|x|
        tilefile = pn + "#{"%.2d_%.2d_%.2d" % [zoom,x,y]}.jpg"
        tile = td.draw_tile([0,0,0,255],indexes, palette, :rows, x*w, y*h, zoom, w, h)
        if tile
          if tile.is_a?(String)
            tilefile.open("wb"){|f| f.write Tiles.string_to_jpeg(tile,256,256,90) }
          else
            tile.save(tilefile.to_s)
          end
        else
          break
        end
      }
    }
    t = @image_cache.instance_variable_get("@jpeg_tiles")
    data = t.load_tile_at(1, 0, 0, 0)
    img = Imlib2::Image.create_using_data(256,256,data)
    img.has_alpha = true
    img.save(pn + "_8_0_cache.png")
    img.delete!(true)
  end

end

