$cookie = "future_session_id=04f65d64041ff8334ed02d10a1d46e61"

def url(x,y,z,i)
  rx = (z*x + i%5)*256
  ry = (z*y + i/5)*256
  "http://manifold.fhtr.org:2000/tile/x#{rx}y#{ry}z#{z}"
end

def fetch(n, x, y, z, threads=2)
  times = []
  sizes = []
  (0...threads).map do |t|
    Thread.new(t) do
      (n/threads).times{|i|
        t0 = Time.now.to_f
        sizes << `curl -s -b "#{$cookie}" "#{url(x, y, z, t*n/threads+i)}"`.size
        times << Time.now.to_f - t0
      }
    end
  end.each{|t| t.join }
  [sizes, times]
end

def pattern_browse(time=30, zooms=4, lateral_nav=2)
  z = 4
  x = 0
  y = 0
  times = []
  sizes = []
  sleep( rand * 5 )
  t0 = Time.now.to_f
  zooms.times{
    s,t = fetch(40, x, y, z)
    sizes += s
    times += t
    sleep( rand * time / zooms )
    lateral_nav.times{|ln|
      if ln % 2 == 0
        x += (rand-0.5) > 0 ? 1 : -1 
        x = 1 if x < 0
      else
        y += (rand-0.5) > 0 ? 1 : -1
        y = 1 if y < 0
      end
      s,t = fetch(8, x, y, z)
      sizes += s
      times += t
      sleep( rand * time / zooms / lateral_nav )
    }
    z += (rand-(z/8.0)) > 0 ? 1 : -1
  }
  elapsed = Time.now.to_f - t0
  [elapsed, sizes, times]
end

def mass_browse(users=10)
  elapsed = []
  times = []
  sizes = []
  (0...users).map{|u|
    Thread.new{
      e,s,t = pattern_browse
      elapsed << e
      times += t
      sizes += s
    }
  }.map{|t| t.join }
  [elapsed, sizes, times]
end


if __FILE__ == $0
  users = (ARGV.shift || 10).to_i
  e,sz,t = mass_browse(users)
  puts("Sent a total of #{t.size} requests from #{e.size} clients, using #{sz.inject{|s,i| s+i}} bytes of bandwidth.")
  puts("Average tile size: #{sz.inject{|s,i| s+i} / sz.size} bytes")
  puts("Average time to finish browsing: #{e.inject{|s,i| s+i} / e.size}s")
  puts("Average response time: #{t.inject{|s,i| s+i} / t.size}s")
end
