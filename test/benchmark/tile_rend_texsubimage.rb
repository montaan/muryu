=begin
512x512 texture:
Texture load from fs cache, 120fps (= 8.3ms)
Without texture load from disk, 154fps (= 6.4ms)
Without texture upload, 200fps (= 5ms)

256x256 texture:
Texture load from fs cache, 135fps (= 7.4ms)
Without texture load from disk, 185fps (= 5.4ms)
Without texture upload, 200fps (= 5ms)

What this does:

- creates a tile with 65536 items from a cache image
- the texture, vertex array and texcoord array are uploaded to the 
  graphics card on every frame
- the framebuffer is read to memory on every frame


Meaning:

- drawing a tile of 1x1px items takes 7.4ms
- if the cache image is in system memory, drawing a tile takes 5.4ms
- if the cache image is in graphics card memory, drawing a tile takes 5ms
- every extra cache image not in gfx card mem adds 0.4 - 2.4ms draw time (?)

=end

require 'rend'
include Rend

sz = (ARGV[0] || 512).to_i
extra_images = (ARGV[1] || 0).to_i

img = 'data/tiles_0.png'
tmp_img = 'tmp/tex.tga'

verts = []
texcoords = []

imi = Imlib2::Image.load(img)
imi.crop_scaled!(0, 0, imi.width, imi.height, sz, sz)
imi.save(tmp_img)
imi.delete!

i = Image.new(:image => tmp_img, :mipmapping => false)
eimgs = (1..extra_images).map{ 
  Image.new(:image => tmp_img, :mipmapping => false)
}
File.open("tmp/tex.raw",'wb'){|f| f.write(i.texture.pixels) }

(0...256).each{|x|
  (0...256).each{|y|
    verts.push(x, y, 0, x+1, y, 0, x+1, y+1, 0, x, y+1, 0)
    texcoords.push(x, y, x+1, y, x+1, y+1, x, y+1)
  }
}

g = Geometry.new(:type => :quads, :vertices => verts, :texcoords => texcoords.pack("f*"))
puts g.vert_count / 4
t = i.texture
t.mode = :PIXEL_RECTANGLE
m = Model.new
m.scale = 2 / 256.0
m.material = i.material
m.texture = t
m.color = i.color
m.y = -0.5
m.geometry = g
m.add_motion(Rotate.new(90))
data = ""
done = 0
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
    builder.c <<-EOF
      void upload()
      {
        int c, i, sz, r2, r, sz24, sz4;
        char *pixels, *tex, *xyo;
        sz = 1;
        r = 256 / sz;
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
          /* texture index: 4 bytes * (x + r*y) */
          xyo = tex + (4 * ((c % r) + r*(c / r)));
          /* copy each row of pixels to tex offset */
          for(i=0; i<sz; i++) {
            memcpy(xyo + 1024*i, pixels + sz4*i, sz4);
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
  end
end

texup = TextureUploader.new

m.on_frame{
  GL::ReadBuffer(GL::FRONT)
  data = GL::ReadPixels(
    0,0, Rend.width, Rend.height,
    Rend::Renderer::NATIVE_TEXTURE_FORMAT, GL::UNSIGNED_BYTE)
  GL::ReadBuffer(GL::BACK)
  if Rend.fps
    if done < 5 or done % 100 == 0
      bw = (1 / ((1 / Rend.fps)-0.005)) * t.pixels.size * (eimgs.size + 1) / 1e6
      puts "#{Rend.fps}: #{"%.1f" % bw}MB/s texture bandwidth"
    end
    if done == 999
      t.pixels = File.read('tmp/tex.raw')
      puts "vvvvv texture loaded"
      done = 99
    else
      # comment out to not upload texture on every frame
      texup.upload
#       c = 0
#       sz = 16
#       r = 256 / sz
#       sz24 = sz*sz*4
#       while c < 256
#         GL::TexSubImage2D(
#           GL::TEXTURE_RECTANGLE_EXT, 0, sz * (c % r), sz * (c / r), sz, sz,
#           GL::RGBA, GL::UNSIGNED_BYTE, t.pixels[c*sz24, sz24])
#         c += 1
#       end
      #m.texture.pixels = t.pixels
      #eimgs.each{|im| im.texture.pixels = im.texture.pixels }
    end
    done += 1
  end
}

m.attach *eimgs unless eimgs.empty?

Rend.init(:width => 256, :height => 256)
Rend.scene << m 
Rend.thread.join
