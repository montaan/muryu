require 'future/imaging/image_cache'
require 'future/imaging/utils'
require 'future/web/memcachepool'
require 'future/database'
require 'future/models'
require 'digest/sha1'
require 'inline'

require 'fastthread'

$NO_TILE_DRAWING = true if $NO_TILE_DRAWING.nil?

class Struct
  def to_json
    "{#{ members.map{|m| m.dump << ":" << self[m].to_json}.join(",") }}"
  end
end

$imlib_mutex ||= Mutex.new

module Future

BACKGROUND_COLOR = Imlib2::Color::RgbaColor.new(14, 35, 56, 255)

module Tiles
extend self

  @@indexes = {}
  @@infos = {}
  @@mutex = Mutex.new
  @@indexes_mtime = 0

  @@fn_data = nil
  @@palette = nil
  @@transparent_palette = nil

  MIMETYPE_DELETED = 0
  DEFAULT_BGCOLOR = [14, 35, 56, 255]

  BLUE    = [ 64,  77, 127, 127]
  RED     = [178,   0,   0, 127]
  GREEN   = [ 42, 224,   0, 127]
  MAGENTA = [227,  73, 255, 127]
  YELLOW  = [255, 229, 127, 127]
  BLACK   = [  0,   0,   0, 127]

  @@type_colors = {
    'image' => BLUE,
    'application' => RED,
    'audio' => GREEN,
    'text' => YELLOW,
    'video' => MAGENTA,
    'application/x-flash-video' => MAGENTA
  }

  @@default_color = BLACK

  def palette(colors, deleted_color)
    @@palette ||= create_palette
    @@transparent_palette ||= (
      h = {}
      @@palette.each{|k,v| h[k] = [0,0,0,0] }
      h
    )
    if colors
      @@palette
    else
      @@transparent_palette
    end.merge(MIMETYPE_DELETED => deleted_color)
  end

  def create_palette
    mts = Mimetypes.find_all(:columns => [:major, :minor])
    h = {}
    mts.each{|mt|
      h[mt.id+1] = color_for_type(mt)
    }
    h
  end

  def color_for_type(mt)
    @@type_colors[mt.major + "/" + mt.minor] ||
    @@type_colors[mt.major] ||
    @@default_color
  end

  def tile_drawer
    @@tile_drawer
  end

  @@read_count = 0

  def read(user, query, time, *tile_args)
    if $NO_TILE_DRAWING
      require 'dipus'
      return DIPUS.open_address("tile_drawer.*.*.#{$SERVER_ID}") do |conn|
        conn.write(
          Marshal.dump([user,query,time]+tile_args)
        )
        conn.close_write
        conn.read
      end
    end
    bad_tile = (tile_args[1] < 0 or tile_args[2] < 0)
    indexes = nil
    r,x,y,z,w,h,colors,bgcolor,bgimage = *tile_args
    if bgcolor
      if bgcolor.size == 3
        abgcolor = bgcolor.scan(/./).map{|s| (s*2).hex }
      else
        abgcolor = bgcolor[0,6].scan(/../).map{|s| s.hex }
      end
      vbgcolor = (0..2).map{|i| abgcolor[i] || 0 }
      vbgcolor[3] = 255
    else
      vbgcolor = DEFAULT_BGCOLOR
    end
    if not bad_tile
      indexes = query_info(user, query, time)
      deleted_color = (query['deleted'] ? [0,0,0,0] : vbgcolor)
      puts "#{Thread.current.telapsed} for fetching indexes" if $PRINT_QUERY_PROFILE
      pal = palette(colors, deleted_color)
      tile = tile_drawer.draw_tile(vbgcolor, indexes, pal, r,x,y,z,w,h, bgimage)
    end
    if tile
      qtext = sanitize_query(query)
      quality = case z
                when 0: 65
                when 1: 65
                when 2: 40
                when 3: 50
                when 4: 50
                when 5: 65
                when 6: 75
                when 7: 75
                else
                  90
                end
      quality += 10 if colors
      quality = 90 if quality > 90
      if tile.is_a? String
        retval = string_to_jpeg(tile, w, h, quality)
      else
        retval = imlib_to_jpeg(tile, quality)
      end
    else
      img = nil
      $imlib_mutex.synchronize do
        img = Imlib2::Image.new(w,h)
        img.fill_rectangle(0,0, img.width, img.height, Imlib2::Color::RgbaColor.new(vbgcolor))
        if bgimage
          bg = Imlib2::Image.create_using_data(256, 256, bgimage)
          img.blend!(bg,0,0,256,256,0,0,256,256)
          bg.delete!(true)
        end
      end
      retval = imlib_to_jpeg(img)
    end
    retval
  end

  def imlib_to_jpeg(tile, quality=50, delete=true)
    ImagingUtils.imlib_to_jpeg(tile, quality, delete)
  end

  def imlib_to_gray_jpeg(tile, quality=50, delete=false)
    ImagingUtils.imlib_to_gray_jpeg(tile, quality, delete)
  end

  def string_to_jpeg(tile, w, h, quality=50)
    ImagingUtils.string_to_jpeg(tile, w, h, quality)
  end

  def string_to_gray_jpeg(tile, w, h, quality=50)
    ImagingUtils.string_to_gray_jpeg(tile, w, h, quality)
  end

  @@column_structs = {}

  def info(user, query, time, *tile_args)
    return [] if tile_args[1] < 0 or tile_args[2] < 0
    s = query_info(user, query, time)
    infos = []
    indexes = []
    h = {}
    tile_drawer.tile_info(s, *tile_args){|image_index, query_index, deleted, x, y, sz|
      infos << (h[image_index] = [image_index, query_index, deleted, x, y, sz, nil])
      indexes << image_index
    }
    puts "#{Thread.current.telapsed} for info layout" if $PRINT_QUERY_PROFILE
    if indexes.size > 0
      paths = DB::Conn.query("select image_index, path from items where image_index = ANY (ARRAY#{indexes.inspect})")
      i = 0
      while i < infos.size
        iidx,path = paths[i]
        h[iidx.to_i][6] = path
        i += 1
      end
    end
    puts "#{Thread.current.telapsed} for paths query" if $PRINT_QUERY_PROFILE
    infos
  end

  def query_info(user, query, time)
    @@mutex.synchronize do
      ### FIXME do a quick C layout, get key and indexes based on that
      ###
      key = "indexes::" + user.id.to_s + "::" + sanitize_query(query) + "::" + time.to_s
      puts "#{Thread.current.telapsed} for generating key" if $PRINT_QUERY_PROFILE
      if Future.memcache
        t = Future.memcache.get(key, true)
      else
        t = @@indexes[key]
      end
      puts "#{Thread.current.telapsed} for memcache get" if $PRINT_QUERY_PROFILE
      unless t
        idxs = Items.rfind_all(user, query.merge(:columns => [:image_index, :mimetype_id, :deleted], :as_array => true))
        tr = 't'
        mts = []
        nidxs = idxs.map{|i|
          ii = Integer(i[0])
          mi = (i[2] == tr ? MIMETYPE_DELETED : Integer(i[1]) + 1)
          mts[mi] ||= mi
          [ii, mi]
        }
        if palette(true, 0).size != mts.size
          @@palette = @@transparent_palette = nil
        end
        t = [nidxs.size].pack("N")
        t << nidxs.transpose.map{|ix| ix.pack("I*") }.join
        if Future.memcache
          Future.memcache.set(key, t, 300, true)
        else
          @@indexes[key] = t
        end
        puts "#{Thread.current.telapsed} for db info query" if $PRINT_QUERY_PROFILE
      end
      t
    end
  end
  
  def item_count(user, query, time)
    indexes_sz = query_info(user,query,time)[0,4].unpack("N")[0]
  end

  def dimensions(user, query, time, layouter)
    indexes_sz = query_info(user,query,time)[0,4].unpack("N")[0]
    tile_drawer.dimensions((0...indexes_sz), layouter)
  end

  private
  def sanitize_query(query)
    query = query.clone
    query.delete :columns
    str = query.to_a.
          sort_by{|k,v| k.to_s }.inspect
    Digest::SHA1.hexdigest(str).to_s
  end

