=begin
512x512 texture:
Texture load from fs cache, 55fps (= 18ms)
Without texture load from disk, 87fps (= 11ms)
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

verts = []
texcoords = []
i = Image.new(:image => 'data/tiles_0.png')
File.open("tmp/tiles_0.raw",'wb'){|f| f.write(i.texture.pixels) }

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
m.on_frame{
        GL::ReadBuffer(GL::FRONT)
        data = GL::ReadPixels(
          0,0, Rend.width, Rend.height,
          Rend::Renderer::NATIVE_TEXTURE_FORMAT, GL::UNSIGNED_BYTE)
        GL::ReadBuffer(GL::BACK)
  if Rend.fps
    puts Rend.fps if done < 5 or done % 100 == 0
    if done == 999
      t.pixels = File.read('tmp/tiles_0.raw')
      puts "vvvvv texture loaded"
      done = 99
    end
# comment out to not upload texture on every frame
    m.texture.pixels = t.pixels
    done += 1
  end
}

Rend.init(:width => 256, :height => 256)
Rend.scene << m
Rend.thread.join
