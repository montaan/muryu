=begin
Optimize:
considerations: 256x256 tile = 65kquads max mesh size
                timed drawing 65k items:
                  total time 2395ms
                      - one texture load @ 12ms
                      - one save jpg @ 20ms
                      - 300ms to iterate the layout = slow! (C layouter in ext/ does in 2ms)
                      - 230ms to call Imlib2::Image#blend! = slow!
                      - 1860ms for ImageCache#draw_image_at overhead = SLOW!
                      - (drawing with OpenGL: ~20ms)
                texture load 12ms per tex, texture memory usage 1 meg
                image save 20ms
1Mitems =>
  4x     1x1     cache images   4MB, 65536 images per tile, max 4   cache images per tile = 8ms   (131 072ms @ 256Mitems)
  16x    2x2     cache images  16MB, 16384 images per tile, max 16  cache images per tile = 32ms  ( 32 768ms @ 64Mitems )
  64x    4x4     cache images  64MB, 4096  images per tile, max 64  cache images per tile = 128ms (  8 192ms @ 16Mitems )
  256x   8x8     cache images 256MB, 1024  images per tile, max 256 cache images per tile = 512ms (  2 048ms @ 4Mitems  )
  1024x  16x16   cache images   1GB, 256   images per tile, max 256 cache images per tile = 512ms
  4096x  32x32   cache images   4GB, 64    images per tile, max 64  cache images per tile = 128ms
  16384x 64x64   cache images  16GB, 16    images per tile, max 16  cache images per tile = 32ms
  65536x 128x128 cache images  64GB, 4     images per tile, max 4   cache images per tile = 8ms
=> worst case: 256 cache images needed for drawing a tile == 512ms to load textures & 256MB mem use == not too bad

Worst case probability:
  pick images_per_tile images from all images so that all image_index / images_per_cache_image are different
  "there are images socks in a box, images_per_cache_image of each color, what is the probability of picking images_per_tile
    differently colored socks from the box?"

=end

def worst_case(images_per_tile, images, images_per_cache_image)
  (1...images_per_tile).inject(1){|s,i| s *
     ((images-i*images_per_cache_image.to_f)/(images-i)) }
end

=begin

P(worst case) is not very relevant, since other cases nearly as bad are
much more likely anyway.

1Mitems:
  128x128 => 0.9999 => 8ms
  64x64   => 0.9928 => 32ms
  32x32   => 0.6109 => 128ms (4GB textures in total, doable to keep in RAM)
  16x16   => 7.07e-16 worst case, but still ~460ms expected unless kept
                                  in RAM (VERY doable <= 1GB)

  Total textures: 85 GB (25.5e @ 0.3e / GB of hard disk space)

16Mitems:
  128x128 => 0.9999 (1TB textures)
  64x64   => 0.9995 (256GB textures)
  32x32   => 0.9698 (64GB textures)
  16x16   => 0.1352 => 512ms
  8x8     => 1.48e-61

  Total textures: 1365 GB (409e)

64Mitems:
  32x32   => 0.9924 (256GB textures)
  16x16   => 0.6076 (64GB textures)

  Total textures: 5461 GB (1638e)

256Mitems:
  16x16   => 0.8830 (256GB textures)

  Total textures: 21845 GB (6552e)


Random tiles are expensive, should optimize cache image layout for oft-used
sortings. Now they're by date and all users in same cache, which is good for
forum-style posting.
For private sets, it'd make sense to have a user-wise set of cache images.

The problem is projecting an n-dimensional space to a single dimension in a way
that preserves locality (impossible in the general case?)
Could store copies of the cache sorted in different ways, maybe use that for
storage redundancy?
=end

require 'pp'

