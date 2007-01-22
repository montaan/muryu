
require 'rend'
include Rend

sz = (ARGV[0] || 512).to_i
extra_images = (ARGV[1] || 1).to_i

img = 'data/tiles_0.png'
tmp_img = 'tmp/tex.tga'

verts = []
texcoords = []

imi = Imlib2::Image.load(img)
imi.crop_scaled!(0, 0, imi.width, imi.height, sz, sz)
imi.save(tmp_img)
imi.delete!

i = Image.new(:image => tmp_img, :mipmapping => false, :transparent => true, :z => 0)
imgs = (1..extra_images).map{|j|
  Image.new(:image => tmp_img, :mipmapping => false, :transparent => true, :z => j,
  :blend_mode => :add)
}

data = ""
i.on_frame{
  GL::ReadBuffer(GL::FRONT)
  data = GL::ReadPixels(
    0,0, Rend.width, Rend.height,
    Rend::Renderer::NATIVE_TEXTURE_FORMAT, GL::UNSIGNED_BYTE)
  GL::ReadBuffer(GL::BACK)
  data.tr!("\002", "\001")
  i.texture.pixels = i.texture.pixels
  imgs.each{|i2|
    i2.texture.pixels = i2.texture.pixels
  }
}

i.attach *imgs
Rend.init(:width => sz, :height => sz)
Rend.overlay << i
Thread.new{ loop do sleep 1; puts Rend.fps; end }
Rend.thread.join
