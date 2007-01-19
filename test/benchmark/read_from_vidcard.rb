require 'rend'
include Rend
m = Cube.new
m.on_frame{
  GL::ReadBuffer(GL::FRONT)
  t1 = Time.now.to_f
  1000.times{
    data = GL::ReadPixels(
            0,0, Rend.width, Rend.height,
            Rend::Renderer::NATIVE_TEXTURE_FORMAT, GL::UNSIGNED_BYTE)
  }
  elapsed = Time.now.to_f - t1
  puts "#{(elapsed * 1000).to_i}ms to read 1e9 bytes of data (#{(1000.0 / elapsed).to_i}MB/s)"
  GL::ReadBuffer(GL::BACK)
}

Rend.init(:width => 1000, :height => 250)
Rend.scene << m 
Rend.thread.join
