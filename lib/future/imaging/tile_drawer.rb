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

  def open(user, query, *tile_args, &block)
    ### FIXME query optimization problematic (need to layout to get wanted spans,
    ###       then do a query for each (semi-)continuous span, e.g. layout says
    ###       that 4-10, 16-22, 28-34, 4182-4188, 4194-4200 needed
    ###       -> get 4-34, 4182-4200)
    ###
    bad_tile = (tile_args[1] < 0 or tile_args[2] < 0)
    indexes = nil
    if not bad_tile
      @@mutex.synchronize do
        indexes = (@@indexes[user.name + "::" + sanitize_query(query)] ||= Items.rfind_all(user, query.merge(:columns => [:image_index])).map{|i| i.image_index })
      end
      tile = TileDrawer.new.draw_tile(indexes, *tile_args)
    end
    Future.tile_cache_dir.mkdir_p
    if tile
      ### FIXME cache badness
      r,x,y,z,w,h = *tile_args
      qtext = sanitize_query(query)
      #fn = Future.tile_cache_dir + %!tile_#{qtext}_#{[r,"#{w}x#{h}",z,x,y].join("_")}.jpg!
      fn = Future.tile_cache_dir + "tmptile-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.jpg"
      tile['quality'] = [30, [(z-1)*10, 90].min].max
      tile.save(fn.to_s)
      tile.delete!(true)
      #File.rename(tmp, fn.to_s)
    else
      fn = Future.empty_tile
      unless fn.exist?
        img = Imlib2::Image.new(*tile_args[-2,2])
        img.fill_rectangle(0,0, img.width, img.height, BACKGROUND_COLOR)
        tmp = Future.tile_cache_dir + "tmptile-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.jpg"
        img.save(tmp.to_s)
        img.delete!(true)
        File.rename(tmp, fn)
      end
    end
    fn.open('rb', &block)
  end

  def read(*a)
    open(*a){|f| f.read }
  end

  def info(user, query, *tile_args)
    ### FIXME Query optimization problematic (again.)
    return {} if tile_args[1] < 0 or tile_args[2] < 0
    q = query.clone
    q[:columns] ||= []
    q[:columns] |= [:image_index]
    indexes = iindexes = nil
    @@mutex.synchronize do
      indexes, iindexes = *(@@infos[user.name + "::" + sanitize_query(q)] ||= (
        result = Items.rfind_all(user, q)
        idxs = result.map{|r| r.image_index }
        iidxs = result.map{|r| [r.image_index, (q[:columns] - [:image_index]).map{|c| [c, r[c]]}.to_hash ] }.to_hash
        [idxs, iidxs]
      ))
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
    return draw_tile_rend(indexes, x, y, zoom) if zoom <= 7
    tile = Imlib2::Image.new(w,h)
    tile.fill_rectangle(0,0, w, h, BACKGROUND_COLOR)
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

  def draw_tile_rend(indexes, x, y, z)
    init_rend unless @@rend_init
    rq = Queue.new
    @@draw_queue.push([rq, [indexes, x, y, @image_cache.thumb_size_at_zoom(z)]])
    Imlib2::Image.create_using_data(256, 256, rq.pop)
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
      t = Thread.new do
        GLUT.Init
        GLUT.InitDisplayMode(GLUT::DOUBLE | GLUT::RGB)
        GLUT.InitWindowSize(128, 128)
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
        GL.BindFramebufferEXT(GL::FRAMEBUFFER_EXT, fbo)
        GL.FramebufferTexture2DEXT(GL::FRAMEBUFFER_EXT,
          GL::COLOR_ATTACHMENT0_EXT, GL::TEXTURE_RECTANGLE_EXT, fbo_tex, 0)
        GL.ReadBuffer(fbo)
        GL.MatrixMode(GL::PROJECTION)
        GL.LoadIdentity
        GLU.Ortho2D(0, 256, 0, 256)
        GL.MatrixMode(GL::MODELVIEW)
        GL.LoadIdentity
        GLUT.IdleFunc(
          lambda do
            GL.Viewport(0,0,256,256)
            GL.Clear(GL::COLOR_BUFFER_BIT)
            begin
              GL.Enable(GL::TEXTURE_RECTANGLE_EXT)
              GL.BindTexture(GL::TEXTURE_RECTANGLE_EXT, tex)
              rq, query = @@draw_queue.shift
              puts query[3]
              puts Time.now.to_f
              draw_query(*query)
              puts Time.now.to_f
            rescue => e
              puts e, e.backtrace[0,5]
              puts
            end
            GL::Flush()
            d = GL::ReadPixels(
              0,0, 256, 256,
              GL::BGRA, GL::UNSIGNED_BYTE)
            puts Time.now.to_f
            puts
            rq.push(d)
            GLUT.SwapBuffers()
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
        uint_64 *indexes;
        GLfloat *varr, *texc;
        uint_32 tile_image_count, k, l, tx, ty;

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
            indexes[tile_image_count] = (bigrow * bigrow_img_count) + (c * rows) + (r % rows);
            l = tile_image_count * 12;
            k = tile_image_count * 8;
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
            tile_image_count++;
          }
        }
        *rtile_image_count = tile_image_count;
        *rindexes = indexes;
        *vertex_array = varr;
        *texcoords = texc;
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
      
      void setup_texture
      (
        VALUE self, VALUE query,
        uint_32 sz, uint_64 *indexes, uint_32 indexes_length
      )
      {
        VALUE image_cache, thumb_data;
        char *pixels, *data;
        uint_32 i, sz24;
        VALUE *qptr;
        int qlen;
        uint_64 index;
        
        sz24 = sz*sz*4;
        pixels = (char*)malloc(sz24*indexes_length);
        for(i=0;i<sz24*indexes_length;i++) pixels[i] = 0;
        data = (char*)malloc(sz24);
        for(i=0;i<sz24;i++) data[i] = 255;
        image_cache = rb_ivar_get(self, rb_intern("@image_cache"));
        qlen = RARRAY(query)->len;
        qptr = RARRAY(query)->ptr;
        rb_funcall(self, rb_intern("print_time"), 0);
        for(i=0; i<indexes_length; i++) {
          index = indexes[i];
          if (index >= qlen) {
            /* memcpy(pixels+(sz24*i), data, sz24); */
          } else {
            thumb_data = rb_funcall(
              image_cache,
              rb_intern("read_image_at"), 2,
              qptr[index], INT2FIX(sz)
            );
            memcpy(pixels+(sz24*i), StringValuePtr(thumb_data), sz24);
          }
        }
        rb_funcall(self, rb_intern("print_time"), 0);
        upload(pixels, indexes_length, sz);
        free(pixels);
      }

      void draw(VALUE self, VALUE query, uint_64 x, uint_64 y, uint_32 sz)
      {
        uint_64* indexes;
        GLfloat* vertex_array;
        GLfloat* texcoords;
        uint_32 indexes_length;
        row_layout(&indexes_length, &indexes, &vertex_array, &texcoords,
                    x, y, sz, 256, 256);
        setup_texture(self, query, sz, indexes, indexes_length);
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
        glEnableClientState( GL_VERTEX_ARRAY );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glDisableClientState( GL_NORMAL_ARRAY );
        glDisableClientState( GL_COLOR_ARRAY );
        glVertexPointer(3, GL_FLOAT, 0, vertex_array);
        glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
        glDrawArrays(GL_QUADS, 0, indexes_length*4);
#endif
        free(texcoords);
        free(vertex_array);
        free(indexes);
      }
    EOF

    builder.c_raw <<-EOF
      VALUE draw_query(int argc, VALUE *argv, VALUE self)
      {
        if (argc != 4) {
          rb_raise(rb_eArgError, "Wrong number of args");
          return Qundef;
        }
        draw(self,
          argv[0],
          FIX2INT(argv[1]),FIX2INT(argv[2]),FIX2INT(argv[3]));
        return Qnil;
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
