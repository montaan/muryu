require 'future/imaging/image_cache'
require 'digest/sha1'
require 'inline'

require 'fastthread'

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
    @@tile_drawer ||= TileDrawer.new
  end

  def read(user, query, *tile_args)
    ### FIXME query optimization problematic (need to layout to get wanted spans,
    ###       then do a query for each (semi-)continuous span, e.g. layout says
    ###       that 4-10, 16-22, 28-34, 4182-4188, 4194-4200 needed
    ###       -> get 4-34, 4182-4200)
    ###
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
    if not bad_tile
      @@mutex.synchronize do
        key = user.name + "::" + sanitize_query(query)
        t = @@indexes[key]
        unless t
          idxs = Items.rfind_all(user, query.merge(:columns => [:image_index, :mimetype_id, :deleted], :as_array => true))
          tr = 't'
          idxs.each{|i|
            i[0]=i[0].to_i
            i[1]=(i.pop == tr ? MIMETYPE_DELETED : i[1].to_i)
          }
          t = @@indexes[key] = idxs
        end
        indexes = t
      end
      puts "#{Time.now.to_f}: indexes fetched"
      pal = palette(colors, vbgcolor)
      tile = tile_drawer.draw_tile(vbgcolor, indexes, pal, r,x,y,z,w,h)
    end
    if tile
      qtext = sanitize_query(query)
      if tile.is_a? String
        string_to_jpeg(tile)
      else
        imlib_to_jpeg(tile)
      end
    else
      img = Imlib2::Image.new(w,h)
      img.fill_rectangle(0,0, img.width, img.height, Imlib2::Color::RgbaColor.new(vbgcolor))
      imlib_to_jpeg(img)
    end
  end

  def imlib_to_jpeg(tile, delete=true)
    Future.cache_dir.+('ramdisk').mkdir_p
    tmp = Future.cache_dir + 'ramdisk' + "tmptile-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.jpg"
    tile.save(tmp.to_s)
    tile.delete!(true) if delete
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
    ### FIXME Query optimization problematic (again.)
    return {} if tile_args[1] < 0 or tile_args[2] < 0
    q = query.clone
    q[:columns] ||= []
    q[:columns] |= [:image_index]
    indexes = iindexes = nil
    @@mutex.synchronize do
        key = user.name + "::" + sanitize_query(query)
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
  end

  def draw_tile(bgcolor, indexes, palette, layouter_name, x, y, zoom, w, h, *layouter_args)
    layouter = LAYOUTERS[layouter_name.to_s]
    raise ArgumentError, "Bad layouter_name: #{layouter_name.inspect}" unless layouter
    sz = @image_cache.thumb_size_at_zoom(zoom)
    empty_tile = true
    puts "#{Time.now.to_f}: draw_tile init done"
    layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      empty_tile = false
      break
    end
    puts "#{Time.now.to_f}: checked tile emptiness"
    return false if empty_tile
    return draw_tile_rend(bgcolor, indexes, palette, x, y, zoom) if zoom <= 7
    tile = Imlib2::Image.new(w,h)
    tile.fill_rectangle(0,0, w, h, Imlib2::Color::RgbaColor.new(bgcolor))
    layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      @image_cache.draw_image_at(i[0], zoom, tile, ix, iy)
      if palette and palette[i[1]][3] != 0
        tile.fill_rectangle(ix, iy, sz, sz,
          Imlib2::Color::RgbaColor.new(palette[i[1]]))
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

  def draw_tile_rend(bgcolor, indexes, palette, x, y, z)
    init_rend unless @@rend_init
    rq = Queue.new
    puts "#{Time.now.to_f}: rend init done /tile/x#{x}y#{y}z#{z}"
    if palette
      pmax = palette.keys.max
      s = [0,0,0,0].pack("c*")
      cpalette = (0..pmax).map{|i|
        pl = palette[i]
        pl ? pl.pack("c*") : s
      }.join.unpack("L*")
    else
      cpalette = []
    end
    puts "#{Time.now.to_f}: pushing query /tile/x#{x}y#{y}z#{z}"
    @@draw_queue.push([rq, [bgcolor, indexes, cpalette, x, y, z, @image_cache.thumb_size_at_zoom(z)]])
    img = Imlib2::Image.create_using_data(256, 256, rq.pop)
    puts "#{Time.now.to_f}: created imlib image"
    img
  end

  @@rend_init = false
  @@draw_queue = Queue.new
  @@init_mutex = Mutex.new

  def init_rend
    return if @@rend_init
    @@init_mutex.synchronize do
      return if @@rend_init
      @@rend_init = true
      require 'opengl'
      require 'glut'
      require 'glew'
      use_fbo = true
      init_image_cache(1_000_000, 6)
      t = Thread.new do
        GLUT.Init
        GLUT.InitDisplayMode(GLUT::RGBA | GLUT::DOUBLE)
        GLUT.InitWindowSize(256, 256)
        GLUT.CreateWindow
        GLEW.Init
        GL.ClearColor(0.055, 0.137, 0.220, 1.0)
        GL.Enable(GL::BLEND)
        GL.BlendFunc(GL::SRC_ALPHA, GL::ONE_MINUS_SRC_ALPHA)
        tex, fbo_tex = GL::GenTextures(2)
        fbo = GL.GenFramebuffersEXT(1)[0]
        GL::Enable(GL::TEXTURE_RECTANGLE_EXT)
        GL::BindTexture(GL::TEXTURE_RECTANGLE_EXT, fbo_tex)
        GL::TexImage2D(GL::TEXTURE_RECTANGLE_EXT, 0,
          GL::RGBA, 256,256,0, GL::RGBA,
          GL::UNSIGNED_BYTE, nil)
        GL::BindTexture(GL::TEXTURE_RECTANGLE_EXT, tex)
        GL::TexImage2D(GL::TEXTURE_RECTANGLE_EXT, 0,
          GL::RGBA, 512,512,0, GL::RGBA,
          GL::UNSIGNED_BYTE, "\000\000\000\000"*(512*512))
        if use_fbo
          GL.BindFramebufferEXT(GL::FRAMEBUFFER_EXT, fbo)
          GL.FramebufferTexture2DEXT(GL::FRAMEBUFFER_EXT,
            GL::COLOR_ATTACHMENT0_EXT, GL::TEXTURE_RECTANGLE_EXT, fbo_tex, 0)
          GL.ReadBuffer(fbo)
        end
        GL.MatrixMode(GL::PROJECTION)
        GL.LoadIdentity
        GLU.Ortho2D(0, 256, 0, 256)
        GL.MatrixMode(GL::MODELVIEW)
        GL.LoadIdentity
        GL.Enable(GL::TEXTURE_RECTANGLE_EXT)
        GL.BindTexture(GL::TEXTURE_RECTANGLE_EXT, tex)
        GLUT.IdleFunc(
          lambda do
            loop do
              GL.Viewport(0,0,256,256)
              begin
                rq, query = @@draw_queue.shift
                GC.disable
                @draw_start = Time.now.to_f
                puts "#{@draw_start}: got query /tile/x#{query[3]}y#{query[4]}z#{query[5]}"
                GL.Clear(GL::COLOR_BUFFER_BIT)
                GL.ClearColor(*query[0].map{|i| i / 255.0 })
                draw_query(*query[1..-1])
              rescue => e
                puts e, e.backtrace[0,5]
                puts
              end
              GL.Flush()
              puts "#{Time.now.to_f-@draw_start}: query drawn /tile/x#{query[3]}y#{query[4]}z#{query[5]}"
              d = GL.ReadPixels(
                0,0, 256, 256,
                GL::BGRA, GL::UNSIGNED_BYTE)
              puts "#{Time.now.to_f-@draw_start}: image read from framebuffer"
              rq.push(d)
              GLUT.SwapBuffers() unless use_fbo
              GC.enable
            end
          end
        )
        GLUT.MainLoop
      end
      t.abort_on_exception = true
    end
  end

  def print_time_texture
    puts "#{Time.now.to_f-@draw_start}: texture built"
  end

  def print_time_upload
    puts "#{Time.now.to_f-@draw_start}: texture uploaded"
  end

  def print_time_layout
    puts "#{Time.now.to_f-@draw_start}: layout done"
  end

  inline do |builder|
    builder.include "<math.h>"
    builder.include "<netinet/in.h>"
    builder.include "<GL/glew.h>"
    builder.include "<GL/gl.h>"
    builder.include "<GL/glu.h>"
    builder.add_compile_flags "-Wall"
    if $PLATFORM =~ /darwin/
      flags = "-lm -framework opengl -lruby"
    else
      flags = "-lm -lGL -lGLU"
    end
    flags << " -lGLEW"
    builder.add_link_flags flags
    builder.c_raw <<-EOF
      void do_nothing(){}
