require 'imlib2'
require 'benchmark'

pn = File.dirname(__FILE__)
types = %w(jpg png tga)

Benchmark.bm do |x|
  img = Imlib2::Image.load(pn+"/data/cache_image_0.jpg")
  types.each do |t|
    x.report("10x save 512x512 "+t) do
      10.times do |i| 
        img.crop!(0,0,512,512)
        img.save(pn+"/tmp/save_image_#{i}."+t)
      end
    end
  end
  x.report("10x save 256x256 jpg") do
      10.times do |i| 
        img.crop!(0,0,256,256)
        img.save(pn+"/tmp/save_image_256_#{i}.jpg")
      end
  end
end
