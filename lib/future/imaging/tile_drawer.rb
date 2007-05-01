require 'future/imaging/image_cache'
require 'digest/sha1'
require 'inline'

require 'fastthread'

class Thread
  attr_accessor :last_time

  def telapsed
    t = self.last_time
    self.last_time = Time.now.to_f
    t ||= self.last_time
    ms = (self.last_time - t) * 1000
    "[#{("#"*((ms*2).round)).rjust(16)[0,16]}] %.3fms" % [ms]
  end
  
end

$imlib_mutex ||= Mutex.new
$PRINT_QUERY_PROFILE = true if $PRINT_QUERY_PROFILE.nil?

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

  MIMETYPE_DELETED = 2**8
  DEFAULT_BGCOLOR = [14, 35, 56, 255]

  BLUE    = [ 13,   7, 255, 127]
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
    'video' => MAGENTA
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
    mts = Mimetypes.find_all(:columns => [:major])
    h = {}
    mts.each{|mt|
      h[mt.id] = color_for_type(mt.major)
    }
    h
  end

  def color_for_type(major)
    @@type_colors[major] || @@default_color
  end

  def tile_drawer
    @@tile_drawer
  end

  def read(user, query, *tile_args)
    ### FIXME query optimization problematic (need to layout to get wanted spans,
    ###       then do a query for each (semi-)continuous span, e.g. layout says
    ###       that 4-10, 16-22, 28-34, 4182-4188, 4194-4200 needed
    ###       -> get 4-34, 4182-4200)
    ###
    puts "#{Thread.current.telapsed} for Tiles init" if $PRINT_QUERY_PROFILE
    bad_tile = (tile_args[1] < 0 or tile_args[2] < 0)
    indexes = nil
    r,x,y,z,w,h,colors,bgcolor = *tile_args
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
    puts "#{Thread.current.telapsed} for arg parsing" if $PRINT_QUERY_PROFILE
    if not bad_tile
      @@mutex.synchronize do
        key = user.id.to_s + "::" + sanitize_query(query)
        puts "#{Thread.current.telapsed} for generating key" if $PRINT_QUERY_PROFILE
        t = @@indexes[key]
        unless t
          idxs = Items.rfind_all(user, query.merge(:columns => [:image_index, :mimetype_id, :deleted], :as_array => true))
          tr = 't'
          idxs.each{|i|
            i[0]=i[0].to_i
            i[1]=(i.pop == tr ? MIMETYPE_DELETED : i[1].to_i)
          }
          t = @@indexes[key] = [idxs, idxs.transpose.map!{|ix| ix.pack("I*") }]
        end
        indexes = t
      end
      puts "#{Thread.current.telapsed} for fetching indexes" if $PRINT_QUERY_PROFILE
      pal = palette(colors, vbgcolor)
      tile = tile_drawer.draw_tile(vbgcolor, indexes, pal, r,x,y,z,w,h)
    end
    if tile
      qtext = sanitize_query(query)
      quality = case z
                when 0: 70
                when 1: 40
                when 2: 40
                when 3: 50
                when 4: 50
                when 5: 70
                when 6: 80
                when 7: 80
                else
                  90
                end
      quality += 20 if colors
      quality = 90 if quality > 90
      if tile.is_a? String
        string_to_jpeg(tile, quality)
      else
        imlib_to_jpeg(tile, quality)
      end
    else
      $imlib_mutex.synchronize do
        img = Imlib2::Image.new(w,h)
        img.fill_rectangle(0,0, img.width, img.height, Imlib2::Color::RgbaColor.new(vbgcolor))
      end
      imlib_to_jpeg(img)
    end
  end

  def imlib_to_jpeg(tile, quality=50, delete=true)
    Future.cache_dir.+('ramdisk').mkdir_p
    tmp = Future.cache_dir + 'ramdisk' + "tmptile-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.jpg"
    tile['quality'] = quality
    $imlib_mutex.synchronize do
      tile.save(tmp.to_s)
      tile.delete!(true) if delete
    end
    GC.enable
    d = tmp.read
    tmp.unlink
    d
  end

  def string_to_jpeg(tile)
    IO.popen('rawtoppm 256 256 | ppmtojpeg', 'rb+'){|f|
      Thread.new{ f.write(tile) }
      f.read
    }
  end

  def info(user, query, *tile_args)
    return {} if tile_args[1] < 0 or tile_args[2] < 0
    q = query.clone
    q[:columns] ||= []
    q[:columns] |= [:image_index]
    indexes = iindexes = nil
    @@mutex.synchronize do
        key = user.id.to_s + "::" + sanitize_query(query)
        t = @@infos[key]
        unless t
          result = Items.rfind_all(user, q)
          idxs = result.map{|i| i.image_index }
          iidxs = result.map{|r| [r.image_index, (q[:columns] - [:image_index]).map{|c| [c, r[c]]}.to_hash ] }.to_hash
          t = @@infos[key] = [idxs, iidxs]
        end
        indexes, iindexes = t
    end
    infos = {}
    tile_drawer.tile_info(indexes, *tile_args){|i, *a| infos[i] = [a, iindexes[i]]}
    infos
  end

  private
  def sanitize_query(query)
    str = query.to_a.sort_by{|k,v| k.to_s}.map do |key, val| 
      [key, val].map{|str| str.to_s.gsub(/[^A-Za-z0-9_]/){|x| "%%%02X" % x[0]}}.join("_")
    end.join("+")
    str
    if str.size < 40
      str
    else
      Digest::SHA1.hexdigest(str).to_s
    end
  end

