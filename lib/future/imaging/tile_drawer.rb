require 'future/imaging/image_cache'
require 'digest/sha1'

module Future


module Tiles
extend self

  def open(user, query, *tile_args, &block)
    indexes = Items.rfind_all(user, query.merge(:columns => [:image_index])).
                    map{|i| i.image_index }
    tile = TileDrawer.new.draw_tile(indexes, *tile_args)
    Future.tile_cache_dir.mkdir_p
    if tile
      ### FIXME cache badness
      r,x,y,z,w,h = *tile_args
      qtext = sanitize_query(query)
      fn = Future.tile_cache_dir + %!tile_#{qtext}_#{[r,"#{w}x#{h}",z,x,y].join("_")}.jpg!
      tmp = Future.tile_cache_dir + "tmptile-#{Process.pid}-#{Thread.object_id}.jpg"
      tile.save(tmp)
      File.rename(tmp, fn.to_s)
    else
      fn = Future.empty_tile
      unless fn.exist?
        img = Imlib2::Image.new(*tile_args[-2,2])
        img.clear
        img.save(fn.to_s)
      end
    end
    fn.open('rb', &block)
  end

  private
  def sanitize_query(query)
    str = query.to_a.sort_by{|k,v| k}.map do |key, val| 
      [key, val].map{|str| str.to_s.gsub(/[^A-Za-z0-9_]/){|x| "%%%02X" % x[0]}}.join("_")
    end.join("+")
    if str.size < 40
      str
    else
      Digest::Sha1.hexdigest(str)
    end
  end

end


class TileDrawer

  LAYOUTERS = {}

  def initialize(image_cache = Future.image_cache)
    @image_cache = image_cache
  end

  def draw_tile(indexes, layouter_name, x, y, zoom, w, h)
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
