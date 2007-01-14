=begin
Optimize:
considerations: 256x256 tile = 65kquads max mesh size
                timed drawing 65k items:
                  total time 2395ms
                      - one texture load @ 2ms
                      - one save jpg @ 3ms
                      - 300ms to iterate the layout = slow! (C layouter in ext/ does in 2ms)
                      - 230ms to call Imlib2::Image#blend! = slow!
                      - 1860ms for ImageCache#draw_image_at overhead = SLOW!
                      - (drawing with OpenGL: ~5ms)
                texture load 2ms per tex, texture memory usage 1 meg
                image save 3ms
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
* With texture on disk and no save: 7.4ms to draw and read.
* With texture in system RAM and no save: 5.4ms to draw and read.
* With texture in gfx card RAM and no save: 5ms to draw and read.
* Best-case performance: 12 - 14.4ms, 500 - 600ms for a 42-tile screen.
* ~600MB/s texture bandwidth

512x512 cache image:
* With texture on disk and no save: 8.4ms to draw and read.
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

For expected random tile performance, see below:

=end

def expected_drawing_performance(
  cache_images_needed, cache_hit_ratio = 0.2,
  texture_load_time = 2, texture_upload_time = 1.4,
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
  cache_image_factor = 4, load=2, upload=1.4, cache=0.2, tiles_per_screen = 42)
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

# 256x256
pp(random_drawing_perf_stats(1, 2, 0.4))

[[1048576,
  [[4, 4.0, 21.0, 349.0],
   [16, 15.997, 44.994, 1356.748],
   [64, 63.872, 140.744, 5378.248],
   [256, 248.174, 509.348, 20859.616],   # 20 seconds
   [1024, 647.649, 1308.298, 54415.516], # 54 seconds
   [4096, 255.999, 524.998, 21516.916]]],
 [16777216,
  [[4, 4.0, 21.0, 349.0],
   [16, 16.0, 45.0, 1357.0],
   [64, 63.99, 140.98, 5388.16],
   [256, 255.523, 524.046, 21476.932],
   [1024, 992.621, 1998.242, 83393.164],
   [4096, 2589.687, 5192.374, 217546.708]]],
 [67108864,
  [[4, 4.0, 21.0, 349.0],
   [16, 16.0, 45.0, 1357.0],
   [64, 63.999, 140.998, 5388.916],
   [256, 255.882, 524.764, 21507.088],
   [1024, 1016.15, 2045.3, 85369.6],
   [4096, 3624.145, 7261.29, 304441.18]]],
 [268435456,
  [[4, 4.0, 21.0, 349.0],
   [16, 16.0, 45.0, 1357.0],
   [64, 64.0, 141.0, 5389.0],
   [256, 255.975, 524.95, 21514.9],
   [1024, 1022.002, 2057.004, 85861.168],
   [4096, 3970.333, 7953.666, 333520.972]]]] # 5.5 minutes


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


Original plan:

1. tell image_cache to load images to memory (async per disk)
2. draw an image's part of the layout when the image is loaded (create mesh in C, use OpenGL for drawing)
3. read image from framebuffer to ram and send to browser

image_cache.load_images_at(indexes, zoom) do |image, image_indexes|
  layouter.each(indexes, image_indexes, x, y, sz, w, h, *layouter_args) do |i, ix, iy|
    image.draw_at(i, ix, iy)
  end
end

=end