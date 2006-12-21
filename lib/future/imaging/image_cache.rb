require 'future/base'
require 'fileutils'
require 'imlib2'


module Future


# ImageCache creates and updates the cache images used for drawing zoomable
# views.
#
class ImageCache

  attr_accessor :cache_dir
  attr_reader :cache_image_size, :cache_pyramid_size,
              :max_thumbnail_size, :max_zoom

  def initialize(cache_dir = Future.cache_dir + 'image_cache',
                 cache_image_type = 'png',
                 cache_image_size = 512, max_thumbnail_size = 128)
    cache_pyramid_size = cache_image_size ** 2
    @cache_image_type = cache_image_type
    @cache_image_size = cache_image_size
    @max_thumbnail_size = max_thumbnail_size
    @cache_dir = cache_dir
    @cache_pyramids = []
    @cache_pyramid_size = cache_pyramid_size
    @max_zoom = (Math.log(max_thumbnail_size) / Math.log(2)).to_i
  end

  def thumb_size_at_zoom(zoom)
    2**zoom.to_i
  end

  def regenerate!
    items = DB::Items.count
    (0...items).each{|i| update_cache_at(i) }
  end

  def item_at(index)
    DB::Items.find(:continuous_index => index+1, :columns => [:deleted, :path])
  end

  # Updates the thumbnail stored at index.
  #
  # Loads the thumbnail for the item at index and replaces the current cached
  # version with it.
  # 
  # If the item at index has been deleted, replaces it with a blank area.
  #
  # Indexes start from 0.
  #
  def update_cache_at(index, item = item_at(index))
    if item
      cache_pyramid = cache_pyramid_for(index)
      pyramid_index = (index) % @cache_pyramid_size
      if item.deleted
        cache_pyramid.clear_at(pyramid_index, @batch_ops)
      else
        cache_pyramid.update_at(pyramid_index, item.thumbnail, @batch_ops)
      end
    else
      raise ArgumentError, 'Invalid index, should be a valid continuous_index for item.'
    end
  end

  # Draws cache image at +index+ and zoom level +zoom+ on +image+ at +x+,+y+.
  #
  def draw_image_at(index, zoom, image, x, y)
    cache_pyramid = cache_pyramid_for(index)
    pyramid_index = (index) % @cache_pyramid_size
    cache_pyramid.draw_image_at(pyramid_index, zoom, image, x, y)
  end

  # Retrieves the image cache pyramid for the given index.
  #
  def cache_pyramid_for(index)
    pyramid = index / @cache_pyramid_size
    @cache_pyramids[pyramid] ||= ImageCachePyramid.new(
      @cache_dir, pyramid, @cache_image_type, @cache_image_size, @max_thumbnail_size
    )
  end

  def batch
    if @batch_ops
      yield
    else
      @batch_ops = {}
      yield
      @batch_ops.each do |addr, img|
        img.save
        img.delete!
      end
      @batch_ops = false
    end
  end

end


# ImageCachePyramid provides an interface to draw on multiple resolutions of
# thumbnails with a single call.
#
# For e.g. an #update_at-call, it loads the CacheImage stack for the index,
# then draws on each of the CacheImages.
#
class ImageCachePyramid

  def initialize(cache_dir, toplevel_index, image_type='png', image_size=512, max_thumbnail_size=128)
    @cache_dir = cache_dir
    @toplevel_index = toplevel_index
    @image_type = image_type
    @image_size = image_size
    @pyramid_dir = File.join(@cache_dir, @toplevel_index.to_s)
    @levels = (0..(Math.log(max_thumbnail_size) / Math.log(2)).to_i)
  end

  def image_stack_for(index, batch=nil, levels=@levels)
    levels.map do |lvl|
      image_for(lvl, index, batch)
    end
  end

  def image_for(level, index, batch=nil)
    items_per_image = (@image_size / (1 << level)) ** 2
    wanted_image = index / items_per_image
    batch = {} unless batch
    batch[[@pyramid_dir, level, wanted_image]] ||= CacheImage.new(File.join(@pyramid_dir, level.to_s, wanted_image.to_s), @image_size, 1 << level, @image_type)
  end

  def at(index, batch=nil, levels=@levels)
    image_stack = image_stack_for(index, batch, levels)
    image_stack.each_with_index do |cache_img, i|
      thumb_size = 1 << i
      thumbs_per_cache_img = (@image_size / thumb_size) ** 2
      yield(cache_img, index % thumbs_per_cache_img)
    end
  end

  def update_at(index, image_filename, batch = nil)
    image = Imlib2::Image.load(image_filename)
    at(index, batch) do |cache_img, cache_idx|
      cache_img.draw_at(cache_idx, image)
      unless batch
        cache_img.save
        cache_img.delete!
      end
    end
    image.delete!(true)
  end

  def clear_at(index, batch = nil)
    at(index, batch) do |cache_img, cache_idx|
      cache_img.clear_at(cache_idx)
      unless batch
        cache_img.save
        cache_img.delete!
      end
    end
  end

  def draw_image_at(index, level, image, x, y, batch=nil)
    at(index, batch, [level]) do |cache_img, cache_idx|
      cache_img.draw_image_at(cache_idx, image, x, y)
      cache_img.delete! unless batch
    end
  end

end


class CacheImage

  attr_reader :directory, :image_size, :image, :filename, :thumb_size, :thumbs_per_row

  def initialize(file_prefix, image_size, thumb_size, image_type_suffix = 'png')
    @directory = File.dirname(file_prefix)
    @image_size = image_size
    FileUtils.mkdir_p(@directory)
    @filename = file_prefix + "." + image_type_suffix
    @thumb_size = thumb_size
    @thumbs_per_row = (image_size / thumb_size)
    if File.exist? filename
      @image = Imlib2::Image.load(filename)
    else
      @image = Imlib2::Image.new(image_size, image_size)
      @image.has_alpha = true
      init_ctx
      @image.fill_rectangle([0, 0, image_size, image_size])
    end
  end

  def init_ctx
    ctx = Imlib2::Context.get
    ctx.blend = false
    ctx.color = Imlib2::Color::TRANSPARENT
    ctx.op = Imlib2::Op::COPY
  end

  def draw_at(idx, img)
    clear_at(idx)
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    larger = [img.width, img.height].max
    iw = (@thumb_size.to_f*img.width / larger).round
    ih = (@thumb_size.to_f*img.height / larger).round
    simg = img.crop_scaled(0,0,img.width,img.height,iw,ih)
    @image.blend!(simg, 0,0, iw,ih, x*thumb_size, y*thumb_size, iw,ih)
    simg.delete!(true)
    @changed = true
  end

  def clear_at(idx)
    init_ctx
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    @image.fill_rectangle([x*thumb_size,y*thumb_size, thumb_size,thumb_size])
    @changed = true
  end

  def draw_image_at(idx, img, ix, iy)
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    sz = thumb_size
    img.blend!(@image, x*sz, y*sz, sz, sz, ix, iy, sz, sz)
  end

  def save
    if @changed
      @image.save @filename
      @changed = false
    end
  end

  def delete!(*a)
    @image.delete!(*a)
  end
  
end


end