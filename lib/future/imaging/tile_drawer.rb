require 'future/imaging/image_cache'
require 'digest/sha1'
require 'inline'

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

  def palette(colors=false)
    if colors
      @@palette ||= create_palette
    else
      false
    end
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
          idxs = Items.rfind_all(user, query.merge(:columns => [:image_index, :mimetype_id])).map{|i| [i.image_index, i.mimetype_id] }
          t = @@indexes[key] = idxs
        end
        indexes = t
      end
      tile = TileDrawer.new.draw_tile(vbgcolor,indexes, palette(colors), r,x,y,z,w,h)
    end
    if tile
      qtext = sanitize_query(query)
      if tile.is_a? String
        IO.popen('rawtoppm 256 256 | ppmtojpeg', 'rb+'){|f|
          Thread.new{ f.write(tile) }
          f.read
        }
      else
        Future.tile_cache_dir.mkdir_p
        tmp = Future.tile_cache_dir + "tmptile-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.jpg"
        tile.save(tmp.to_s)
        tile.delete!(true)
        d = tmp.read
        tmp.unlink
        d
      end
    else
      img = Imlib2::Image.new(w,h)
      img.fill_rectangle(0,0, img.width, img.height, Imlib2::Color::RgbaColor.new(vbgcolor))
      Future.tile_cache_dir.mkdir_p
      tmp = Future.tile_cache_dir + "tmptile-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.jpg"
      img.save(tmp.to_s)
      img.delete!(true)
      d = tmp.read
      tmp.unlink
      d
    end
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
    TileDrawer.new.tile_info(indexes, *tile_args){|i, *a| infos[i] = [a, iindexes[i]]}
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
    layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      empty_tile = false
      break
    end
    return false if empty_tile
    return draw_tile_rend(bgcolor, indexes, palette, x, y, zoom) if zoom <= 7
    tile = Imlib2::Image.new(w,h)
    tile.fill_rectangle(0,0, w, h, Imlib2::Color::RgbaColor.new(bgcolor))
    layouter.each(indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
      @image_cache.draw_image_at(i[0], zoom, tile, ix, iy)
      if palette
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
    if palette
      pmax = palette.keys.max
      cpalette = (0..pmax).map{|i| palette[i] || [0,0,0,0]}.flatten.pack("c*").unpack("L*")
    else
      cpalette = []
    end
    @@draw_queue.push([rq, [bgcolor, indexes, cpalette, x, y, z, @image_cache.thumb_size_at_zoom(z)]])
    puts Time.now.to_f
    img = Imlib2::Image.create_using_data(256, 256, rq.pop)
    puts Time.now.to_f
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
                puts query[3]
                puts Time.now.to_f
                GL.Clear(GL::COLOR_BUFFER_BIT)
                GL.ClearColor(*query[0].map{|i| i / 255.0 })
                draw_query(*query[1..-1])
                puts Time.now.to_f
              rescue => e
                puts e, e.backtrace[0,5]
                puts
              end
              GL.Flush()
              d = GL.ReadPixels(
                0,0, 256, 256,
                GL::BGRA, GL::UNSIGNED_BYTE)
              puts Time.now.to_f
              rq.push(d)
              GLUT.SwapBuffers() unless use_fbo
            end
          end
        )
        GLUT.MainLoop
      end
      t.abort_on_exception = true
    end
  end

  def print_time
    puts Time.now.to_f
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
        uint_32 row_offset, columns, rows, bigrow_height, bigrow_img_count, ix, iy; 
        uint_32 y_offset, tpt;
        uint_64 bigrow, first_bigrow_in_view, last_bigrow_in_view;
        uint_64 first_bigrow_offset, last_bigrow_offset;
        uint_64 first_row_in_view, last_row_in_view, first_row_y;
        uint_64 first_column_in_view, last_column_in_view, columns_in_view, rows_in_view;
        uint_64 i,r,j,c;
        uint_64 index;
        uint_64 *indexes;
        GLfloat *varr, *texc;
        GLuint *colr;
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
        
        /* 4 3D points */
        varr = (GLfloat*)malloc( sizeof(GLfloat)*(columns_in_view * rows_in_view)*4*3 );
        /* 4 2D points */
        texc = (GLfloat*)malloc( sizeof(GLfloat)*(columns_in_view * rows_in_view)*4*2 );
        /* 4 packed colors */
        colr = (GLuint*)malloc( sizeof(GLuint)*(columns_in_view * rows_in_view)*4 );
        
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
      }

      void upload(char* pixels, uint_32 pxlen, uint_32 sz)
      {
        int c, i, r2, r, sz24, sz4;
        char *tex, *xyo;
        int offset;
        r = (512 / sz);
        r2 = r*r;
        sz24 = sz*sz*4;
        sz4 = sz*4;
        tex = (char*)malloc(512*512*4);
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

      char** icache;
      uint_32 icache_levels;

      void setup_texture
      (
        VALUE self, uint_64* iindexes, uint_32 iindexes_length,
        uint_32 z, uint_32 sz, uint_64 *indexes, uint_32 indexes_length
      )
      {
        VALUE image_cache, thumb_data;
        char *pixels, *data;
        uint_32 i, sz24;
        uint_64 index;
        
        sz24 = sz*sz*4;
        pixels = (char*)malloc(sz24*indexes_length);
        for(i=0;i<sz24*indexes_length;i++) pixels[i] = 0;
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        rb_funcall(self, rb_intern("print_time"), 0);
        for(i=0; i<indexes_length; i++) {
          index = indexes[i];
          if (index < iindexes_length) {
            if (z < icache_levels) {
              if (icache[z*32768 + index] != NULL) {
                memcpy(pixels+(sz24*i), icache[z*32768 + index], sz24);
              } else {
                thumb_data = rb_funcall(
                  image_cache,
                  rb_intern("read_image_at"), 2,
                  INT2FIX(iindexes[index]), INT2FIX(z)
                );
                data = (char*)malloc(sz24);
                memcpy(data, StringValuePtr(thumb_data), sz24);
                icache[z*32768 + index] = data;
                memcpy(pixels+(sz24*i), data, sz24);
              }
            } else {
              thumb_data = rb_funcall(
                image_cache,
                rb_intern("read_image_at"), 2,
                INT2FIX(iindexes[index]), INT2FIX(z)
              );
              memcpy(pixels+(sz24*i), StringValuePtr(thumb_data), sz24);
            }
          }
        }
        rb_funcall(self, rb_intern("print_time"), 0);
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
        iindex_colors = (uint_32*)malloc(iindexes_length * sizeof(uint_32));
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
          for(i=0; i<plen; i++) {
            gl_palette[i] = FIX2UINT(qptr[i]);
          }
        }
        
        row_layout(&indexes_length, &indexes, &vertex_array, &texcoords, &colors,
                   iindex_colors, iindexes_length, gl_palette,
                   x, y, sz, 256, 256);
        setup_texture(self, iindexes, iindexes_length, z, sz, indexes, indexes_length);
#ifdef NO_DEBUG
        glColor3f(1,1,1);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        glBegin(GL_QUADS);
        glTexCoord2d(0,0);
        glVertex3f(0,0,0);
        glTexCoord2d(512,0);
        glVertex3f(256,0,0);
        glTexCoord2d(512,512);
        glVertex3f(256,256,0);
        glTexCoord2d(0,512);
        glVertex3f(0,256,0);
        glEnd();
#else
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
#endif
        free(texcoords);
        free(vertex_array);
        free(indexes);
        free(colors);
        free(iindexes);
        free(iindex_colors);
        free(gl_palette);
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
        int i;
        icache = (char**)malloc(sizeof(char*) * cache_size * cache_levels);
        icache_levels = (uint_32)cache_levels;
        for(i=0; i < cache_size*cache_levels; i++) {
          icache[i] = NULL;
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
