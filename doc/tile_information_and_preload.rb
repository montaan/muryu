=begin
Tile info for different zoom levels
-----------------------------------

=end

def item_stats(screen_width=1280, screen_height=1024, tile_sz=256, preload=1)
  tiles_per_w = 2*preload + (screen_width.to_f / tile_sz).ceil
  tiles_per_h = 2*preload + (screen_height.to_f / tile_sz).ceil
  tiles_per_screen = tiles_per_w * tiles_per_h
  screen_size = tiles_per_screen * (tile_sz / 256 * 17)
  puts "#{tiles_per_screen} tiles per #{screen_width}x#{screen_height} screen, " +
  "#{screen_size}kB, " +
  "%.1fs at 2048kbps" % [screen_size / 256.0]
  puts((0..12).map do |z|
    item_sz = 2**z
    items_per_tile = (tile_sz.to_f / item_sz) ** 2
    items_per_screen = tiles_per_screen * items_per_tile
    "#{z}:(#{item_sz}x#{item_sz}) ".ljust(15) +
    "%.3f".%(items_per_tile)[0,5].chomp(".").ljust(6) +
    "items per #{tile_sz}x#{tile_sz} tile,  " +
    "%.3f".%(items_per_screen)[0,7].chomp(".").ljust(8) +
    "items per #{screen_width}x#{screen_height} screen"
  end)
  puts 
end
item_stats(240, 320)
item_stats(480, 360)
item_stats(640, 480)
item_stats(1024, 768)
item_stats(1280, 1024)
item_stats(1600, 1200)
item_stats(1920, 1080)
item_stats(2*1280, 1024)
item_stats(2*1920, 1080)

=begin

1280x1024 screen contains 42 tiles, including border cache.

0:(1x1)        65536 items per tile,  2.8M items per 1280x1024 screen
1:(2x2)        16384 items per tile,  688k items per 1280x1024 screen
2:(4x4)        4096  items per tile,  172k items per 1280x1024 screen
3:(8x8)        1024  items per tile,  43k  items per 1280x1024 screen
4:(16x16)      256   items per tile,  11k  items per 1280x1024 screen
5:(32x32)      64    items per tile,  2.7k items per 1280x1024 screen
6:(64x64)      16    items per tile,  672  items per 1280x1024 screen
7:(128x128)    4     items per tile,  168  items per 1280x1024 screen
8:(256x256)    1     items per tile,  42   items per 1280x1024 screen
9:(512x512)    0.25  items per tile,  11   items per 1280x1024 screen
10:(1024x1024) 0.063 items per tile,  2.6  items per 1280x1024 screen
11:(2048x2048) 0.016 items per tile,  0.66 items per 1280x1024 screen
12:(4096x4096) 0.004 items per tile,  0.16 items per 1280x1024 screen

Info per item assuming compression factor of 2.
Tile info per screen ~400kB, 200kB compressed.


One possible way to allocate the information
--------------------------------------------

0:1x1 2.8M items, 1.2 bits per item
  server-side:
    - colors
    - high-level patterns a must
  client-side:
    - not doable to have per-item details
    - color fields drawable with canvas (may be hard to implement gradient mesh
      though?)
    - can draw borders around wanted areas and put a piece of text there
    - websom-style drawing should be doable

1:2x2 688k items, 5 bits per item
  - ditto for above

2:4x4 172k items, 2 bytes per item
  - tile-relative item coordinates for querying item data from tile_info

3:8x8 43k items, 10 bytes per item, +8 bytes
  + rating, item type, set memberships?

4:16x16 11k items, 40 bytes per item, +30 bytes
  + user, dimensions, ref

5:32x32 2.7k items, 160 bytes per item, +120 bytes
  + related items, date, size

6:64x64 672 items, 640 bytes per item, +480 bytes
  + src, tags, top comments

7:128x128 168 items, 2.5kB per item, +1.9kB
  + all comments, all metadata, top related items data

8:256x256 42 items, 10kB per item, +7.5kB
  + more related items data, editor data

9:512x512 11 items, 40kB per item, +30kB
  + metadata revisions, more related items data, location map

10:1024x1024 8 items, 50kB per item, +10kB
  + more related items

11:2048x2048 4 items, 100kB per item, +50kB
  + related items of top related items :?

12:4096x4096 4 items, 100kB per item
  - no change


Utility of information, or answer to "1.2 bits per item seems very useless"
---------------------------------------------------------------------------

information_utility = amount_of_information * quality_of_information

Information utility measures the capability of making an informed decision based
on the given information. As such, it isn't concerned about information per
item, but rather the total information per screen; 1.2 bits per item is very
little information per item, but if you have 2 million items, the information
contained in the screen is 2.4 million bits.


quality_of_information = q(presentation, (information & needed_information))

Quality of information is a function of how well the information is presented
and how the presented information matches the needed information.


presentation = presentation_quality * (presentation_style & viewer_capabilities)

How well information is presented depends on the quality of the presentation
(graphics used, text used, typography, etc.) and how well the presentation
matches the capabilities of the viewer (slideshow to a blind person vs.
pseudo-code to a programmer.)


Tile image size and screen size
-------------------------------

Tile image size 12kB would give 42*12kB = 504kB in images, for a total screen
size of 700kB.

With a 2Mbps internet connection, a screen would take 3.5 seconds to load,
with the first tile shown after ~50ms. On a mobile phone, the screen will be
a lot smaller, meaning around 12 tiles and 172kB per 240x320 screen. With a
384kbps 3G connection, loading the screen would take 3.6 seconds, with the
first tile shown after 0.3 seconds. With a 64kbps connection (~EDGE) loading
the screen would take 21.5 seconds, with the first tile loaded at 1.9 seconds
(+ 2 seconds of latency). With 32kBps GPRS, screen: 43s, first tile 3.8s.


Tile preloading strategy
------------------------

Assuming an usage pattern of quick zoom to medium & near overview, then
pan to seek out interesting things, zoom in to far detail for more browsing -
in essence panning as function of zoom, with more panning when zoomed near -
it'd make sense to do less pan preload when zoomed out and instead prioritize
preloading a couple zoom levels of tiles under the cursor. When zoomed in, the
preload would prioritize panning, with zoom level preload taking a lower
priority.

=end