def simulate_random_tiles(cache_image_factor = 4)
  [2**20,2**24,2**26,2**28].map do |images|
    [ images,
      [4,16,64,256,1024,4096].map do |images_per_tile|
        cache_tiles = images / (images_per_tile * cache_image_factor)
        arr = Hash.new(0)
        1000.times do
          h = Hash.new(0)
          images_per_tile.times { h[(rand*cache_tiles).to_i] += 1 }
          arr[h.keys.size] += 1
        end
    #   total = 1.0 * arr.inject(0){|s,(k,v)| s+v}
    #   thres = 1.0
    #   arr.sort_by{|k,v| k}.inject(0) do |s,(k,v)|
    #     s1 = s + v / total
    #     if s1 >= thres / 10
    #       thres += 1
    #       puts "%04.1f%% %d" % [s1 * 100, k]
    #     end
    #     s1
    #   end
    #   puts
        [ images_per_tile,
          arr.inject(0){|s,(k,v)| s + k*v } /
          arr.inject(0){|s,(k,v)| s+v }.to_f
        ]
      end
    ]
  end
end

=begin
sims = simulate_random_tiles
pp sims

[[1048576,
  [[4, 4.0],        # 128x128
    [16, 15.993],    # 64x64
    [64, 63.511],    # 32x32
    [256, 226.655],  # 16x16
    [1024, 251.435], # 8x8
    [4096, 64.0]]],  # 4x4
  [16777216,
  [[4, 4.0],
    [16, 15.999],
    [64, 63.965],
    [256, 253.979],
    [1024, 905.779],
    [4096, 1005.274]]],
  [67108864,
  [[4, 4.0],
    [16, 15.999],
    [64, 63.994],
    [256, 255.535],
    [1024, 992.65],
    [4096, 2588.624]]],
  [268435456,
  [[4, 4.0],
    [16, 16.0],
    [64, 63.998],
    [256, 255.859],
    [1024, 1016.046],
    [4096, 3623.971]]]]

Not only is the expected number of cache images per tile close to the
worst case, but the distribution is such that very few tiles will need
comparatively few cache images:

1048576 images
256 images per tile (16x16)
10.1% 220      <- only 10% under 220 cache images per tile
24.6% 223      in another run, only 1.7% under 216...
31.4% 224
48.0% 226
56.5% 227
63.0% 228
72.6% 229
80.3% 230
91.2% 232
100.0% 241



Drawing a 256x256 tile of 1x1px items using OpenGL
--------------------------------------------------

Layout in C takes 3ms.
Saving as JPG takes 4ms.
Best case: query results cached, tile needs only one cache image.

256x256 cache image:
* With texture in system RAM and no save: 5.4ms to draw and read.
* With texture in gfx card RAM and no save: 5ms to draw and read.
* Best-case performance: 12 - 14.4ms, 500 - 600ms for a 42-tile screen.
* ~600MB/s texture bandwidth

512x512 cache image:
* With texture in system RAM and no save: 6.4ms to draw and read.
* With texture in gfx card RAM and no save: 5ms to draw and read.
* Best-case performance: 12 - 15.3ms, 500 - 640ms for a 42-tile screen.

Smaller cache images improve worst-case performance, but make it more probable.
* If a cache image stores only one item image, drawing will exhibit worst-case
  performance every time, but disk and graphics card bandwidth use will be
  optimal (but requires uploading more textures and more meshes to the card)
  - reduces amount of data to move at the price of multiplying random access
    latency
* If a cache image stores all item images, drawing will exhibit best-case
  performance every time, but best-case performance will be equal to worst-case
  performance, and memory used will be equal to cache image size
  - reduces random access latency at the price of memory & bandwidth

Guessing: cache hit ratio is equal between different cache image sizes, or
somewhat better for smaller cache images. Smaller images give finer
granularity, which should help in minimizing unwanted data in the cached set.
(Memory used for the cache is equal, so e.g. for each 512x512 cache image, you
can have four 256x256 cache images.)

