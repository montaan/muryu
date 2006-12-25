require 'future/imaging/image_cache'
require 'digest/sha1'

module Future


module Tiles
extend self

  def open(user, query, *tile_args, &block)
    ### FIXME query optimization problematic (need to layout to get wanted spans,
    ###       then do a query for each (semi-)continuous span, e.g. layout says
    ###       that 4-10, 16-22, 28-34, 4182-4188, 4194-4200 needed
    ###       -> get 4-34, 4182-4200)
    ###
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

  def info(user, query, *tile_args, &block)
    ### FIXME Query optimization problematic (again.)
    ###       Want to get a list of fields for the items, but don't want to do
    ###       infos.map{|k,v| Items.find(:image_index => i, :columns => ...)}
    ###       and Items.find_all(:image_index => infos.keys, :columns => ...)
    ###       will likely run into query size limit.
    indexes = Items.rfind_all(user, query.merge(:columns => [:image_index])).
                    map{|i| i.image_index }
    infos = {}
    TileDrawer.new.tile_info(indexes, *tile_args){|i, *a| infos[i] = a}
    infos
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

  ### Optimize: 
  ### considerations: 256x256 tile = 65kquads max mesh size
  ###                 timed drawing 65k items: 
  ###                   total time 2395ms
  ###                      - one texture load @ 2ms
  ###                      - one save jpg @ 3ms
  ###                      - 300ms to iterate the layout = slow!
  ###                      - 230ms to call Imlib2::Image#blend! = slow!
  ###                      - 1860ms for ImageCache#draw_image_at overhead = SLOW!
  ###                 texture load 2ms per tex, texture memory usage 1 meg
  ###                 image save 3ms 
  ### 1Mitems => 
  ###   4x     1x1     cache images   4MB, 65536 images per tile, max 4   cache images per tile = 8ms   (131 072ms @ 256Mitems)
  ###   16x    2x2     cache images  16MB, 16384 images per tile, max 16  cache images per tile = 32ms  ( 32 768ms @ 64Mitems )
  ###   64x    4x4     cache images  64MB, 4096  images per tile, max 64  cache images per tile = 128ms (  8 192ms @ 16Mitems )
  ###   256x   8x8     cache images 256MB, 1024  images per tile, max 256 cache images per tile = 512ms (  2 048ms @ 4Mitems  )
  ###   1024x  16x16   cache images   1GB, 256   images per tile, max 256 cache images per tile = 512ms
  ###   4096x  32x32   cache images   4GB, 64    images per tile, max 64  cache images per tile = 128ms
  ###   16384x 64x64   cache images  16GB, 16    images per tile, max 16  cache images per tile = 32ms
  ###   65536x 128x128 cache images  64GB, 4     images per tile, max 4   cache images per tile = 8ms
  ### => worst case: 256 cache images needed for drawing a tile == 512ms to load textures & 256MB mem use == not too bad
  ###
  ### Worst case probability: 
  ###   pick images_per_tile images from all images so that all image_index / images_per_cache_image are different
  ###   "there are images socks in a box, images_per_cache_image of each color, what is the probability of picking images_per_tile
  ###    differently colored socks from the box?"
  ###   (1...images_per_tile).inject(1){|s,i| s * ((images-i*images_per_cache_image.to_f)/(images-i)) }
  ###
  ### 1Mitems: 
  ### imgs = 2**24; (1..7).map{|z| ipt = 4**z; ipci = 4**(z+1); (1...ipt).inject(1){|s,i| s*(imgs-i*ipci.to_f)/(imgs-i) }} 
  ### imgs = 2**24; (1..7).map{|z| ipt = 4**z; ipci = 4**(z+1); (1...ipt).inject(1){|s,i| r=s*(imgs-i*ipci.to_f)/(imgs-i); break i if r < 0.95; r }} 
  ###   128x128 => 0.9999 => 8ms
  ###   64x64   => 0.9928 => 32ms
  ###   32x32   => 0.6109 => 128ms (4GB textures in total, doable to keep in RAM)
  ###   16x16   => 7.07e-16
  ###   
  ###   Total textures: 85 GB (25.5e @ 0.3e / GB of hard disk space)
  ###
  ### 16Mitems:
  ###   128x128 => 0.9999 (1TB textures)
  ###   64x64   => 0.9995 (256GB textures)
  ###   32x32   => 0.9698 (64GB textures)
  ###   16x16   => 0.1352 => 512ms
  ###   8x8     => 1.48e-61
  ###   
  ###   Total textures: 1365 GB (409e)
  ###
  ### 64Mitems:
  ###   32x32   => 0.9924 (256GB textures)
  ###   16x16   => 0.6076 (64GB textures)
  ###   
  ###   Total textures: 5461 GB (1638e)
  ###
  ### 256Mitems:
  ###   16x16   => 0.8830 (256GB textures)
  ###   
  ###   Total textures: 21845 GB (6552e)
  ###
  ### Expected performance: expected amount of cache images per tile per zoom level * 2ms 
  ###                       + 5ms draw&save time (pretty much constant)
  ### # random tiles are expensive
  ### 
  ### require 'pp'
  ### 
  ### sims = [2**20,2**24,2**26,2**28].map do |images| 
  ###   [ images, 
  ###     [4,16,64,256,1024,4096].map do |images_per_tile| 
  ###       cache_tiles = images/(images_per_tile*4)
  ###       arr = Hash.new(0)
  ###       1000.times do 
  ###         h = Hash.new(0)
  ###         images_per_tile.times { h[(rand*cache_tiles).to_i] += 1 }
  ###         arr[h.keys.size] += 1
  ###       end 
  ###       [ images_per_tile, 
  ###         arr.inject(0){|s,(k,v)| s + k*v } / 
  ###         arr.inject(0){|s,(k,v)| s+v }.to_f
  ###       ] 
  ###     end
  ###   ]
  ### end
  ### 
  ### pp sims 
  ### 
  ### [[1048576,
  ###   [[4, 4.0],        # 128x128
  ###    [16, 15.993],    # 64x64
  ###    [64, 63.511],    # 32x32
  ###    [256, 226.655],  # 16x16
  ###    [1024, 251.435], # 8x8
  ###    [4096, 64.0]]],  # 4x4
  ###  [16777216,
  ###   [[4, 4.0],
  ###    [16, 15.999], 
  ###    [64, 63.965], 
  ###    [256, 253.979], 
  ###    [1024, 905.779], 
  ###    [4096, 1005.274]]],
  ###  [67108864,
  ###   [[4, 4.0],
  ###    [16, 15.999], 
  ###    [64, 63.994], 
  ###    [256, 255.535], 
  ###    [1024, 992.65], 
  ###    [4096, 2588.624]]],
  ###  [268435456,
  ###   [[4, 4.0],
  ###    [16, 16.0], 
  ###    [64, 63.998], 
  ###    [256, 255.859], 
  ###    [1024, 1016.046], 
  ###    [4096, 3623.971]]]]
  ###
  ### It is probably possible to get best-case drawing performance to ~6-7ms, 
  ### or 5ms with cached texture, or 3ms with serving jpg from ram(?)
  ###
  ### Another thing that helps is that tile drawing is embarrassingly parallel.
  ###
  ### With 256Mitems and 4x4 random tile: required 3600 texture loads = 7.2s on a single computer.
  ###
  ### Split across 120 nodes and you have 30 texture loads per node = 60ms.
  ### If you have a 500MB/s (10Gbps) effective downstream to the composing node, it becomes
  ### 0.5ms to get one composed tile part (256x256x4 bytes) from the network, so 60ms for 120, 
  ### for a total draw time of 120ms.
  ###
  ### With a 100MB/s (1Gbps) network, transferring a composed tile takes 5ms.
  ### Introduce two levels of aggregation nodes, 120 -> 30 -> 6 -> 1 ?
  ### Draw is 60ms, first aggregation is 4 per aggregator: 20ms, second aggregation is 5 per
  ### aggregator: 25ms, third aggregation is 6 per aggregator: 30ms, for a total of 135ms.
  ###
  ### (Aggregation with a 10Gbps network: 480 -> 48 -> 4 -> 1, 15ms + 5ms + 6ms + 2ms = 28ms.)
  ###
  ### By having the aggregation nodes also do drawing, you can save 37 transfers out of 157.
  ### These are first-level results though, so the effect is equivalent to lowering the first
  ### aggregation time to somewhere around 13ms?
  ###
  ### Each aggregation node can also draw more than a normal node due to having to
  ### wait for the network transfer.
  ### 
  ### 1. tell image_cache to load images to memory (async per disk)
  ### 2. draw an image's part of the layout when the image is loaded (create mesh in C, use OpenGL for drawing)
  ### 3. read image from framebuffer to ram and send to browser
  ###
  ### image_cache.load_images_at(indexes, zoom) do |image, image_indexes|
  ###   layouter.each(indexes, image_indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
  ###     image.draw_at(i, ix, iy)
  ###   end
  ### end
  def draw_tile(indexes, layouter_name, x, y, zoom, w, h, *layouter_args)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.inspect}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    empty_tile = true
    layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      empty_tile = false
      break
    end
    return false if empty_tile
    tile = Imlib2::Image.new(w,h)
    tile.clear
    @image_cache.batch do
      layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
        @image_cache.draw_image_at(i, zoom, tile, ix, iy)
      end
    end
    tile
  end

  def tile_info(indexes, layouter_name, x, y, zoom, w, h, *layouter_args)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.inspect}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      yield(i, ix, iy, sz)
    end
  end


  module RowLayouter
  extend self

    def each(indexes, x, y, sz, w, h,
                  row_offset = sz / 2, columns = 200, rows = 5)
      row_offset ||= sz / 2
      bigrow_height = (rows*sz) + row_offset
      bigrow_img_count = columns * rows
      
      item_count = indexes.size
      bigrows = ((item_count-1) / bigrow_img_count) + 1
      
      all_rows = bigrows * rows
      
      first_bigrow_in_view = y / bigrow_height
      last_bigrow_in_view = (y+h) / bigrow_height
      first_bigrow_offset = row_offset * first_bigrow_in_view
      last_bigrow_offset = row_offset * last_bigrow_in_view
      
      first_row_in_view = (y-first_bigrow_offset) / sz
      last_row_in_view = (y+h-last_bigrow_offset) / sz
      
      first_row_y = first_row_in_view * sz + first_bigrow_offset
      y_offset = y - first_row_y
      
      first_column_in_view = x / sz
      last_column_in_view = (x+w) / sz

      (first_row_in_view..last_row_in_view).each_with_index do |r,i|
        next if r > all_rows or r < 0
        bigrow = r / rows
        iy = i*sz - y_offset + row_offset*(bigrow-first_bigrow_in_view)
        next if iy >= h
        (first_column_in_view..last_column_in_view).each_with_index do |c,j|
          next if c >= columns or c < 0
          ix = j*sz - x%sz
          next if ix >= w
          iindex = (bigrow * bigrow_img_count) + (c * rows) + (r % rows)
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
