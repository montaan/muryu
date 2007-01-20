require 'rend'
include Rend

sz = (ARGV[0] || 512).to_i
extra_images = (ARGV[1] || 0).to_i

img = 'data/tiles_0.png'
tmp_img = 'tmp/tex.tga'

class TextureUploader
  inline do |builder|
    builder.include "<math.h>"
    builder.include "<netinet/in.h>"
    builder.include "<GL/glew.h>"
    builder.include "<GL/gl.h>"
    builder.include "<GL/glu.h>"
    builder.add_compile_flags "-Wall"
    if MAC_OS_X
      flags = "-lm -framework opengl -lruby"
    else
      flags = "-lm -lGL -lGLU"
    end
    flags << " -lGLEW"
    builder.add_link_flags flags
    builder.c <<-EOF
      void upload_sub()
      {
        int c, sz, r2, r, sz24;
        char *pixels;
        sz = 1;
        r = 256 / sz;
        r2 = r*r;
        sz24 = sz*sz*4;
        pixels = (char*)malloc(sz24);
        for(c=0; c<r2; c++) {
          glTexSubImage2D(
            GL_TEXTURE_RECTANGLE_EXT, 0,
            sz * (c % r), sz * (c / r), sz, sz,
            GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        }
        free(pixels);
      }
    EOF
    builder.c_raw <<-EOF
      void upload()
      {
        int c, i, sz, r2, r, sz24, sz4;
        char *pixels, *tex, *xyo;
        sz = 16;
        r = (256 / sz) + 2;
        r2 = r*r;
        sz24 = sz*sz*4;
        sz4 = sz*4;
        tex = (char*)malloc(512*512*4);
        pixels = (char*)malloc(sz24);
        for(i=0; i<sz24; i+=4) {
          pixels[i] = 255;
          pixels[i+1] = 0;
          pixels[i+2] = 0;
          pixels[i+3] = 255;
        }
        /* copy each subtexture (=pixels) to the correct position in
           the big texture (=tex) */
        for(c=0; c<r2; c++) {
          /* texture index: sz4*x + sz4*512*y */
          xyo = tex + (sz4*(c % r) + sz4*512*(c / r));
          /* copy each row of pixels to tex offset */
          for(i=0; i<sz; i++) {
            memcpy(xyo + 2048*i, pixels + sz4*i, sz4);
          }
        }
        glTexSubImage2D(
          GL_TEXTURE_RECTANGLE_EXT, 0,
          0, 0, 512, 512,
          GL_RGBA, GL_UNSIGNED_BYTE, tex);
        free(pixels);
        free(tex);
      }
    EOF
    builder.c_raw <<-EOF
      void do_nothing(){}
#define uint_32 unsigned long
#define uint_64 unsigned long long

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
        uint_32 y_offset;
        uint_64 bigrow, first_bigrow_in_view, last_bigrow_in_view;
        uint_64 first_bigrow_offset, last_bigrow_offset;
        uint_64 first_row_in_view, last_row_in_view, first_row_y;
        uint_64 first_column_in_view, last_column_in_view, columns_in_view, rows_in_view;
        uint_64 i,r,j,c;
        uint_64 *indexes;
        GLfloat *varr, *texc;
        uint_32 tile_image_count, k, l, tx, ty;

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
            tx = (tile_image_count * sz) % w;
            ty = (tile_image_count * sz) / w;
            varr[l+2] = varr[l+5] = varr[l+8] = varr[l+11] = 0.0f;
            varr[l] = varr[l+3] = ix;
            varr[l+6] = varr[l+9] = ix + sz;
            varr[l+1] = varr[l+10] = iy;
            varr[l+4] = varr[l+7] = iy + sz;
            texc[k] = texc[k+2] = tx;
            texc[k+4] = texc[k+6] = tx + sz;
            texc[k+1] = texc[k+7] = ty;
            texc[k+3] = texc[k+5] = ty + sz;
            tile_image_count++;
          }
        }
        *rtile_image_count = tile_image_count;
        *rindexes = indexes;
        *vertex_array = varr;
        *texcoords = texc;
      }

      void setup_texture
      (
        char* query, uint_32 query_len,
        uint_64* indexes, uint_32 indexes_length
      )
      {
        upload();
      }

      void draw(char* query, uint_32 query_len, uint_64 x, uint_64 y, uint_32 sz)
      {
        uint_64* indexes;
        GLfloat* vertex_array;
        GLfloat* texcoords;
        uint_32 indexes_length;
        int i;
        row_layout(&indexes_length, &indexes, &vertex_array, &texcoords,
                    x, y, sz, 256, 256);
        setup_texture(query, query_len, indexes, indexes_length);
        glEnableClientState( GL_VERTEX_ARRAY );
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glDisableClientState( GL_NORMAL_ARRAY );
        glDisableClientState( GL_COLOR_ARRAY );
        glVertexPointer(3, GL_FLOAT, 0, vertex_array);
        glTexCoordPointer(2, GL_FLOAT, 0, texcoords);
        glDrawArrays(GL_QUADS, 0, indexes_length);
        for(i=12000; i<12032; i++)
        {
          printf("(%.0f, %.0f, %.0f)-(%.0f, %.0f) ",
                 vertex_array[i*3], vertex_array[i*3+1], vertex_array[i*3+2],
                 texcoords[i*2], texcoords[i*2+1]
                 );
          if (i%4 == 3) printf("\\n");
        }
        printf("\\n");
        free(texcoords);
        free(vertex_array);
        free(indexes);
      }
    EOF

    builder.c <<-EOF
      void draw_query()
      {
        draw("foo",3,0,0,1);
      }
    EOF
  end
end

verts = []
texcoords = []

imi = Imlib2::Image.load(img)
imi.crop_scaled!(0, 0, imi.width, imi.height, sz, sz)
imi.save(tmp_img)
imi.delete!

i = Image.new(:image => tmp_img, :mipmapping => false)

t = i.texture
t.mode = :PIXEL_RECTANGLE
m = Model.new
m.material = i.material
m.texture = t
m.color = i.color
data = ""
done = 0
texup = TextureUploader.new

m.on_frame{
  GL::ReadBuffer(GL::FRONT)
  data = GL::ReadPixels(
    0,0, Rend.width, Rend.height,
    Rend::Renderer::NATIVE_TEXTURE_FORMAT, GL::UNSIGNED_BYTE)
  GL::ReadBuffer(GL::BACK)
  if Rend.fps
    if done < 5 or done % 100 == 0
      puts Rend.fps
    end
    texup.draw_query
    done += 1
  end
}

Rend.init(:width => 256, :height => 256)
Rend.scene.background = [0.1, 0.15, 0.3, 1.0]
Rend.overlay << m
Rend.thread.join