Timed disk reads by creating a 16GB file and reading blocks at random positions.
1000x 1B    reads: 10.3s -> 10ms / read,   100Bps throughput
1000x 64B   reads: 12.9s -> 13ms / read,  5.0kBps throughput (4x4)
1000x 2^10B reads: 13.1s -> 13ms / read,   79kBps throughput (16x16)
1000x 2^12B reads: 14.0s -> 14ms / read,  293kBps throughput (32x32)
1000x 2^14B reads: 16.0s -> 16ms / read,  1.0MBps throughput (64x64)
1000x 2^16B reads: 18.2s -> 18ms / read,  3.6MBps throughput (128x128)
1000x 2^18B reads: 24.0s -> 24ms / read, 10.9MBps throughput (256x256)
1000x 1MB   reads: 32.5s -> 33ms / read, 30.8MBps throughput (512x512)
1000x 4MB   reads: 90.3s -> 90ms / read, 44.3MBps throughput (1024x1024)
1000x 2^24B reads: 327s -> 327ms / read, 51.3MBps throughput (2048x2048)
100x 2^26B reads: 126s -> 1260ms / read, 53.3MBps throughput (4096x4096)
For expected random tile performance, see below:

=end

def create_file(fn, size=16_000_000_000)
  system("head -c #{size} < /dev/zero > #{fn.dump}")
end

def random_reads(filename, read_size, count=1000)
  File.open(filename, 'rb'){|f|
    sz = f.stat.size
    count.times{ f.seek((rand*sz).to_i); f.read(read_size) }
  }
end

def expected_drawing_performance(
  cache_images_needed, cache_hit_ratio = 0.2,
  texture_load_time = 33, texture_upload_time = 1.4,
  layout = 3, drawing = 5, save_as_jpg = 4,
  query = 1 # 40ms amortized over 40 tiles
)
  texture_from_disk_to_gfx_card = texture_load_time + texture_upload_time
  average_texture_upload_time = (
    (1 - cache_hit_ratio) * texture_from_disk_to_gfx_card +
    cache_hit_ratio * texture_upload_time
  )
  query + layout + drawing +
  cache_images_needed * average_texture_upload_time +
  save_as_jpg
end

def random_drawing_perf_stats(
  cache_image_factor = 4, load=33, upload=1.4, cache=0.2, tiles_per_screen = 42)
  simulate_random_tiles(cache_image_factor).map{|amt, sims|
    [amt, sims.map{|items,cache_images|
      [items, cache_images,
       expected_drawing_performance(cache_images, cache, load, upload),
       expected_drawing_performance(cache_images * tiles_per_screen,
         cache, load, upload)
      ]
    }]
  }
end

=begin

Exclamation mark next to best performing cache image size from the three.
Notes: cache hit ratio is equal between the zoom levels, when it should follow
an exponential curve so that most zoomed out has hit ratio of 1 / (r*4^0),
nextmost zoomed out 1 / (r*4^1), etc.

Several disks per machine divides the load time. 6-disk RAID-1 ~> divide time
by 6 by doing 6 parallel loads.

A 1Mitem tile server would have six 100GB SATA disks for the cache, 4
gigs of RAM, run-of-the-mill graphics card and a dualcore proc.
Disks 300e(?), RAM 400e, gfx card 100e, CPU and mobo ~300e, case and PSU 100e
= 1200e. Maybe rather likely to spontaneously combust as well, but such is life
on the cheap~

1Mitem system can run on a single box with 1GB+ RAM. Worst case draw time
there being 950ms per tile, 160ms with a 6-disk setup. Standalone
"Professional Edition."

16Mitem system has worst case performance at 3.7s per tile, which is 0.6s with
6 disks. It's fast, but sluggish. With 16GB of RAM, the worst case becomes as
above. "Enterprise Edition." 1.4TB of disk per cache copy. If you can fit around
0.75TB of 6-redundant disks per box, needs two boxes. Total memory 16GB, so
8GB per box. Disks 1800e, RAM 1600e, total 3500e / box, 7000e in total.

64Mitems with 4GB of RAM has worst case of 14s (2.3s) per tile with 4GB RAM,
3.7s (0.6s) with 16GB of RAM, 950ms (160ms) with 64GB of RAM. 5.5TB of disk per
cache copy. 8 boxes as configured above, 28ke.