end



class TileDrawer

  LAYOUTERS = {}

  def initialize(image_cache = Future.image_cache)
    @image_cache = image_cache
    @max_cache_size = 1_000_000
    @raw_cache_level = 4
    @jpeg_cache_level = 7
    init_sw unless $NO_TILE_DRAWING
  end

  def draw_tile(bgcolor, index_string, palette, layouter_name, x, y, zoom, w, h, bgimage=nil)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.inspect}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    indexes_sz = index_string[0,4].unpack("N")[0]
    empty_tile = true
    layouter.each((0...indexes_sz), x, y, sz, w, h) do |i, ix, iy|
      empty_tile = false
      break
    end
    return false if empty_tile
    puts "#{Thread.current.telapsed} for tile init" if $PRINT_QUERY_PROFILE
    if zoom <= @jpeg_cache_level && layouter_name.to_s == 'rows' && w == 256 && h == 256
      c_indexes = [index_string[4,indexes_sz*4],
                 index_string[4+indexes_sz*4,indexes_sz*4]
                ]
      tile = draw_tile_sw(bgcolor, c_indexes, palette, x, y, zoom, bgimage)
      return tile
    end
    tile = nil
    $imlib_mutex.synchronize do
      tile = Imlib2::Image.new(w,h)
      tile.has_alpha = true
      tile.fill_rectangle(0,0, w, h, Imlib2::Color::RgbaColor.new(bgcolor))
      if bgimage
        bg = Imlib2::Image.create_using_data(256, 256, bgimage)
        tile.blend!(bg,0,0,256,256,0,0,256,256)
        bg.delete!
      end
    end
    layouter.each((0...indexes_sz), x, y, sz, w, h) do |idx, ix, iy|
      i = index_string[4*(idx+1),4].unpack("I")[0]
      c = index_string[4*(idx+indexes_sz+1),4].unpack("I")[0]
      @image_cache.draw_image_at(i, zoom, tile, ix, iy)
      if palette and (zoom < 6 or palette[c][3] == 255)
        $imlib_mutex.synchronize do
          tile.fill_rectangle(ix, iy, sz, sz,
            Imlib2::Color::RgbaColor.new(palette[c]))
        end
      end
    end
    print_time_draw
    d = tile.data
    $imlib_mutex.synchronize{ tile.delete! }
    d
  end

  def tile_info(index_string, layouter_name, x, y, zoom, w, h, *layouter_args)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.to_s}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    indexes_sz = index_string[0,4].unpack("N")[0]
    layouter.each((0...indexes_sz), x, y, sz, w, h, *layouter_args) do |idx, ix, iy|
      i = index_string[4*(idx+1),4].unpack("I")[0]
      deleted = index_string[4*(idx+indexes_sz+1),4].unpack("I")[0] == Tiles::MIMETYPE_DELETED
      yield(i, idx, deleted, ix, iy, sz)
    end
  end

  def dimensions(indexes, layouter_name)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.to_s}" unless layouter
    layouter.dimensions(indexes)
  end

  @@tiles_drawn = 0
  
  def draw_tile_sw(bgcolor, indexes, palette, x, y, z, bgimage=nil)
    if palette
      pmax = palette.keys.max
      s = [0,0,0,0].pack("C*")
      cpalette = (0..pmax).map{|i|
        pl = palette[i]
        pl ? pl.pack("CCC").reverse! << pl[3,1].pack("C") : s
      }
    else
      cpalette = []
    end
    puts "#{Thread.current.telapsed} for palette generation" if $PRINT_QUERY_PROFILE
    init_sw unless @@sw_init
    @@draw_mutex.synchronize do
      tile = draw_query(indexes[0], indexes[1], cpalette, x, y, z,
        @image_cache.thumb_size_at_zoom(z), bgcolor.pack("CCC").reverse! << "\377",
        bgimage)
      tile
    end
  end

  @@sw_init = false
  @@draw_mutex = Mutex.new

  def init_sw
    @@init_mutex.synchronize do
      return if @@sw_init
      @@sw_init = true
      if $USE_DIPUS_IMAGE_CACHE or $NO_TILE_DRAWING
        require 'dipus'
      else
        puts "#{Time.now.to_f}: Reading #{@image_cache.max_index+1} thumbs of cache to RAM."
        init_mem_image_cache
        puts "#{Time.now.to_f}: Cache init done."
      end
    end
  end

  def init_mem_image_cache
    init_image_cache(
      @max_cache_size, @raw_cache_level, @jpeg_cache_level,
      @image_cache.max_index
    )
  end

  def reload_image_cache
    delete_image_cache
    init_mem_image_cache
  end

  def fetch_texture(z, index_int_string)
    d = if ($USE_DIPUS_IMAGE_CACHE or $NO_TILE_DRAWING) and defined? DIPUS
      DIPUS.open_address('image_cache'){|conn|
        conn.write([z].pack("I"))
        conn.write(index_int_string)
        conn.close_write
        conn.read
      }
    else
      build_texture(z, index_int_string)
    end
    d
  end

  @@init_mutex = Mutex.new

  def print_time_thumbs_zero
    puts "#{Thread.current.telapsed} for zeroing texture" if $PRINT_QUERY_PROFILE
  end

  def print_time_thumbs_read
    puts "#{Thread.current.telapsed} for reading thumbs" if $PRINT_QUERY_PROFILE
  end

  def print_time_jpeg_thumbs_read
    puts "#{Thread.current.telapsed} for reading and decoding jpeg thumbs" if $PRINT_QUERY_PROFILE
  end

  def print_time_texture
    puts "#{Thread.current.telapsed} for building texture" if $PRINT_QUERY_PROFILE
  end

  def print_time_colors
    puts "#{Thread.current.telapsed} for coloring texture" if $PRINT_QUERY_PROFILE
  end

  def print_time_layout
    puts "#{Thread.current.telapsed} for layout" if $PRINT_QUERY_PROFILE
  end

  def print_time_draw
    puts "#{Thread.current.telapsed} for drawing" if $PRINT_QUERY_PROFILE
  end

  def print_time_draw_zero
    puts "#{Thread.current.telapsed} for zeroing render" if $PRINT_QUERY_PROFILE
  end

  def print_time_draw_bg
    puts "#{Thread.current.telapsed} for drawing bg" if $PRINT_QUERY_PROFILE
  end
  
  def print_time_shuffle
    puts "#{Thread.current.telapsed} for shuffling bytes" if $PRINT_QUERY_PROFILE
  end
  
  inline do |builder|
    builder.include "<tile_drawer.c.rb>"
    builder.add_compile_flags "-I#{File.expand_path(File.dirname(__FILE__))}"
    builder.add_compile_flags "-ljpeg"
    builder.add_compile_flags "-Wall -Os"
    builder.add_compile_flags `pkg-config --cflags liboil-0.3`.strip
    builder.add_link_flags `pkg-config --libs liboil-0.3`.strip

    builder.c_raw <<-EOF
      VALUE draw_query(int argc, VALUE *argv, VALUE self)
      {
        if (argc != 9) {
          rb_raise(rb_eArgError, "Wrong number of args");
          return Qundef;
        }
        return draw_software(self,
          argv[0], argv[1], argv[2],
          *((int*)StringValuePtr(argv[7])), argv[8],
          FIX2INT(argv[3]),FIX2INT(argv[4]),FIX2INT(argv[5]),FIX2INT(argv[6]));
      }
    EOF

    builder.c_raw <<-EOF
      VALUE build_texture
      (
        int argc, VALUE *argv, VALUE self
      )
      {
        int z, iindexes_length;
        int* iindexes = NULL;
        VALUE image_cache;
        
        if (argc != 2)
          rb_raise(rb_eRuntimeError, "Wrong number of arguments, expected 2");
      
        z = FIX2INT(argv[0]);
        iindexes = (int*)StringValuePtr(argv[1]);
        iindexes_length = RSTRING(argv[1])->len / sizeof(int);
        
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        
        return build_texture_c(z, iindexes, iindexes_length, image_cache);
      }
    EOF

    builder.c <<-EOF
      void delete_image_cache()
      {
        destroy_image_cache();
      }
    EOF

    builder.c <<-EOF
      void init_image_cache
      (
        int cache_size, int cache_levels, int cache_jpeg_levels, int max_index
      )
      {
       VALUE image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
       init_image_cache_c(image_cache, cache_size, cache_levels, cache_jpeg_levels, max_index);
      }
    EOF


  end


  module RowLayouter
  extend self

    def dimensions(indexes)
      {
        :x => 0,
        :y => 0,
        :width => indexes.size > 1000 ? 1.125 * 200 : (1.125 * indexes.size / 5.0).ceil,
        :height => ((indexes.size * 0.001).ceil * 7.25)
      }
    end

    def each(indexes, x, y, sz, w, h,
                  row_offset = sz.to_f, columns = 200, rows = 5,  hspace = sz / 8.0, vspace = sz / 4.0)
      return false if x < 0 or y < 0
      row_offset ||= sz.to_f
      tw = sz + hspace
      th = sz + vspace
      bigrow_height = (rows*th) + row_offset
      bigrow_img_count = columns * rows
      
      item_count = indexes.size
      bigrows = ((item_count-1) / bigrow_img_count) + 1
      
      all_rows = bigrows * rows
      
      first_bigrow_in_view = (y / bigrow_height).floor
      last_bigrow_in_view = ((y+h) / bigrow_height).floor
      first_bigrow_offset = row_offset * first_bigrow_in_view
      last_bigrow_offset = row_offset * last_bigrow_in_view
      
      first_row_in_view = ((y-first_bigrow_offset) / th).floor
      last_row_in_view = ((y+h-last_bigrow_offset) / th).floor
      
      first_row_y = first_row_in_view * th + first_bigrow_offset
      y_offset = y - first_row_y
      
      first_column_in_view = (x / tw).floor
      last_column_in_view = ((x+w) / tw).floor

      (first_row_in_view..last_row_in_view).each_with_index do |r,i|
        next if r > all_rows or r < 0
        bigrow = r / rows
        iy = i*th - y_offset + row_offset*(bigrow-first_bigrow_in_view)
        next if iy >= h
        (first_column_in_view..last_column_in_view).each_with_index do |c,j|
          next if c >= columns or c < 0
          ix = j * tw - x % tw
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
  
  module ListLayouter
  extend self

    def each(indexes, x, y, sz, w, h, *rest)
      if x > -w && x < sz
        ix = -x
        len = indexes.size / sz
        sidx = (y / sz).floor
        tlen = (h / sz.to_f).ceil 
        return if -sidx >= tlen
        iy = (sidx * sz) - y
        i = 0
        sidx.upto(tlen){|iindex|
          index = indexes[iindex]
          next unless index
          yield(index, ix, iy+(i*sz))
          i += 1
        }
      end
    end

  end # ListLayouter
  LAYOUTERS['list'] = ListLayouter

  module RawListLayouter
  extend self

    def each(indexes, first, last, *rest)
      return if last - first > 1_000_000
      first.upto(last){|iindex|
        index = indexes[iindex]
        next unless index
        yield(index,0,0)
      }
    end

  end # RawListLayouter
  LAYOUTERS['rawlist'] = RawListLayouter

end # TileDrawer


module Tiles
  @@tile_drawer = TileDrawer.new
end


end # Future
