require 'imlib2'
require 'benchmark'

types = %w(jpg png tga)

pn = File.dirname(__FILE__)
fns = Dir[pn+"/data/cache_image_*.jpg"].map do |fn| File.basename(fn) end
fns.each do |fn|
  im = Imlib2::Image.load(pn+'/data/'+fn)
  types.each do |t|
    im.crop!(0,0,512,512)
    im.save(pn+'/tmp/'+fn[0..-4]+t)
  end
  im.delete!(true)
end

Benchmark.bm do |x|
  types.each do |t|
    tsz = fns.inject(0){|s,fn| File.size(pn+"/tmp/"+fn[0..-4]+t) + s}
    x.report("#{fns.size}x load 512x512 #{t} (#{tsz / 1000}kB)") do
      fns.each do |fn|
        img = Imlib2::Image.load(pn+'/tmp/'+fn[0..-4]+t)
        img.delete!(true)
      end
    end
  end
end