# 128x128
pp(random_drawing_perf_stats(0.25, 18, 0.2))
[[1048576,
  [[4, 4.0, 71.4, 2465.8],                      # 2s    ! 64GB
   [16, 16.0, 246.6, 9824.2],                   # 10s   ! 16GB
   [64, 63.97, 946.962, 39239.404],             # 39s   ! 4GB <- good speed
   [256, 254.017, 3721.6482, 155776.2244],      # 2m36s ! 1GB <- ok speed
   [1024, 905.843, 13238.3078, 555475.9276],    # 9m15s
   [4096, 1005.288, 14690.2048, 616455.6016]]], # 10m16s
 [16777216,
  [[4, 4.0, 71.4, 2465.8],                       ! 1TB
   [16, 16.0, 246.6, 9824.2],                    ! 256GB
   [64, 63.998, 947.3708, 39256.5736],           ! 64GB
   [256, 255.881, 3748.8626, 156919.2292],       ! 16GB <- ok speed
   [1024, 1015.94, 14845.724, 622987.408],       ! 4GB
   [4096, 3624.656, 52932.9776, 2222652.0592]]],   1GB
 [67108864,
  [[4, 4.0, 71.4, 2465.8],                       ! 4TB   HD (total 4TB) -> 72ms
   [16, 16.0, 246.6, 9824.2],                    ! 1TB   Flash (total 1.3TB) -> 17ms (2+15ms)
   [64, 63.999, 947.3854, 39257.1868],           ! 256GB Flash -> 22ms
   [256, 255.966, 3750.1036, 156971.3512],       ! 64GB  RAM (total 86GB)-> ~0ms
   [1024, 1022.016, 14934.4336, 626713.2112],    ! 16GB  RAM -> ~0ms
   [4096, 3970.456, 57981.6576, 2434696.6192]]], ! 4GB   RAM -> ~0ms
 [268435456,
  [[4, 4.0, 71.4, 2465.8],                       ! 16TB
   [16, 16.0, 246.6, 9824.2],                    ! 4TB
   [64, 64.0, 947.4, 39257.8],                   ! 1TB
   [256, 255.99, 3750.454, 156986.068],          ! 256GB <- ok speed
   [1024, 1023.539, 14956.6694, 627647.1148],    # 10m27s ! 64GB
   [4096, 4064.374, 59352.8604, 2492287.1368]]]] # 41m32s ! 16GB


# 256x256
pp(random_drawing_perf_stats(1, 24, 0.4))
[[1048576,
  [[4, 4.0, 91.4, 3305.8],                   # 3s
   [16, 16.0, 326.6, 13184.2],               # 13s
   [64, 63.85, 1264.46, 52574.32],           # 53s
   [256, 248.073, 4875.2308, 204226.6936],   # 3m24s
   [1024, 646.748, 12689.2608, 532415.9536], # 8m52s
   [4096, 256.0, 5030.6, 210752.2]]],        # 3m31s
 [16777216,
  [[4, 4.0, 91.4, 3305.8],
   [16, 16.0, 326.6, 13184.2],
   [64, 63.995, 1267.302, 52693.684],
   [256, 255.51, 5020.996, 210348.832],
   [1024, 992.618, 19468.3128, 817136.1376],
   [4096, 2589.396, 50765.1616, 2131603.7872]]], # 35m31s
 [67108864,
  [[4, 4.0, 91.4, 3305.8],
   [16, 16.0, 326.6, 13184.2],
   [64, 64.0, 1267.4, 52697.8],
   [256, 255.88, 5028.248, 210653.416],
   [1024, 1016.005, 19926.698, 836388.316],
   [4096, 3624.585, 71054.866, 2983771.372]]], # 49m43s
 [268435456,
  [[4, 4.0, 91.4, 3305.8],
   [16, 16.0, 326.6, 13184.2],
   [64, 63.999, 1267.3804, 52696.9768],
   [256, 255.959, 5029.7964, 210718.4488],
   [1024, 1022.013, 20044.4548, 841334.1016],
   [4096, 3970.767, 77840.0332, 3268748.3944]]]] # 54m28s