end


class TileDrawer

  LAYOUTERS = {}

  def initialize(image_cache = Future.image_cache)
    @image_cache = image_cache
    @max_cache_size = 1_000_000
    @raw_cache_level = 4
    @jpeg_cache_level = 4
    init_sw
  end

  def draw_tile(bgcolor, indexes, palette, layouter_name, x, y, zoom, w, h, *layouter_args)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.inspect}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    empty_tile = true
    layouter.each(indexes[0], x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      empty_tile = false
      break
    end
    return false if empty_tile
    return draw_tile_sw(bgcolor, indexes[1], palette, x, y, zoom) if zoom <= 7
    $imlib_mutex.synchronize do
      tile = Imlib2::Image.new(w,h)
      tile.fill_rectangle(0,0, w, h, Imlib2::Color::RgbaColor.new(bgcolor))
      layouter.each(indexes[0], x, y, sz, w, h, *layouter_args) do |i, ix, iy|
        @image_cache.draw_image_at(i[0], zoom, tile, ix, iy)
        if palette and palette[i[1]][3] != 0
          tile.fill_rectangle(ix, iy, sz, sz,
            Imlib2::Color::RgbaColor.new(palette[i[1]]))
        end
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

  def draw_tile_sw(bgcolor, indexes, palette, x, y, z)
    puts "#{Thread.current.telapsed} for tile init" if $PRINT_QUERY_PROFILE
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
    data = draw_query(indexes[0], indexes[1], cpalette, x, y, z,
        @image_cache.thumb_size_at_zoom(z), bgcolor.pack("CCC").reverse! << 255)
    puts "#{Thread.current.telapsed} for getting image into ruby" if $PRINT_QUERY_PROFILE
    GC.disable
    img = $imlib_mutex.synchronize do
      Imlib2::Image.create_using_data(256, 256, data)
    end
    puts "#{Thread.current.telapsed} for creating an imlib image" if $PRINT_QUERY_PROFILE
    img
  end

  @@sw_init = false

  def init_sw
    @@init_mutex.synchronize do
      return if @@sw_init
      @@sw_init = true
      puts "#{Time.now.to_f}: Reading #{@image_cache.max_index+1} thumbs of cache to RAM."
      init_image_cache(
        @max_cache_size, @raw_cache_level, @jpeg_cache_level,
        @image_cache.max_index
      )
      puts "#{Time.now.to_f}: Cache init done."
    end
  end

  @@init_mutex = Mutex.new

  def print_time_thumbs
    puts "#{Thread.current.telapsed} for reading thumbs" if $PRINT_QUERY_PROFILE
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

  def print_time_init
    puts "#{Thread.current.telapsed} for draw init" if $PRINT_QUERY_PROFILE
  end

  inline do |builder|
    builder.include "\"#{File.expand_path(File.dirname(__FILE__))}/stb_image.c\""
    builder.add_compile_flags "-Wall"
    builder.c_raw <<-EOF
      void do_nothing(){}
#define uint_32 int
/* unsigned long */
#define uint_64 int
/* unsigned long long */

      void sw_row_layout
      (
        uint_32* rtile_image_count,
        uint_64** rindexes,
        int** coords,
        uint_32 iindexes_length,
        uint_64 x,
        uint_64 y,
        uint_32 sz,
        uint_32 w,
        uint_32 h
      )
      {
        uint_32 columns, rows, bigrow_img_count;
        uint_32 y_offset, tpt;
        uint_64 bigrow, first_bigrow_in_view, last_bigrow_in_view;
        uint_64 first_row_in_view, last_row_in_view;
        uint_64 first_column_in_view, last_column_in_view, columns_in_view, rows_in_view;
        uint_64 i,r,j,c;
        uint_64 index;
        uint_64 *indexes = NULL;
        float row_offset, bigrow_height, ix, iy, first_row_y,
              first_bigrow_offset, last_bigrow_offset;
        uint_32 tile_image_count, l;
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

        indexes = (uint_64*)malloc((columns_in_view * rows_in_view) * sizeof(uint_64));
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
        uint_32 *colors, uint_32 colors_length,
        uint_32 sz
      )
      {
        uint_32 i,j,sz24,isz;
        unsigned short sa, da;
        uint_32 sr,sg,sb;
        unsigned char *color;

        sz24 = sz*sz*4;

        for (i=0; i<colors_length; i++) {
          if (colors[i] == 0) continue;
          color = (unsigned char*)(colors + i);
          isz = i*sz24+sz24;
          sa = color[3];
          da = 256 - sa;
          sr = (color[0]<<8)*sa;
          sg = (color[1]<<8)*sa;
          sb = (color[2]<<8)*sa;
          for (j=i*sz24; j<isz; j+=4) {
            thumbs[j] = ((thumbs[j]<<8)*da + sr)>>16;
            thumbs[j+1] = ((thumbs[j+1]<<8)*da + sg)>>16;
            thumbs[j+2] = ((thumbs[j+2]<<8)*da + sb)>>16;
            thumbs[j+3] = 255;
          }
        }
      }

      inline void blend_over(unsigned char* dst, unsigned char* src)
      {
        unsigned short sa, da;
        sa = src[3];
        da = 256 - sa;
        src[0] = ((dst[0]<<8)*da + (src[0]<<8)*sa)>>16;
        src[1] = ((dst[1]<<8)*da + (src[1]<<8)*sa)>>16;
        src[2] = ((dst[2]<<8)*da + (src[2]<<8)*sa)>>16;
        src[3] = 255;
      }
      
      char*** icache = NULL;
      uint_32 icache_levels = 0;
      uint_32 icache_size = 0;
      uint_32 icache_jpeg_levels = 0;

      char* setup_texture
      (
        VALUE self, uint_64* iindexes, uint_32 iindexes_length,
        uint_32 z, uint_32 sz, uint_64 *indexes, uint_32 indexes_length
      )
      {
        VALUE image_cache, thumb_data;
        VALUE read_imgs;
        char *pixels=NULL, *data=NULL, *thumb_ptr=NULL;
        uint_32 i, j, sz24, sz4, len, tsz, k;
        uint_64 index;
        int need_to_read = 0;
        char c;
        unsigned int w, h, n;
        VALUE *ptr=NULL;
        
        sz24 = sz*sz*4;
        sz4 = sz*4;
        pixels = (char*)malloc(sz24*indexes_length);
        if (pixels == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate pixels");
          return NULL;
        }
        for(i=0;i<sz24*indexes_length;i++) pixels[i] = 0;
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        read_imgs = rb_ary_new();
        for (i=0; i<indexes_length; i++) {
          index = indexes[i];
          if (index < iindexes_length && (z >= icache_jpeg_levels ||
              icache[z][iindexes[index]] == NULL))
          {
            rb_funcall(read_imgs, rb_intern("push"), 1, INT2FIX(iindexes[index]));
            need_to_read = 1;
          }
        }
        if (need_to_read == 1) {
          if (z >= icache_levels && z < icache_jpeg_levels) {
            thumb_data = rb_funcall(image_cache,
                                    rb_intern("read_images_as_jpeg"), 2,
                                    INT2FIX(z), read_imgs);
            len = RARRAY(read_imgs)->len;
            ptr = RARRAY(read_imgs)->ptr;
            thumb_ptr = StringValuePtr(thumb_data);
            for(i=0,k=0; i<len; i++) {
              tsz = *(int*)(thumb_ptr+k);
              data = malloc(tsz+4);
              if (data == NULL) {
                rb_raise(rb_eRuntimeError, "Failed to allocate new cache leaf");
                free(pixels);
                return NULL;
              }
              memcpy(data, thumb_ptr+k, tsz+4);
              icache[z][FIX2INT(ptr[i])] = data;
              k += tsz+4;
            }
          } else {
            thumb_data = rb_funcall(image_cache,
                                    rb_intern("read_images_as_string"), 2,
                                    INT2FIX(z), read_imgs);
            len = RARRAY(read_imgs)->len;
            ptr = RARRAY(read_imgs)->ptr;
            thumb_ptr = StringValuePtr(thumb_data);
            if (z < icache_levels) {
              for(i=0; i<len; i++) {
                data = (char*)malloc(sz24);
                if (data == NULL) {
                  rb_raise(rb_eRuntimeError, "Failed to allocate new cache leaf");
                  free(pixels);
                  return NULL;
                }
                memcpy(data, thumb_ptr+(i*sz24), sz24);
                icache[z][FIX2INT(ptr[i])] = data;
              }
            } else {
              for(i=0,j=0; i<indexes_length; i++) {
                index = indexes[i];
                if (index < iindexes_length){
                  memcpy(pixels+(sz24*i), thumb_ptr+(j*sz24), sz24);
                  j++;
                }
              }
            }
          }
        }
        if (z < icache_levels) {
          for(i=0; i<indexes_length; i++) {
            index = indexes[i];
            if (index < iindexes_length)
              memcpy(pixels+(sz24*i), icache[z][iindexes[index]], sz24);
          }
        } else if (z < icache_jpeg_levels) {
          for(i=0; i<indexes_length; i++) {
            index = indexes[i];
            if (index < iindexes_length) {
              thumb_ptr = icache[z][iindexes[index]];
              tsz = *(int*)thumb_ptr;
              if (tsz == 0) continue;
              data = stbi_jpeg_load_from_memory(thumb_ptr+4, tsz,
                                                &w, &h, &n, 4);
              for (j=0;j<w*h*4;j+=4) {
                c = data[j];
                data[j] = data[j+2];
                data[j+2] = c;
              }
              for (j=0;j<h;j++)
                memcpy(pixels+(sz24*i)+sz4*j, data+w*4*j, w*4);
              stbi_image_free(data);
            }
          }
        }
        return pixels;
      }

      char* draw_software
      (
        VALUE self,
        VALUE riindexes,
        VALUE riindex_colors,
        VALUE palette,
        uint_32 bgcolor,
        uint_64 x, uint_64 y, uint_32 z, uint_32 sz
      )
      {
        uint_64 *indexes = NULL;
        char *thumbs = NULL, *bordered_render = NULL, *final_render = NULL;
        uint_32 indexes_length;
        uint_64 *iindexes = NULL;
        uint_32 *iindex_colors = NULL, *colors = NULL;
        uint_32 iindexes_length;
        int *coords = NULL;
        int tx, ty;
        uint_32 *gl_palette = NULL;
        VALUE *qptr = NULL;
        uint_32 i, j, plen, sz24, sz4;
        
        sz24 = sz*sz*4;
        sz4 = sz*4;
        bordered_render = (char*)malloc(512*512*4);
        if (bordered_render == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate bordered_render");
          goto exit;
        }
        final_render = (char*)malloc(256*256*4);
        if (final_render == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate final_render");
          goto exit;
        }

        iindexes_length = RSTRING(riindexes)->len / sizeof(uint_64);
        iindexes = (uint_64*)StringValuePtr(riindexes);
        iindex_colors = (uint_32*)StringValuePtr(riindex_colors);
        
        plen = RARRAY(palette)->len;
        qptr = RARRAY(palette)->ptr;
        if (plen == 0) {
          gl_palette = NULL;
        } else {
          gl_palette = (uint_32*)malloc(plen * sizeof(uint_32));
          if (gl_palette == NULL) {
            rb_raise(rb_eRuntimeError, "Failed to allocate gl_palette");
            goto exit;
          }
          for(i=0; i<plen; i++) {
            gl_palette[i] = *((uint_32*)StringValuePtr(qptr[i]));
          }
        }

        rb_funcall(self, rb_intern("print_time_init"), 0);
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
        thumbs = setup_texture(self, iindexes, iindexes_length, z, sz, 
                               indexes, indexes_length);
        if (thumbs == NULL) {
          goto exit;
        }
        for (i=0; i<indexes_length*sz24; i+=4) {
          if (((unsigned char*)thumbs)[i+3] == 255) continue;
          if (((unsigned char*)thumbs)[i+3] == 0) {
            *((uint_32*)(thumbs+i)) = bgcolor;
          } else {
            blend_over((unsigned char*)(&bgcolor), (unsigned char*)(thumbs+i));
          }
        }
        rb_funcall(self, rb_intern("print_time_thumbs"), 0);
        colors = (uint_32*)malloc(sizeof(uint_32) * indexes_length);
        if (colors == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate colors");
          goto exit;
        }
        for (i=0; i<indexes_length; i++) {
          j = indexes[i];
          if (j < iindexes_length) {
            colors[i] = gl_palette[iindex_colors[j]];
          } else {
            colors[i] = 0;
          }
        }
        colorize(self, (unsigned char*)thumbs, colors, indexes_length, sz);
        rb_funcall(self, rb_intern("print_time_colors"), 0);

        for(i=0; i<262144; i++) {
          ((uint_32*)bordered_render)[i] = bgcolor;
        }
        
        for(i=0; i<indexes_length; i++) {
          if (indexes[i] >= iindexes_length) continue;
          tx = coords[i*2] + 128;
          ty = 512 * (coords[i*2+1] + 128);

          for (j=0; j<sz; j++) {
            memcpy(bordered_render + ty*4 + j*2048 + tx*4,
                   thumbs + i*sz24 + j*sz4,
                   sz4);
          }
        }

        for(i=0; i<256; i++)
          memcpy(final_render+1024*i, bordered_render+2048*(i+128)+512, 1024);
          
        exit:
        free(thumbs);
        free(bordered_render);
        free(coords);
        free(indexes);
        free(gl_palette);
        free(colors);
        
        rb_funcall(self, rb_intern("print_time_draw"), 0);
        
        return final_render;
      }

      
      void destroy_image_cache()
      {
        int i,j;
        char *c;
        if (icache != NULL) {
          for (i=0; i<icache_levels; i++)
          {
            for(j=0; j<icache_size; j++)
            {
              c = icache[i][j];
              if (c != NULL) free(c);
            }
            free(icache[i]);
          }
          free(icache);
          icache = NULL;
        }
        icache_levels = 0;
        icache_size = 0;
      }

      int cache_fill(VALUE self, uint_64 first_idx, uint_64 last_idx)
      {
        uint_64 j, k, span_end;
        uint_32 span_sz, i, tsz, l;
        VALUE image_cache, thumb_str;
        char *span = NULL, *thumb = NULL;
        
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        
        printf("normal cache fill start\\n");
        for(i=0; i<icache_levels; i++)
        {
          tsz = 4 << (i*2);
          span_sz = 1 << (18-(i*2)); // 1 MiB chunks
          for(j=first_idx; j<=last_idx; j+=span_sz)
          {
            span_end = j+span_sz;
            if (span_end > last_idx) span_end = last_idx;
            thumb_str = rb_funcall(image_cache,
                                rb_intern("read_span_as_string"), 3,
                                INT2FIX(i), INT2FIX(j), INT2FIX(span_end));
            span = StringValuePtr(thumb_str);
            for(k=0; k<RSTRING(thumb_str)->len; k+=tsz) {
              thumb = malloc(tsz);
              if ( thumb != NULL ) {
                memcpy(thumb, span+k, tsz);
                icache[i][j+(k/tsz)] = thumb;
              } else {
                return -1;
              }
            }
          }
          printf("level %d cached\\n", i);
        }
        printf("normal cache fill ok\\n");
        printf("jpeg cache fill start\\n");
        for(i=icache_levels; i < icache_jpeg_levels; i++) {
          span_sz = 1 << (21-(i*2)); // ~1 MiB chunks
          for(j=first_idx; j<=last_idx; j+=span_sz)
          {
            span_end = j+span_sz;
            if (span_end > last_idx) span_end = last_idx;
            thumb_str = rb_funcall(image_cache,
                                  rb_intern("read_span_as_jpeg"), 3,
                                  INT2FIX(i), INT2FIX(j), INT2FIX(span_end));
            span = StringValuePtr(thumb_str);
            for(k=0,l=0; k<RSTRING(thumb_str)->len; l++) {
              tsz = *(int*)(span+k);
              thumb = malloc(tsz+4);
              if ( thumb != NULL ) {
                memcpy(thumb, span+k, tsz+4);
                icache[i][j+l] = thumb;
              } else {
                return -1;
              }
              k += tsz+4;
            }
          }
          printf("level %d cached\\n", i);
        }
        printf("jpeg cache fill ok\\n");
        return 0;
      }
      
    EOF

    builder.c_raw <<-EOF
      VALUE draw_query(int argc, VALUE *argv, VALUE self)
      {
        char *image;
        VALUE rimage;
        if (argc != 8) {
          rb_raise(rb_eArgError, "Wrong number of args");
          return Qundef;
        }
        image = draw_software(self,
          argv[0], argv[1], argv[2],
          *((uint_32*)StringValuePtr(argv[7])),
          FIX2INT(argv[3]),FIX2INT(argv[4]),FIX2INT(argv[5]),FIX2INT(argv[6]));
        if (image == NULL) {
          return Qnil;
        } else {
          rimage = rb_str_new(image, 256*256*4);
          free(image);
          return rimage;
        }
      }
    EOF

    builder.c <<-EOF
      void init_image_cache
      (
        int cache_size, int cache_levels, int cache_jpeg_levels, int max_index
      )
      {
        int i,j;
        char **c;
        if (icache != NULL) destroy_image_cache();
        icache_size = (uint_32)cache_size;
        icache_levels = (uint_32)cache_levels + 1;
        icache_jpeg_levels = (uint_32)cache_jpeg_levels + 1;
        icache = (char***)malloc(sizeof(char**) * icache_jpeg_levels);
        if (icache == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate icache");
          goto fail;
        }
        for(i=0; i < icache_jpeg_levels; i++) {
          c = (char**)malloc(sizeof(char*) * icache_size);
          if (c == NULL) {
            rb_raise(rb_eRuntimeError, "Failed to allocate icache level");
            destroy_image_cache();
            goto fail;
          }
          for (j=0; j<icache_size; j++) c[j] = NULL;
          icache[i] = c;
        }
        cache_fill(self, 0, max_index);
        fail:
      }
    EOF

    builder.c <<-EOF
      void clear_cache_at(int index)
      {
        int i;
        char *c;
        if (index > 0 && index < icache_size)
        {
          for (i=0; i<icache_levels; i++)
          {
            c = icache[i][index];
            if (c != NULL)
            {
              free(c);
              icache[i][index] = NULL;
            }
          }
        }
      }
    EOF


  end


  module RowLayouter
  extend self

    def each(indexes, x, y, sz, w, h,
                  row_offset = sz / 2, columns = 200, rows = 5)
      return false if x < 0 or y < 0
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


module Tiles
  @@tile_drawer = TileDrawer.new
end


end # Future
