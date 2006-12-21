require 'future/imaging/image_cache'


module Future


module Tiles
extend self

  def open(user, query, *tile_args, &block)
    indexes = Items.rfind_all(user, query.merge(:columns => [:image_index])).
                    map{|i| i.image_index }
    tile = TileDrawer.new.draw_tile(*tile_args)
    if tile
      fn = Future.tile_cache_dir + "tile.jpg" ### FIXME
      tile.save(fn.to_s)
    else
      fn = Future.empty_tile
    end
    fn.open('rb', &block)
  end

end


class TileDrawer

  LAYOUTERS = {}

  def initialize(image_cache = Future.image_cache)
    @image_cache = image_cache
  end

  def draw_tile(layouter_name, indexes, x, y, zoom, w, h)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.inspect}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    empty_tile = true
    layouter.each(indexes, x, y, sz, w, h) do |i, ix, iy|
      empty_tile = false
      break
    end
    return false if empty_tile
    tile = Imlib2::Image.new(w,h)
    tile.clear
    @image_cache.batch do
      layouter.each(indexes, x, y, sz, w, h) do |i, ix, iy|
        @image_cache.draw_image_at(i, zoom, tile, ix, iy)
      end
    end
    tile
  end


  module RowLayouter
  extend self

    def each(indexes, x, y, sz, w, h,
                  row_offset = sz / 2, columns = 200, rows = 5)
      bigrow_height = (rows*sz) + row_offset
      bigrow_img_count = columns * rows
      
      item_count = indexes.size
      bigrows = (item_count.to_f / bigrow_img_count).ceil.to_i
      
      all_rows = bigrows * 5
      
      first_bigrow_in_view = y / bigrow_height
      last_bigrow_in_view = (y+h) / bigrow_height
      first_bigrow_offset = row_offset * first_bigrow_in_view
      last_bigrow_offset = row_offset * last_bigrow_in_view
      
      first_row_in_view = (y-first_bigrow_offset) / sz
      last_row_in_view = (y+h-last_bigrow_offset) / sz
      
      first_row_y = first_row_in_view * sz + first_bigrow_offset
      y_offset = y - first_row_y
      
      first_column_in_view = x / sz
      last_column_in_view = (x+h) / sz

      (first_row_in_view..last_row_in_view).each_with_index do |r,i|
        next if r > all_rows or r < 0
        bigrow = r / rows
        iy = i*sz - y_offset + row_offset*(bigrow-first_bigrow_in_view)
        (first_column_in_view..last_column_in_view).each_with_index do |c,j|
          next if c >= columns or c < 0
          ix = j*sz - x%sz
          iindex = bigrow * bigrow_img_count + c * rows + r
          index = indexes[iindex]
          next unless index
          yield(index, ix, iy)
        end
      end
    end

  end # RowLayouter
  LAYOUTERS['rows'] = RowLayouter


end # TileDrawer


end # Future
