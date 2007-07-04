require 'future/imaging/image_cache'
require 'future/web/memcachepool'
require 'future/database'
require 'future/models'
require 'digest/sha1'
require 'inline'

require 'fastthread'

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
    d = string_to_jpeg(tile.data_for_reading_only, tile.width, tile.height, quality)
    $imlib_mutex.synchronize { tile.delete!(true) } if delete
    d
  end

  def imlib_to_gray_jpeg(tile, quality=50, delete=false)
    d = string_to_gray_jpeg(tile.data_for_reading_only, tile.width, tile.height, quality)
    $imlib_mutex.synchronize { tile.delete!(true) } if delete
    d
  end

  def string_to_jpeg(tile, w, h, quality=50)
    tile_drawer.string_to_jpeg(tile, w, h, quality)
  end

  def string_to_gray_jpeg(tile, w, h, quality=50)
    tile_drawer.string_to_gray_jpeg(tile, w, h, quality)
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
    paths = Items.find_all(:image_index => indexes, :columns => ['image_index','path'], :as_array => true)
    i = 0
    while i < infos.size
      iidx,path = paths[i]
      h[iidx.to_i][6] = path
      i += 1
    end
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
        init_liboil
      else
        puts "#{Time.now.to_f}: Reading #{@image_cache.max_index+1} thumbs of cache to RAM."
        init_liboil
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
    builder.include "<stb_image.c.rb>"
    builder.include "<liboil/liboil.h>"
    builder.include "<errno.h>"
    builder.include "<stdlib.h>"
    builder.include "<jpeglib.h>"
    builder.include "<jerror.h>"
    builder.add_compile_flags "-I#{File.expand_path(File.dirname(__FILE__))}"
    builder.add_compile_flags "-ljpeg"
    builder.add_compile_flags "-Wall -Os"
    builder.add_compile_flags `pkg-config --cflags liboil-0.3`.strip
    builder.add_link_flags `pkg-config --libs liboil-0.3`.strip
    builder.c_raw <<-EOF
      void do_nothing(){}

      char*** icache = NULL;
      int icache_levels = 0;
      int icache_size = 0;
      int icache_jpeg_levels = 0;

      #define MEMORY_ALIGN 64 /* no measurable impact what so ever */

      #define OUTPUT_BUF_SIZE 32768 /* should fit all tile jpegs */

      typedef struct {
        struct jpeg_destination_mgr pub; /* public fields */

        VALUE * rb_str;               /* target stream */
        JOCTET * buffer;              /* start of buffer */
      } rb_str_destination_mgr;

      typedef rb_str_destination_mgr * rb_str_dest_ptr;

      METHODDEF(void)
      rb_str_init_destination (j_compress_ptr cinfo)
      {
        rb_str_dest_ptr dest = (rb_str_dest_ptr) cinfo->dest;

        /* Allocate the output buffer --- it will be released when done with image */
        dest->buffer = (JOCTET *)
            (*cinfo->mem->alloc_large) ((j_common_ptr) cinfo, JPOOL_IMAGE,
                                        OUTPUT_BUF_SIZE * sizeof(JOCTET));
        *dest->rb_str = rb_str_new(0, 0);
        dest->pub.next_output_byte = dest->buffer;
        dest->pub.free_in_buffer = OUTPUT_BUF_SIZE;
      }

      METHODDEF(boolean)
      rb_str_empty_output_buffer (j_compress_ptr cinfo)
      {
        rb_str_dest_ptr dest = (rb_str_dest_ptr) cinfo->dest;

        rb_str_cat(*dest->rb_str, (char*)dest->buffer, OUTPUT_BUF_SIZE);

        dest->pub.next_output_byte = dest->buffer;
        dest->pub.free_in_buffer = OUTPUT_BUF_SIZE;

        return TRUE;
      }

      METHODDEF(void)
      rb_str_term_destination (j_compress_ptr cinfo)
      {
        rb_str_dest_ptr dest = (rb_str_dest_ptr) cinfo->dest;
        size_t datacount = OUTPUT_BUF_SIZE - dest->pub.free_in_buffer;

        /* Write any data remaining in the buffer */
        if (datacount > 0)
          rb_str_cat(*dest->rb_str, (char*)dest->buffer, datacount);
      }
      
      GLOBAL(void)
      rb_str_dest(j_compress_ptr cinfo, VALUE *dst)
      {
        rb_str_dest_ptr dest;

        cinfo->dest = (struct jpeg_destination_mgr *)
            (*cinfo->mem->alloc_small) ((j_common_ptr) cinfo, JPOOL_PERMANENT,
                                        sizeof(rb_str_destination_mgr));
        dest = (rb_str_dest_ptr) cinfo->dest;
        dest->pub.init_destination = rb_str_init_destination;
        dest->pub.empty_output_buffer = rb_str_empty_output_buffer;
        dest->pub.term_destination = rb_str_term_destination;
        dest->rb_str = dst;
      }

      VALUE compress_jpeg(JSAMPLE *rgb_pixels, int w, int h, int quality)
      {
        struct jpeg_error_mgr jerr;
        struct jpeg_compress_struct cinfo;
        JSAMPROW *rows;
        int i;
        VALUE jdst;

        rows = (JSAMPROW*)malloc(h*sizeof(JSAMPROW));

        for (i=0; i<h; i++)
          rows[i] = &rgb_pixels[i*w*3];

        cinfo.err = jpeg_std_error(&jerr);
        jpeg_create_compress(&cinfo);

        rb_str_dest(&cinfo, &jdst);
        
        cinfo.image_width = w;
        cinfo.image_height = h;
        cinfo.input_components = 3;
        cinfo.in_color_space = JCS_RGB;

        jpeg_set_defaults(&cinfo);
        jpeg_set_quality(&cinfo, quality, TRUE);
        cinfo.dct_method = JDCT_IFAST;
        
        jpeg_start_compress(&cinfo, TRUE);
        jpeg_write_scanlines(&cinfo, rows, h);
        jpeg_finish_compress(&cinfo);

        jpeg_destroy_compress(&cinfo);
        free(rows);
        
        return jdst;
      }

      VALUE compress_gray_jpeg(JSAMPLE *rgb_pixels, int w, int h, int quality)
      {
        struct jpeg_error_mgr jerr;
        struct jpeg_compress_struct cinfo;
        JSAMPROW *rows;
        int i;
        VALUE jdst;

        rows = (JSAMPROW*)malloc(h*sizeof(JSAMPROW));

        for (i=0; i<h; i++)
          rows[i] = &rgb_pixels[i*w];

        cinfo.err = jpeg_std_error(&jerr);
        jpeg_create_compress(&cinfo);

        rb_str_dest(&cinfo, &jdst);
        
        cinfo.image_width = w;
        cinfo.image_height = h;
        cinfo.input_components = 1;
        cinfo.in_color_space = JCS_GRAYSCALE;

        jpeg_set_defaults(&cinfo);
        jpeg_set_quality(&cinfo, quality, TRUE);
        cinfo.dct_method = JDCT_IFAST;
        
        jpeg_start_compress(&cinfo, TRUE);
        jpeg_write_scanlines(&cinfo, rows, h);
        jpeg_finish_compress(&cinfo);

        jpeg_destroy_compress(&cinfo);
        free(rows);
        
        return jdst;
      }
      
      void sw_row_layout
      (
        int* rtile_image_count,
        int** rindexes,
        int** coords,
        int iindexes_length,
        int x,
        int y,
        int sz,
        int w,
        int h
      )
      {
        int columns, rows, bigrow_img_count;
        int y_offset, tpt;
        int bigrow, first_bigrow_in_view, last_bigrow_in_view;
        int first_row_in_view, last_row_in_view;
        int first_column_in_view, last_column_in_view, columns_in_view, rows_in_view;
        int i,r,j,c;
        int index;
        int *indexes = NULL;
        float row_offset, bigrow_height, ix, iy, first_row_y,
              first_bigrow_offset, last_bigrow_offset;
        int tile_image_count, l;
        int* cs = NULL;

        tpt = 512 / sz;

        row_offset = sz / 2.0;
        columns = 200; 
        rows = 5;
        bigrow_height = (rows*sz) + row_offset;
        bigrow_img_count = columns * rows;

        first_bigrow_in_view = y / bigrow_height;
        last_bigrow_in_view = (y+h) / bigrow_height;
        first_bigrow_offset = row_offset * first_bigrow_in_view;
        last_bigrow_offset = row_offset * last_bigrow_in_view;

        first_row_in_view = (y-first_bigrow_offset) / sz;
        last_row_in_view = (y+h-last_bigrow_offset) / sz;

        first_row_y = first_row_in_view * sz + first_bigrow_offset;
        y_offset = y - first_row_y;

        first_column_in_view = x / sz;
        last_column_in_view = (x+w) / sz;
        columns_in_view = last_column_in_view - first_column_in_view + 1;
        rows_in_view = last_row_in_view - first_row_in_view + 1;

        indexes = (int*)malloc((columns_in_view * rows_in_view) * sizeof(int));
        if (indexes == NULL) goto fail;
        
        /* 1 2D point */
        cs = (int*)malloc( sizeof(int)*(columns_in_view * rows_in_view)*2 );
        if (cs == NULL) goto fail;
       
        tile_image_count = 0;

        for(i=0, r=first_row_in_view; r <= last_row_in_view; i++, r++)
        {
          if (r < 0) continue;
          bigrow = r / rows;
          iy = i*sz - y_offset + row_offset*(bigrow-first_bigrow_in_view);
          if (iy >= h) continue;
          for(j=0, c=first_column_in_view; c <= last_column_in_view; j++, c++)
          {
            if (c >= columns || c < 0) continue;
            ix = j*sz - x%sz;
            if (ix >= w) continue;
            index = (bigrow * bigrow_img_count) + (c * rows) + (r % rows);
            indexes[tile_image_count] = index;
            l = tile_image_count * 2;

            cs[l] = ix;
            cs[l+1] = iy;
            
            tile_image_count++;
          }
        }
        *rtile_image_count = tile_image_count;
        *rindexes = indexes;
        *coords = cs;
        return;
        
        fail:
        free(indexes);
        free(cs);
        *rtile_image_count = 0;
        *rindexes = NULL;
        *coords = NULL;
      }

      void colorize
      (
        VALUE self, unsigned char *thumbs,
        int *colors, int colors_length,
        int sz
      )
      {
        int i,j,sz24;
        unsigned char sa;
        unsigned char *color;

        sz24 = sz*sz*4;

        /* premultiply the thumbs */
        for (i=0; i<colors_length*sz24; i+=4) {
          thumbs[i  ] = (thumbs[i  ]*thumbs[i+3]) >> 8;
          thumbs[i+1] = (thumbs[i+1]*thumbs[i+3]) >> 8;
          thumbs[i+2] = (thumbs[i+2]*thumbs[i+3]) >> 8;
        }

        /* color the thumbs */
        for (i=0; i<colors_length; i++) {
          if (colors[i] == 0) continue;
          color = (unsigned char*)&colors[i];
          sa = color[3];
          if (sa == 255) {
            oil_splat_u32_ns((uint32_t*)&thumbs[i*sz24], (uint32_t*)&colors[i], sz*sz);
          } else {
            color[0] = (color[0]*sa) >> 8;
            color[1] = (color[1]*sa) >> 8;
            color[2] = (color[2]*sa) >> 8;
            if (sz >= 64) {
              for(j=0; j<16; j++) {
                oil_composite_over_argb_const_src(
                  (uint32_t*)&thumbs[i*sz24+j*sz*4],
                  (uint32_t*)&colors[i],
                  15-j);
                *(uint32_t*)&thumbs[i*sz24+j*sz*4+(15-j)*4] = 0;
              }
            } else {
              oil_composite_over_argb_const_src((uint32_t*)&thumbs[i*sz24], (uint32_t*)&colors[i], sz*sz);
            }
          }
        }
      }

      int load_cache_jpeg
      (unsigned char *dst, const unsigned char *jpeg, int stride)
      {
        int w,h,aw,ah,j;
        unsigned char *data = NULL, *a_data=NULL;
        int tsz = *(int*)jpeg, csz, asz;
        char c;
        if (tsz > 0) {
          csz = *(int*)&jpeg[4];
          data = stbi_jpeg_load_from_memory(&jpeg[8], csz,
                                            &w, &h, 0, 4);
          if (data == NULL) return -1;
          asz = *(int*)&jpeg[8+csz];
          if (asz > 0) {
            a_data = stbi_jpeg_load_from_memory(&jpeg[12+csz], asz,
                                                &aw, &ah, 0, 1);
            if (a_data == NULL || aw != w || ah != h) return -1;
            for (j=0;j<w*h*4;j+=4) {
              c = data[j];
              data[j] = data[j+2];
              data[j+2] = c;
              data[j+3] = a_data[j>>2];
            }
            stbi_image_free(a_data);
          } else {
            for (j=0;j<w*h*4;j+=4) {
              c = data[j];
              data[j] = data[j+2];
              data[j+2] = c;
            }
          }
          for (j=0;j<h;j++)
            oil_memcpy(&dst[stride*j], &data[w*4*j], w*4);
          stbi_image_free(data);
        }
        return 0;
      }
      
      int add_cache_leaf(int, int, const char*);
      
      char* setup_texture
      (
        VALUE self, int* iindexes, int iindexes_length,
        int z, int sz, int *indexes, int indexes_length
      )
      {
        VALUE image_cache, thumb_data;
        VALUE read_imgs;
        char *thumb_ptr=NULL;
        unsigned char *pixels=NULL;
        int i, j, sz24, sz4, len, k;
        int index=0;
        VALUE *ptr=NULL;
        
        sz24 = sz*sz*4;
        sz4 = sz*4;
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        if (0 != posix_memalign((void **)&pixels, MEMORY_ALIGN, sz24*indexes_length)) {
          rb_raise(rb_eRuntimeError, "Failed to allocate pixels");
          return NULL;
        }
        
        /* raw textures don't need zeroing, jpeg textures do */
        if (z >= icache_levels) {
          oil_splat_u32_ns((uint32_t*)pixels, (uint32_t*)&index, sz*sz*indexes_length);
          rb_funcall(self, rb_intern("print_time_thumbs_zero"), 0);
        }

        /* collect all uncached images to read_imgs */
        read_imgs = rb_ary_new();
        for (i=0; i<indexes_length; i++) {
          index = indexes[i];
          if (index < iindexes_length) {
            if (iindexes[index] >= icache_size) {
              rb_raise(rb_eRuntimeError, "Texture index out of cache bounds");
              return NULL;
            }
            if (z >= icache_jpeg_levels || icache[z][iindexes[index]] == NULL)
            {
              rb_funcall(read_imgs, rb_intern("push"), 1, INT2FIX(iindexes[index]));
            }
          }
        }
        
        if (RARRAY(read_imgs)->len > 0) {
          if (z >= icache_levels && z < icache_jpeg_levels) {
          
          /* read in missing jpegs */
            thumb_data = rb_funcall(image_cache,
                                    rb_intern("read_images_as_jpeg"), 2,
                                    INT2FIX(z), read_imgs);
            len = RARRAY(read_imgs)->len;
            ptr = RARRAY(read_imgs)->ptr;
            thumb_ptr = StringValuePtr(thumb_data);
            for(i=0,k=0; i<len; i++)
              k += add_cache_leaf(z, FIX2INT(ptr[i]), &(thumb_ptr[k]));

          } else {
          /* read in missing raws */
            thumb_data = rb_funcall(image_cache,
                                    rb_intern("read_images_as_string"), 2,
                                    INT2FIX(z), read_imgs);
            len = RARRAY(read_imgs)->len;
            ptr = RARRAY(read_imgs)->ptr;
            thumb_ptr = StringValuePtr(thumb_data);
            if (z < icache_levels) { /* and cache them */
              for(i=0,k=0; i<len; i++)
                k += add_cache_leaf(z, FIX2INT(ptr[i]), &(thumb_ptr[k]));
            } else { /* or read straight into pixels */
              for(i=0,j=0; i<indexes_length; i++) {
                index = indexes[i];
                if (index < iindexes_length){
                  memcpy(pixels+(sz24*i), &(thumb_ptr[j*sz24]), sz24);
                  j++;
                }
              }
              /* and we're done here */
              return (char*)pixels;
            }
          }
        }

        if (z < icache_levels) { /* raws are easy, just memcpy to pixels */
          if (z == 0) { /* int[i] = blaat */
            for(i=0; i<indexes_length; i++) {
              index = indexes[i];
              if (index < iindexes_length)
                ((int*)pixels)[i] = *((int*)icache[z][iindexes[index]]);
            }
          } else {
            for(i=0; i<indexes_length; i++) {
              index = indexes[i];
              if (index < iindexes_length)
                oil_memcpy(pixels+(sz24*i), icache[z][iindexes[index]], sz24);
            }
          }
          rb_funcall(self, rb_intern("print_time_thumbs_read"), 0);
          
        } else if (z < icache_jpeg_levels) { /* jpegs need decompressing */
          for(i=0; i<indexes_length; i++) {
            index = indexes[i];
            if (index < iindexes_length) {
              thumb_ptr = icache[z][iindexes[index]];
              load_cache_jpeg(&pixels[sz24*i], (unsigned char*)thumb_ptr, sz4);
            }
          }
          rb_funcall(self, rb_intern("print_time_jpeg_thumbs_read"), 0);
        }
        
        return (char*)pixels;
      }



      VALUE draw_software
      (
        VALUE self,
        VALUE riindexes,
        VALUE riindex_colors,
        VALUE palette,
        int bgcolor,
        VALUE bgimage,
        int x, int y, int z, int sz
      )
      {
        int *indexes = NULL;
        char *thumbs = NULL, *final_render = NULL;
        int indexes_length;
        int *iindexes = NULL, *cropped_indexes = NULL, *cropped_iindexes = NULL;
        int *iindex_colors = NULL, *colors = NULL;
        int iindexes_length, cropped_indexes_length;
        int *coords = NULL;
        int tx, ty, tsz, tsz4, offset_y, offset_x;
        int *gl_palette = NULL;
        VALUE *qptr = NULL;
        int i, j, plen, sz24, sz4, index;
        VALUE thumb_tex, fetch;
        VALUE rimage = rb_str_new(NULL, 256*256*4);

        sz24 = sz*sz*4;
        sz4 = sz*4;
        final_render = StringValuePtr(rimage);

        iindexes_length = RSTRING(riindexes)->len / sizeof(int);
        iindexes = (int*)StringValuePtr(riindexes);
        iindex_colors = (int*)StringValuePtr(riindex_colors);

        plen = RARRAY(palette)->len;
        qptr = RARRAY(palette)->ptr;
        if (plen == 0) {
          gl_palette = NULL;
        } else {
          gl_palette = (int*)malloc(plen * sizeof(int));
          if (gl_palette == NULL) {
            rb_raise(rb_eRuntimeError, "Failed to allocate gl_palette");
            goto exit;
          }
          for(i=0; i<plen; i++) {
            gl_palette[i] = *((int*)StringValuePtr(qptr[i]));
          }
        }

        sw_row_layout(
                   &indexes_length, &indexes, &coords,
                   iindexes_length,
                   x, y, sz, 256, 256);
        if (indexes == NULL || coords == NULL)
        {
          rb_raise(rb_eRuntimeError, "Failed to allocate layout");
          goto exit;
        }
        rb_funcall(self, rb_intern("print_time_layout"), 0);
        
        cropped_indexes = (int*)malloc(sizeof(int) * indexes_length);
        cropped_iindexes = (int*)malloc(sizeof(int) * indexes_length);
        for (i=0,j=0; i<indexes_length; i++) {
          index = indexes[i];
          if (index < iindexes_length) {
            cropped_indexes[j] = index;
            cropped_iindexes[j] = iindexes[index];
            j++;
          }
        }
        cropped_indexes_length = j;


        fetch = rb_str_new(NULL, cropped_indexes_length * sizeof(int));
        memcpy(StringValuePtr(fetch), cropped_iindexes, cropped_indexes_length * sizeof(int));
        thumb_tex = rb_funcall(
          self, rb_intern("fetch_texture"), 2, INT2FIX(z), fetch
        );
        thumbs = StringValuePtr(thumb_tex);
        rb_funcall(self, rb_intern("print_time_texture"), 0);

        colors = (int*)malloc(sizeof(int) * cropped_indexes_length);
        if (colors == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate colors");
          goto exit;
        }
        for (i=0; i<cropped_indexes_length; i++) {
          index = cropped_indexes[i];
          colors[i] = gl_palette[iindex_colors[index]];
        }

        colorize(self, (unsigned char*)thumbs, colors, cropped_indexes_length, sz);
        rb_funcall(self, rb_intern("print_time_colors"), 0);

        for(i=0; i<256*256; i++)
          ((int*)final_render)[i] = bgcolor;
        rb_funcall(self, rb_intern("print_time_draw_zero"), 0);

        if (bgimage != Qnil) {
          oil_composite_over_argb(
            (uint32_t*)final_render,
            (uint32_t*)StringValuePtr(bgimage),
            256*256);
          rb_funcall(self, rb_intern("print_time_draw_bg"), 0);
        }

        for(i=0,index=0; i<indexes_length; i++) {
          if (indexes[i] >= iindexes_length) continue;
          tx = coords[i<<1];
          ty = coords[(i<<1)+1];
          tsz = sz;
          tsz4 = sz;
          offset_y = offset_x = 0;
          if (tx < 0) {
            tsz4 += tx;
            offset_x = -tx;
            tx = 0;
          } else if (tx > 256-sz) {
            tsz4 += (256-sz - tx);
          }
          if (ty < 0) {
            offset_y = -ty;
          } else if (ty > 256-sz) {
            tsz += (256-sz - ty);
          }
          
          for (j=offset_y; j<tsz; j++) {
            oil_composite_over_argb(
                   &((uint32_t*)final_render)[((ty+j)<<8) + tx],
                   &((uint32_t*)thumbs)[(index<<(z<<1)) + (j<<z) + offset_x],
                   tsz4);
          }
          index++;
        }
        
        exit:
        free(coords);
        free(indexes);
        free(cropped_indexes);
        free(cropped_iindexes);
        free(gl_palette);
        free(colors);
        rb_funcall(self, rb_intern("print_time_draw"), 0);

        return rimage;
      }

      
      void destroy_image_cache()
      {
        int i,j;
        if (icache != NULL) {
          for (i=0; i<icache_levels; i++)
          {
            for(j=0; j<icache_size; j++)
              icache[i][j] = NULL;
            free(icache[i][icache_size]);
            free(icache[i]);
          }
          for (i=icache_levels; i<icache_jpeg_levels; i++)
          {
            for(j=0; j<icache_size; j++)
              if(icache[i][j] != NULL)
                free(icache[i][j]);
            free(icache[i]);
          }
          free(icache);
          icache = NULL;
        }
        icache_levels = 0;
        icache_size = 0;
      }

      /* adds a cache leaf and returns the length of data (useful for jpeg) */
      int add_cache_leaf(int level, int index, const char *data)
      {
        int len;
        char *tmp;
        if (index >= icache_size) {
          rb_raise(rb_eRuntimeError, "Cache leaf index out of bounds");
          return -1;
        }
        if (level < icache_levels)
          len = 1 << (2*level+2); // 2^level * 4
        else
          len = (*(int*)data) + 4;
        tmp = malloc(len);
        if (tmp == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate new cache leaf");
          return -1;
        }
        oil_memcpy(tmp, data, len);
        icache[level][index] = tmp;
        return len;
      }
            
      int raw_cache_level_fill
      (VALUE image_cache, int level, int first_idx, int last_idx)
      {
        int tsz, span_sz, span_end, j, k;
        char *span = NULL;
        VALUE thumb_str;
        
        tsz = (1<<(level*2)) * 4;
        span_sz = 1 << (18-(level*2)); // 1 MiB chunks
        for(j=first_idx; j<=last_idx; j+=span_sz)
        {
          span_end = j+span_sz;
          if (span_end > last_idx) span_end = last_idx;
          thumb_str = rb_funcall(image_cache,
                              rb_intern("read_span_as_string"), 3,
                              INT2FIX(level), INT2FIX(j), INT2FIX(span_end));
          span = StringValuePtr(thumb_str);
          /* copy into pre-allocated slab */
          for(k=0; k<RSTRING(thumb_str)->len; k+=tsz)
            memcpy(icache[level][j+k/tsz], span+k, tsz);
        }
        return 0;
      }

      int jpeg_cache_level_fill
      (VALUE image_cache, int level, int first_idx, int last_idx)
      {
        int span_sz, span_end, j, k, l, total_allocation=0;
        char *span = NULL;
        VALUE thumb_str;
        
        span_sz = 1 << (21-(level*2)); // ~1 MiB chunks
        for(j=first_idx; j<=last_idx; j+=span_sz)
        {
          span_end = j+span_sz;
          if (span_end > last_idx) span_end = last_idx;
          thumb_str = rb_funcall(image_cache,
                                rb_intern("read_span_as_jpeg"), 3,
                                INT2FIX(level), INT2FIX(j), INT2FIX(span_end));
          span = StringValuePtr(thumb_str);
          for(k=0,l=0; k<RSTRING(thumb_str)->len; l++)
            k += add_cache_leaf(level, j+l, &span[k]);
          total_allocation += k;
        }
        printf("allocated %d bytes (%d items) for jpeg cache level %d\\n", total_allocation, last_idx-first_idx+1);
        return 0;
      }

      int cache_fill(VALUE self, int first_idx, int last_idx)
      {
        int i;
        VALUE image_cache;
        
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        
        printf("raw cache fill start, caching levels %d-%d\\n",
               0, icache_levels-1);
        for(i=0; i<icache_levels; i++)
        {
          if (0 == raw_cache_level_fill(image_cache, i, first_idx, last_idx))
            printf("raw level %d cached\\n", i);
          else
            return -1;
        }
        printf("raw cache fill done\\n");
        printf("jpeg cache fill start, caching levels %d-%d\\n",
               icache_levels, icache_jpeg_levels-1);
        for(i=icache_levels; i < icache_jpeg_levels; i++) {
          if (0 == jpeg_cache_level_fill(image_cache, i, first_idx, last_idx))
            printf("level %d cached\\n", i);
          else
            return -1;
        }
        printf("jpeg cache fill done\\n");
        return 0;
      }
      
    EOF

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

    builder.c <<-EOF
      VALUE decompress_rgb_alpha_jpeg(VALUE jpeg, int w, int h)
      {
        int i;
        int *str = NULL;
        VALUE dec = rb_str_new(NULL, w*h*4);
        str = (int*)StringValuePtr(dec);
        for(i=0; i<w*h; i++)
          str[i] = 0;
        load_cache_jpeg(StringValuePtr(dec), StringValuePtr(jpeg), w*4);
        return dec;
      }
    EOF

    builder.c_raw <<-EOF
      VALUE build_texture
      (
        int argc, VALUE *argv, VALUE self
      )
      {
        VALUE image_cache, thumb_data;
        VALUE read_imgs;
        char *thumb_ptr=NULL;
        unsigned char *pixels=NULL;
        int *iindexes=NULL;
        int i, j, sz24, sz4, len, k, z, iindexes_length, sz;
        int index=0;
        VALUE *ptr=NULL;
        VALUE rtex;

        z = FIX2INT(argv[0]);
        sz = 1 << z;
        iindexes = (int*)StringValuePtr(argv[1]);
        iindexes_length = RSTRING(argv[1])->len / sizeof(int);

        sz24 = sz*sz*4;
        sz4 = sz*4;
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));

        rtex = rb_str_new(NULL, sz24*iindexes_length);
        pixels = (unsigned char*)StringValuePtr(rtex);

        /* raw textures don't need zeroing, jpeg textures do */
        if (z >= icache_levels) {
          oil_splat_u32_ns((uint32_t*)pixels, (uint32_t*)&index, sz*sz*iindexes_length);
        }

        /* collect all uncached images to read_imgs */
        read_imgs = rb_ary_new();
        for (i=0; i<iindexes_length; i++) {
          if (z >= icache_jpeg_levels || icache[z][iindexes[i]] == NULL)
          {
            rb_funcall(read_imgs, rb_intern("push"), 1, INT2FIX(iindexes[i]));
          }
        }

        
        if (RARRAY(read_imgs)->len > 0) {
          if (z >= icache_levels && z < icache_jpeg_levels) {
          
          /* read in missing jpegs */
            thumb_data = rb_funcall(image_cache,
                                    rb_intern("read_images_as_jpeg"), 2,
                                    INT2FIX(z), read_imgs);
            len = RARRAY(read_imgs)->len;
            ptr = RARRAY(read_imgs)->ptr;
            thumb_ptr = (char*)StringValuePtr(thumb_data);
            for(i=0,k=0; i<len; i++)
              k += add_cache_leaf(z, FIX2INT(ptr[i]), &(thumb_ptr[k]));

          } else {
          /* read in missing raws */
            thumb_data = rb_funcall(image_cache,
                                    rb_intern("read_images_as_string"), 2,
                                    INT2FIX(z), read_imgs);
            len = RARRAY(read_imgs)->len;
            ptr = RARRAY(read_imgs)->ptr;
            thumb_ptr = (char*)StringValuePtr(thumb_data);
            if (z < icache_levels) { /* and cache them */
              for(i=0,k=0; i<len; i++)
                k += add_cache_leaf(z, FIX2INT(ptr[i]), &(thumb_ptr[k]));
            } else { /* or read straight into pixels */
              for(i=0; i<iindexes_length; i++) {
                memcpy(pixels+(sz24*i), &(thumb_ptr[i*sz24]), sz24);
                j++;
              }
              /* and we're done here */
              return rtex;
            }
          }
        }
        
        if (z < icache_levels) { /* raws are easy, just memcpy to pixels */
          if (z == 0) { /* int[i] = blaat */
            for(i=0; i<iindexes_length; i++) {
              ((int*)pixels)[i] = *((int*)icache[z][iindexes[i]]);
            }
          } else {
            for(i=0; i<iindexes_length; i++) {
              oil_memcpy(pixels+(sz24*i), icache[z][iindexes[i]], sz24);
            }
          }

        } else if (z < icache_jpeg_levels) { /* jpegs need decompressing */
          for(i=0; i<iindexes_length; i++) {
            thumb_ptr = icache[z][iindexes[i]];
            load_cache_jpeg(&pixels[sz24*i], (unsigned char*)thumb_ptr, sz4);
          }
        }
        
        return rtex;
      }
    EOF

    builder.c <<-EOF
      VALUE string_to_jpeg(VALUE str, int w, int h, int quality)
      {
        int i,j,sz24=w*h*4;
        VALUE retval;
        JSAMPLE *data = (JSAMPLE*)StringValuePtr(str);
        JSAMPLE *rgb_data = malloc(w*h*3);
        for(i=0,j=0; i<sz24; i+=4,j+=3) {
          rgb_data[j] = data[i+2];
          rgb_data[j+1] = data[i+1];
          rgb_data[j+2] = data[i];
        }
        rb_funcall(self, rb_intern("print_time_shuffle"), 0);
        retval = compress_jpeg(rgb_data, w, h, quality);
        free(rgb_data);
        return retval;
      }
    EOF

    builder.c <<-EOF
      VALUE string_to_gray_jpeg(VALUE str, int w, int h, int quality)
      {
        int i,j,sz24=w*h*4;
        VALUE retval;
        JSAMPLE *data = (JSAMPLE*)StringValuePtr(str);
        JSAMPLE *gray_data = malloc(w*h);
        for(i=0,j=0; i<sz24; i+=4,j++) {
          gray_data[j] = data[i+3];
        }
        retval = compress_gray_jpeg(gray_data, w, h, quality);
        free(gray_data);
        return retval;
      }
    EOF

    builder.c <<-EOF
      void init_liboil()
      {
        oil_init();
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
        int i,j,sz24;
        int total_header_sz = 0;
        char **c;
        int e;
        if (icache != NULL) destroy_image_cache();
        icache_size = (int)cache_size;
        icache_levels = (int)cache_levels + 1;
        icache_jpeg_levels = (int)cache_jpeg_levels + 1;
        /* 2D-array of strings: icache[level][index] */
        icache = (char***)malloc(sizeof(char**) * icache_jpeg_levels);
        total_header_sz += sizeof(char**) * icache_jpeg_levels;
        if (icache == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate icache");
          goto fail;
        }
        for(i=0; i < icache_jpeg_levels; i++) {
          // with an extra for the slab at c[icache_size]
          c = (char**)malloc(sizeof(char*) * (icache_size + 1));
          total_header_sz += sizeof(char*) * (icache_size + 1);
          printf("allocated %d bytes (%d entries) of cache index for level %d\\n", sizeof(char*) * (icache_size + 1), icache_size, i);
          if (c == NULL) {
            rb_raise(rb_eRuntimeError, "Failed to allocate icache level");
            destroy_image_cache();
            goto fail;
          }
          for (j=0; j<icache_size; j++) c[j] = NULL;
          if (i < icache_levels) {
            /* allocate a slab max_index * 2^i * 4 bytes in size
               aligned to 16-byte boundary*/
            sz24 = (1<<(i*2)) * 4;
            if (0 != (e = posix_memalign((void **)&c[icache_size],
                                MEMORY_ALIGN,
                                (max_index+1) * sz24)))
            {
              printf("%d: %d, %d\\n", e, EINVAL, ENOMEM);
              rb_raise(rb_eRuntimeError, "Failed to allocate icache slab");
              destroy_image_cache();
              goto fail;
            }
            total_header_sz += (max_index+1) * sz24;
            for (j=0; j<=max_index; j++) c[j] = c[icache_size] + sz24*j;
          }
          icache[i] = c;
        }
        printf("pre-allocated %d bytes of cache headers (max_index: %d)\\n", total_header_sz, max_index);
        cache_fill(self, 0, max_index);
        fail:
      }
    EOF


  end


  module RowLayouter
  extend self

    def dimensions(indexes)
      {
        :x => 0,
        :y => 0,
        :width => indexes.size > 1000 ? 200 : (indexes.size / 5.0).ceil,
        :height => ((indexes.size * 0.001).ceil * 5.5)
      }
    end

    def each(indexes, x, y, sz, w, h,
                  row_offset = sz / 2.0, columns = 200, rows = 5)
      return false if x < 0 or y < 0
      row_offset ||= sz / 2.0
      bigrow_height = (rows*sz) + row_offset
      bigrow_img_count = columns * rows
      
      item_count = indexes.size
      bigrows = ((item_count-1) / bigrow_img_count) + 1
      
      all_rows = bigrows * rows
      
      first_bigrow_in_view = (y / bigrow_height).floor
      last_bigrow_in_view = ((y+h) / bigrow_height).floor
      first_bigrow_offset = row_offset * first_bigrow_in_view
      last_bigrow_offset = row_offset * last_bigrow_in_view
      
      first_row_in_view = ((y-first_bigrow_offset) / sz).floor
      last_row_in_view = ((y+h-last_bigrow_offset) / sz).floor
      
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