# 512x512
pp(random_drawing_perf_stats)
[[1048576,
  [[4, 4.0, 119.16, 4471.72],                 # 4s
   [16, 15.996, 437.53384, 17843.42128],      # 18s
   [64, 63.565, 1700.0151, 70867.6342],       # 1m11s
   [256, 226.545, 6025.5043, 252538.1806],    # 4m12s
   [1024, 251.284, 6682.07736, 280114.24912], # 4m40s
   [4096, 64.0, 1711.56, 71352.52]]],         # 1m11s
 [16777216,
  [[4, 4.0, 119.16, 4471.72],
   [16, 16.0, 437.64, 17847.88],
   [64, 63.975, 1710.8965, 71324.653],
   [256, 254.045, 6755.3543, 283191.8806],
   [1024, 906.168, 24062.69872, 1010100.34624],
   [4096, 1005.142, 26689.46868, 1120424.68456]]], # 18m40s
 [67108864,
  [[4, 4.0, 119.16, 4471.72],
   [16, 16.0, 437.64, 17847.88],
   [64, 63.991, 1711.32114, 71342.48788],
   [256, 255.493, 6793.78422, 284805.93724],
   [1024, 992.717, 26359.70918, 1106574.78556],
   [4096, 2589.082, 68727.23628, 2886010.92376]]], # 48m6s
 [268435456,
  [[4, 4.0, 119.16, 4471.72],
   [16, 16.0, 437.64, 17847.88],
   [64, 63.995, 1711.4273, 71346.9466],
   [256, 255.882, 6804.10828, 285239.54776],
   [1024, 1015.972, 26976.89688, 1132496.66896],
   [4096, 3625.307, 96228.64778, 4041070.20676]]]] # 67m21s

# 1024x1024, only the best performing variants
pp(random_drawing_perf_stats(16, 90, 6))
[[1048576,
  [[1024, 64.0, 5005.0, 209677.0],
   [4096, 16.0, 1261.0, 52429.0]]],
 [16777216,
  [[4096, 256.0, 19981.0, 838669.0]]],

# 2048x2048, only the best performing variants
pp(random_drawing_perf_stats(64, 327, 24))
[[1048576,
  [[1024, 16.0, 4582.6, 191936.2],
   [4096, 4.0, 1155.4, 47993.8]]],
 [16777216,
   [4096, 64.0, 18291.4, 767705.8]]],


# 4096x4096, only the best performing variants
pp(random_drawing_perf_stats(256, 1260, 96))
[[1048576,
   [1024, 4.0, 4429.0, 185485.0],         !
   [4096, 1.0, 1117.0, 46381.0]]],        !
 [16777216,
   [4096, 16.0, 17677.0, 741901.0]]],     !


For random tiles, fast disk seeks trump throughput -> small cache images
consistently yield best performance by optimizing the worst case.

Large cache images win when less of them are needed to fit the whole item set
than there are items per tile (again, optimizing the worst case.)

For a 1Mitem system tasked with drawing random tiles, it would be auspicious
to use a 1:1 (1 cache image per item (128x128, 64x64, 32x32, 16x16)) cache
setup for the first four zoom levels and 4096x4096 above that.

For a 16Mitem system, 1:1 for four closest zoom levels, 16x16 for fifth?,
4096x4096 above that.

For bigger systems, 1:1 cache images for at least the four closest zoom levels,
16x16 above that?

Upload times become significant when the amount of textures grows.
Uploading 4000 textures to the graphics card at 0.2ms a piece = 0.2s in total.
It may(?) be faster to concat the textures on the CPU and then magicks but no
idea, would need to benchmark.

Complete hypothesis, but, maybe the image cache could be a huge file per
zoomlevel? Then cut out the wanted bits using fseek.


Parallelism
-----------

Another thing that helps is that tile drawing is embarrassingly parallel.

With 256Mitems and 4x4 random tile: required 3600 texture loads = 7.2s on a single computer.

Split across 120 nodes and you have 30 texture loads per node = 60ms.
If you have a 500MB/s (10Gbps) effective downstream to the composing node, it becomes
0.5ms to get one composed tile part (256x256x4 bytes) from the network, so 60ms for 120,
for a total draw time of 120ms.