#define uint_32 int
/* unsigned long */
#define uint_64 int
/* unsigned long long */

      void row_layout
      (
        uint_32* rtile_image_count,
        uint_64** rindexes,
        GLfloat** vertex_array,
        GLfloat** texcoords,
        GLuint** colors,
        uint_32* iindex_colors,
        uint_32 iindexes_length,
        GLuint* palette,
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
        GLfloat row_offset, bigrow_height, ix, iy, first_row_y,
                first_bigrow_offset, last_bigrow_offset;
        GLfloat *varr = NULL, *texc = NULL;
        GLuint *colr = NULL;
        uint_32 tile_image_count, k, l, m, tx, ty;

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
        
        /* 4 3D points */
        varr = (GLfloat*)malloc( sizeof(GLfloat)*(columns_in_view * rows_in_view)*4*3 );
        if (varr == NULL) goto fail;
        /* 4 2D points */
        texc = (GLfloat*)malloc( sizeof(GLfloat)*(columns_in_view * rows_in_view)*4*2 );
        if (texc == NULL) goto fail;
        /* 4 packed colors */
        colr = (GLuint*)malloc( sizeof(GLuint)*(columns_in_view * rows_in_view)*4 );
        if (colr == NULL) goto fail;
        
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
            l = tile_image_count * 12;
            k = tile_image_count * 8;
            m = tile_image_count * 4;
            tx = (tile_image_count % tpt) * sz;
            ty = (tile_image_count / tpt) * sz;

            varr[l+2] = varr[l+5] = varr[l+8] = varr[l+11] = 0.0f;
            varr[l] = varr[l+9] = ix;
            varr[l+6] = varr[l+3] = ix + sz;
            varr[l+1] = varr[l+4] = iy;
            varr[l+10] = varr[l+7] = iy + sz;
            
            texc[k] = texc[k+6] = tx;
            texc[k+4] = texc[k+2] = tx + sz;
            texc[k+1] = texc[k+3] = ty;
            texc[k+7] = texc[k+5] = ty + sz;

            if (palette != NULL) {
              colr[m] = colr[m+1] = colr[m+2] = colr[m+3] = (
                (index >= iindexes_length) ?
                0x00000000 :
                palette[iindex_colors[index]]);
            }
            tile_image_count++;
          }
        }
        *rtile_image_count = tile_image_count;
        *rindexes = indexes;
        *vertex_array = varr;
        *texcoords = texc;
        *colors = colr;
        return;
        
        fail:
        free(indexes);
        free(varr);
        free(texc);
        free(colr);
        *rtile_image_count = 0;
        *rindexes = NULL;
        *vertex_array = NULL;
        *texcoords = NULL;
        *colors = NULL;
      }

      void upload(char* pixels, uint_32 pxlen, uint_32 sz)
      {
        int c, i, r2, r, sz24, sz4;
        char *tex = NULL, *xyo = NULL;
        int offset;
        r = (512 / sz);
        r2 = r*r;
        sz24 = sz*sz*4;
        sz4 = sz*4;
        tex = (char*)malloc(512*512*4);
        if (tex == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate upload tex");
          return;
        }
        /* copy each subtexture (=pixels) to the correct position in
           the big texture (=tex) */
        for(c=0; c<pxlen; c++) {
          /* texture index: sz4*x + sz4*512*y */
          offset = (sz4*(c % r) + sz*2048*(c / r));
          xyo = tex + offset;
          /* copy each row of pixels to tex offset */
          for(i=0; i<sz; i++) {
            memcpy(xyo+2048*i, pixels+(c*sz24 + sz4*i), sz4);
          }
        }
        glTexSubImage2D(
          GL_TEXTURE_RECTANGLE_EXT, 0,
          0, 0, 512, 512,
          GL_BGRA, GL_UNSIGNED_BYTE, tex);
        free(tex);
      }

      char*** icache = NULL;
      uint_32 icache_levels = 0;
      uint_32 icache_size = 0;

      void setup_texture
      (
        VALUE self, uint_64* iindexes, uint_32 iindexes_length,
        uint_32 z, uint_32 sz, uint_64 *indexes, uint_32 indexes_length
      )
      {
        VALUE image_cache, thumb_data;
        VALUE read_imgs;
        char *pixels, *data, *thumb_ptr;
        uint_32 i, j, sz24, len;
        uint_64 index;
        int need_to_read = 0;
        VALUE *ptr;
        
        sz24 = sz*sz*4;
        pixels = (char*)malloc(sz24*indexes_length);
        if (pixels == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate pixels");
          return;
        }
        for(i=0;i<sz24*indexes_length;i++) pixels[i] = 0;
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        read_imgs = rb_ary_new();
        for (i=0; i<indexes_length; i++) {
          index = indexes[i];
          if (index < iindexes_length && (z >= icache_levels ||
              icache[z][iindexes[index]] == NULL))
          {
            rb_funcall(read_imgs, rb_intern("push"), 1, INT2FIX(iindexes[index]));
            need_to_read = 1;
          }
        }
        if (need_to_read == 1) {
          thumb_data = rb_funcall(image_cache,
                                  rb_intern("read_images_as_string"), 2,
                                  INT2FIX(z), read_imgs);
          len = RARRAY(read_imgs)->len;
          ptr = RARRAY(read_imgs)->ptr;
          thumb_ptr = StringValuePtr(thumb_data);
          if (z < icache_levels) {
            for(i=0; i<len; i++) {
              data = (char*)malloc(sz24);
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
        if (z < icache_levels) {
          for(i=0; i<indexes_length; i++) {
            index = indexes[i];
            if (index < iindexes_length)
              memcpy(pixels+(sz24*i), icache[z][iindexes[index]], sz24);
          }
        }
        rb_funcall(self, rb_intern("print_time_texture"), 0);
        upload(pixels, indexes_length, sz);
        free(pixels);
      }


      void draw(VALUE self, VALUE query, VALUE palette, uint_64 x, uint_64 y, uint_32 z, uint_32 sz)
      {
        uint_64* indexes;
        GLfloat* vertex_array;
        GLfloat* texcoords;
        GLuint* colors;
        uint_32 indexes_length;
        uint_64* iindexes;
        uint_32* iindex_colors;
        uint_32 iindexes_length;
        GLuint* gl_palette;
        VALUE *qptr;
        uint_32 i, plen;
        qptr = RARRAY(query)->ptr;
        iindexes_length = RARRAY(query)->len;
        iindexes = (uint_64*)malloc(iindexes_length * sizeof(uint_64));
        if (iindexes == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate iindexes");
          goto exit;
        }
        iindex_colors = (uint_32*)malloc(iindexes_length * sizeof(uint_32));
        if (iindex_colors == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate iindex_colors");
          goto exit;
        }
        for(i=0; i<iindexes_length; i++) {
          iindexes[i] = FIX2UINT(RARRAY(qptr[i])->ptr[0]);
          iindex_colors[i] = FIX2UINT(RARRAY(qptr[i])->ptr[1]);
        }
        plen = RARRAY(palette)->len;
        qptr = RARRAY(palette)->ptr;
        if (plen == 0) {
          gl_palette = NULL;
        } else {
          gl_palette = (GLuint*)malloc(plen * sizeof(GLuint));
          if (gl_palette == NULL) {
            rb_raise(rb_eRuntimeError, "Failed to allocate gl_palette");
            goto exit;
          }
          for(i=0; i<plen; i++) {
            gl_palette[i] = FIX2UINT(qptr[i]);
          }
        }

        row_layout(&indexes_length, &indexes, &vertex_array, &texcoords, &colors,
                   iindex_colors, iindexes_length, gl_palette,
                   x, y, sz, 256, 256);
        if (indexes == NULL || vertex_array == NULL || texcoords == NULL ||
            colors == NULL)
        {
          rb_raise(rb_eRuntimeError, "Failed to allocate layout");
          goto exit;
        }
        rb_funcall(self, rb_intern("print_time_layout"), 0);
        setup_texture(self, iindexes, iindexes_length, z, sz, indexes, indexes_length);
        rb_funcall(self, rb_intern("print_time_upload"), 0);

        glPushAttrib(GL_COLOR_BUFFER_BIT | GL_CURRENT_BIT | GL_ENABLE_BIT | GL_TEXTURE_BIT);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDisable(GL_DEPTH_TEST);
        
        glPushClientAttrib(GL_CLIENT_VERTEX_ARRAY_BIT);
          glEnable( GL_TEXTURE_RECTANGLE_EXT );
          glDisableClientState( GL_NORMAL_ARRAY );
          glDisableClientState( GL_COLOR_ARRAY );
          glEnableClientState( GL_VERTEX_ARRAY );
          glEnableClientState( GL_TEXTURE_COORD_ARRAY );
          glColor4f(1.0, 1.0, 1.0, 1.0);
          
          glVertexPointer(3, GL_FLOAT, 0, vertex_array);
          glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
          
          glDrawArrays(GL_QUADS, 0, indexes_length*4);
          if (gl_palette != NULL) {
            glDisable( GL_TEXTURE_RECTANGLE_EXT );
            glDisableClientState( GL_TEXTURE_COORD_ARRAY );
            glEnableClientState( GL_COLOR_ARRAY );
            glColorPointer(4, GL_UNSIGNED_BYTE, 0, colors);
            glDrawArrays(GL_QUADS, 0, indexes_length*4);
          }
        glPopClientAttrib();
        glPopAttrib();
        
        exit:
        free(texcoords);
        free(vertex_array);
        free(indexes);
        free(colors);
        free(iindexes);
        free(iindex_colors);
        free(gl_palette);
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
    EOF

    builder.c_raw <<-EOF
      VALUE draw_query(int argc, VALUE *argv, VALUE self)
      {
        if (argc != 6) {
          rb_raise(rb_eArgError, "Wrong number of args");
          return Qundef;
        }
        draw(self,
          argv[0], argv[1],
          FIX2INT(argv[2]),FIX2INT(argv[3]),FIX2INT(argv[4]),FIX2INT(argv[5]));
        return Qnil;
      }
    EOF


    builder.c <<-EOF
      void init_image_cache(int cache_size, int cache_levels)
      {
        int i,j;
        char **c;
        if (icache != NULL) destroy_image_cache();
        icache_size = (uint_32)cache_size;
        icache_levels = (uint_32)cache_levels;
        icache = (char***)malloc(sizeof(char**) * icache_levels);
        if (icache == NULL) {
          rb_raise(rb_eRuntimeError, "Failed to allocate icache");
          goto fail;
        }
        for(i=0; i < icache_levels; i++) {
          c = (char**)malloc(sizeof(char*) * icache_size);
          if (c == NULL) {
            rb_raise(rb_eRuntimeError, "Failed to allocate icache level");
            destroy_image_cache();
            goto fail;
          }
          for (j=0; j<icache_size; j++) c[j] = NULL;
          icache[i] = c;
        }
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


end # Future
