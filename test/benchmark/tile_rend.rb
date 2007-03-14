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
colors = []

imi = Imlib2::Image.load(img)
imi.crop_scaled!(0, 0, imi.width, imi.height, sz, sz)
imi.save(tmp_img)
imi.delete!

i = Image.new(:image => tmp_img, :mipmapping => false)
eimgs = (1..extra_images).map{ 
  Image.new(:image => tmp_img, :mipmapping => false)
}
File.open("tmp/tex.raw",'wb'){|f| f.write(i.texture.pixels) }

tcolors = [[0.3, 0.3, 1, 1], [0, 1, 0, 1], [0, 1, 1,1], [1,1,0,1], [1,0,0,1]]

(0...256).each{|x|
  (0...256).each{|y|
    verts.push(x, y, 0, x+1, y, 0, x+1, y+1, 0, x, y+1, 0)
    texcoords.push(x, y, x+1, y, x+1, y+1, x, y+1)
    colors.push(*(tcolors[(rand**4)*5]*4))
  }
}

g = Geometry.new(:type => :quads, :vertices => verts, :texcoords => texcoords.pack("f*"), :colors => colors.pack("f*"))
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
    end
    # comment out to not upload texture on every frame
    m.texture.pixels = t.pixels
    eimgs.each{|im| im.texture.pixels = im.texture.pixels }
    done += 1
  end
}

m.attach *eimgs unless eimgs.empty?

Rend.init(:width => 256, :height => 256)
Rend.scene << m 
Rend.thread.join