With a 100MB/s (1Gbps) network, transferring a composed tile takes 5ms.
Introduce two levels of aggregation nodes, 120 -> 30 -> 6 -> 1 ?
Draw is 60ms, first aggregation is 4 per aggregator: 20ms, second aggregation is 5 per
aggregator: 25ms, third aggregation is 6 per aggregator: 30ms, for a total of 135ms.

(Aggregation with a 10Gbps network: 480 -> 48 -> 4 -> 1, 15ms + 5ms + 6ms + 2ms = 28ms,
  3600 -> 900 -> 225 -> 56 -> 14 -> 4 -> 1 = 2ms + 6*2ms = 14ms)

Optimal branching factor for an aggregation network is e,
=end
def optimal_aggregation
  [2, Math::E, 3, 4].map{|i| i * (Math.log(1000)/Math.log(i)) }
end
=begin
  optimal_aggregation
  => [19.9315685693242, 18.7772256502992, 18.8631294686045, 19.9315685693242]
(Think of it as a tree, where you're traversing towards the leaves in parallel, each
  level traversal taking branching_factor milliseconds. 2-brancher would get you 8 leaves in 6ms.
  3-brancher would get you 9 leaves in 6ms. 6-brancher would get you 6 leaves in 6ms.)

By having the aggregation nodes also do drawing, you can save 37 transfers out of 157.
These are first-level results though, so the effect is equivalent to lowering the first
aggregation time to somewhere around 13ms?

Each aggregation node can also draw more than a normal node due to having to
wait for the network transfer.


Original plan (optimistic about image cache locality):

1. tell image_cache to load images to memory (async per disk)
2. draw an image's part of the layout when the image is loaded (create mesh in C, use OpenGL for drawing)
3. read image from framebuffer to ram and send to browser

image_cache.load_images_at(indexes, zoom) do |image, image_indexes|
  layouter.each(indexes, image_indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
    image.draw_at(i, ix, iy)
  end
end


Revised plan (random access rules the day):

0. cache all zoom level layout meshes on the vidcard as VBOs
1. create layout in C (query spans) and a 512x512 empty texture
2. do db query to get the list of image indexes for the spans (whole screen :?)
3. split image_indexes in disk_count lists of (layout_index,image_index)-tuples,
   so that each list consists of contiguous image_indexes
4. assign each list to a different disk, go through the list doing async reads
5. whenever a read finishes, update the texture by memcpying the image there
6. when all reads are done, upload the texture and draw the layout
7. read image from framebuffer, save as jpeg, send to browser

m = Model.new
geo = Geometry.new
layout_spans, geo.vertices, geo.texcoords = *layout(x, y, sz, 256, 256)
image_indexes = dbquery(layout_spans)
rtex = Texture.new(:width => 512, :height => 512)
m.geometry = geo
m.texture = rtex
cols = 512 / sz
image_indexes.split_in(disks.size).parallel_read(disks) do |layout_idx, data|
  tx = layout_idx % cols
  ty = layout_idx / cols
  GL::TexSubImage2D(tex, 0, tx*sz, ty*sz, sz, sz,
                    GL::RGBA, GL::UNSIGNED_BYTE, data)
end
m.draw
img = Imlib2::Image.create_from_data(256, 256, GL::ReadPixels(0,0,256,256))
img.save("temp.jpg")
res.body = File.read("temp.jpg")

class Array

  def split_in(n)
    sorted_tuples = map_with_index.sort_by{|lidx, iidx| iidx}
    sz = (sorted_tuples / n.to_f).ceil
    (1..n).map{|i| sorted_tuples[i*sz, sz] }
  end

  def parallel_read(paths, read_sz)
    reads = Array.new(paths.size)
    until all?{|q| q.empty? }
      reads.each_with_index do |e,i|
        next if self[i].empty?
        if not e
          req = self[i].shift
          reads[i] = [thread_read(File.join(paths[i], req[1])), req]
        elsif not e[0].alive?
          yield(e[1][0], e[0].value)
          reads[i] = nil
        end
      end
    end
  end

  def thread_read(path)
    Thread.new{ RAMCache[path] || File.read(path) }
  end

end

RAMCache = {}

=end