require 'imlib2'
require 'benchmark'

pn = File.dirname(__FILE__)
types = %w(jpg png tga)

Benchmark.bm do |x|
  img = Imlib2::Image.load(pn+"/data/cache_image_0.jpg")
  jpg = img.crop(0,0,512,512)
  types.each do |t|
    x.report("10x save 512x512 "+t) do
      10.times do |i| jpg.save(pn+"/tmp/save_image_#{i}."+t) end
    end
  end
end
