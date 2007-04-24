require 'future/base'
require 'thread'
require 'imlib2'


module Future


# ImageCache creates and updates the cache images used for drawing zoomable
# views.
#
class ImageCache

  attr_accessor :cache_dir
  attr_reader :cache_image_size, :cache_pyramid_size,
              :max_thumbnail_size, :max_zoom, :raw_pyramid

  def initialize(cache_dir = Future.cache_dir + 'image_cache',
                 cache_image_type = 'tga',
                 cache_image_size = 512, max_thumbnail_size = 128)
    cache_pyramid_size = cache_image_size ** 2
    @cache_image_type = cache_image_type
    @cache_image_size = cache_image_size
    @max_thumbnail_size = max_thumbnail_size
    @cache_dir = cache_dir
    @cache_pyramids = []
    @cache_pyramid_size = cache_pyramid_size
    @max_zoom = (Math.log(max_thumbnail_size) / Math.log(2)).to_i
    @raw_pyramid = RawPyramid.new(@cache_dir, 2**27, @max_zoom)
    @use_raw = true
    @batch_ops = nil
  end

  def thumb_size_at_zoom(zoom)
    2**zoom.to_i
  end

  def regenerate!
    items = Items.count
    (0..items / 100).each do |batch_idx|
      batch do
        Items.find_all(:order_by => [['image_index', :asc]],
                   :columns => [:deleted, :path],
                   :offset => batch_idx*100, :limit => 100).each{|i|
          update_cache_at(i.image_index, i)
        }
      end
    end
  end

  def item_at(index)
    Items.find('image_index' => index, :columns => [:deleted, :path])
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
      if @use_raw
        if item.deleted
          @raw_pyramid.clear_at(index)
        else
          @raw_pyramid.update_cache_at(index, mipmap(item))
        end
      else
        cache_pyramid = cache_pyramid_for(index)
        pyramid_index = (index) % @cache_pyramid_size
        if item.deleted
          cache_pyramid.clear_at(pyramid_index, @batch_ops)
        else
          cache_pyramid.update_at(pyramid_index, item.thumbnail, @batch_ops)
        end
      end
    else
      raise ArgumentError, 'Invalid index, should be a valid continuous_index for item.'
    end
  end

  def init_ctx
    ctx = Imlib2::Context.get
    ctx.blend = false
    ctx.color = Imlib2::Color::TRANSPARENT
    ctx.op = Imlib2::Op::COPY
  end
  
  def mipmap(item)
    @@cache_draw_mutex.synchronize do
      if item.deleted
        thumb = Imlib2::Image.new(2**@max_zoom, 2**@max_zoom)
        thumb.has_alpha = true
        init_ctx
        thumb.fill_rectangle(0,0,2**@max_zoom, 2**@max_zoom,
                             Imlib2::Color::TRANSPARENT)
      else
        thumb = Imlib2::Image.load(item.thumbnail)
        init_ctx
      end
      larger = [thumb.width, thumb.height].max
      iw = thumb.width / larger.to_f
      ih = thumb.height / larger.to_f
      if thumb.width != thumb.height
        othumb = thumb
        thumb = Imlib2::Image.new(2**@max_zoom, 2**@max_zoom)
        thumb.has_alpha = true
        init_ctx
        thumb.fill_rectangle(0,0,2**@max_zoom, 2**@max_zoom,
                             Imlib2::Color::TRANSPARENT)
        thumb.blend!(othumb, 0, 0, othumb.width, othumb.height,
                             0, 0, 2**@max_zoom*iw, 2**@max_zoom*ih)
        othumb.delete!
      end
      levels = (0..@max_zoom).to_a.reverse.map{|i|
        image = Imlib2::Image.new(2**i, 2**i)
        image.has_alpha = true
        image.fill_rectangle(0,0, 2**i, 2**i, Imlib2::Color::TRANSPARENT)
        image.blend!(thumb, 0, 0, thumb.width, thumb.height,
                            0, 0, 2**i, 2**i)
        px = image.data
        image.delete!
        px
      }.reverse
      thumb.delete!
      levels
    end
  end

  @@cache_draw_mutex = Mutex.new

  # Draws cache image at +index+ and zoom level +zoom+ on +image+ at +x+,+y+.
  #
  def draw_image_at(index, zoom, image, x, y)
    if zoom > @max_zoom
      item = Items.find(:image_index => index)
      if zoom == 8
        @@cache_draw_mutex.synchronize do
          t = Imlib2::Image.load(item.thumbnail.to_s)
          image.blend!(t, 0,0,t.width,t.height, x,y,t.width,t.height)
          t.delete!
        end
      else
        ### FIXME Make this a _lot_ faster. Keep original image cached so 
        ###       that there's no need to rescale every time. Do scaling on GPU.
        ###       Cache created tiles.
        pn = Pathname.new(item.internal_path)
        tn = Future.cache_dir + "tmpthumb-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.tga"
        w = 2**zoom
        @@cache_draw_mutex.synchronize do
          pn.thumbnail(tn, w, 0, "#{image.width}x#{image.height}+#{-[0, x].min}+#{-[0, y].min}")
          return unless tn.exist?
          x = 0 if x < 0
          y = 0 if y < 0
          begin
            t = Imlib2::Image.load(tn.to_s)
            image.blend!(t, 0,0,t.width,t.height, x,y,t.width,t.height)
          rescue Exception => e
            STDERR.puts e
          ensure
            t.delete!
            tn.unlink
          end
        end
      end
    elsif @use_raw
      img = @raw_pyramid.read_images_as_imlib(zoom, [index])[0]
      image.blend!(img, 0, 0, img.width, img.height,
                        x, y, img.width, img.height)
      img.delete!
    else
      cache_pyramid = cache_pyramid_for(index)
      pyramid_index = (index) % @cache_pyramid_size
      cache_pyramid.draw_image_at(pyramid_index, zoom, image, x, y, @batch_ops)
    end
  end

  def read_image_at(index, z)
    if @use_raw
      read_images_as_string(z, [index])
    else
      cache_pyramid = cache_pyramid_for(index)
      pyramid_index = (index) % @cache_pyramid_size
      cache_pyramid.read_image_at(pyramid_index, z)
    end
  end

  def read_images_as_string(z, indexes)
    @raw_pyramid.read_images_as_string(z, indexes)
  end

  def read_span_as_string(z, start, length)
    @raw_pyramid.read_span_as_string(z, start, length)
  end

  # Retrieves the image cache pyramid for the given index.
  #
  def cache_pyramid_for(index)
    pyramid = index / @cache_pyramid_size
    @cache_pyramids[pyramid] ||= ImageCachePyramid.new(
      @cache_dir, pyramid, @cache_image_type,
      @cache_image_size, @max_thumbnail_size
    )
  end

  # Executes editing ops in batch, saving edited images only after
  # processing everything. 
  # 
  # Watch out for excessive memory usage when doing batches.
  # 
  def batch
    if @batch_ops
      yield
    else
      batch_start
      yield
      batch_end
    end
  end

  def batch_start
    batch_end
    @batch_ops = {}
  end

  def batch_end
    if @batch_ops
      @batch_ops.each do |addr, img|
        img.save
        img.delete!
      end
      @batch_ops = false
    end
  end

end


# RawPyramid is a simpler and faster replacement for ImageCachePyramid.
# RawPyramid deals in flat files with images saved as raw BGRA data.
#
# #update_cache_at is used for writing images.
#
# #read_images_as_string is used for building OpenGL textures.
#
# #read_span_as_string is used for slurping a range of thumbs into cache.
#
class RawPyramid

  def initialize(cache_dir, cachefile_size=2**24, top_level=7)
    @cache_dir = cache_dir
    @cachefile_size = cachefile_size
    @levels = (0..top_level)
    @parallel_reads = 8
    @indexes_per_level = @levels.map{|lvl| @cachefile_size / (2**(2*lvl) * 4) }
  end

  def update_cache_at(index, data_levels)
    @levels.each{|lvl|
      next unless data_levels[lvl]
      open_at(lvl, index, 'rb+'){|f|
        f.write(data_levels[lvl])
      }
    }
  end

  def clear_at(index)
    @levels.each{|lvl|
      open_at(lvl, index, 'rb+'){|f|
        f.write("\000"*(2**(2*lvl) * 4))
      }
    }
  end

  def open_at(level, index, mode)
    ipl = @indexes_per_level[level].to_i
    level_idx = (index / ipl).to_i
    dirname = File.join(@cache_dir, level.to_s, (level_idx / 1000).to_s)
    FileUtils.mkdir_p(dirname)
    filename = File.join(dirname, level_idx.to_s)
    unless File.exist?(filename)
      File.open(filename, 'wb'){|f|
        f.truncate(@cachefile_size)
      }
    end
    File.open(filename, mode){|f|
      f.seek((index % ipl) * 2**(2*level) * 4)
      yield(f)
    }
  end

  def read_span_as_string(level, start, last)
    sz = 2**(2*level) * 4
    if start == last
      return open_at(level, start, 'rb'){|f| f.read(sz) }
    elsif start > last
      return ""
    end
    ipl = @indexes_per_level[level].to_i
    level_start_idx = (start / ipl).to_i
    level_end_idx = (last / ipl).to_i
    full_level_files = (level_start_idx+1..level_end_idx-1)
    if full_level_files.begin >= full_level_files.end
      return open_at(level, start, 'rb'){|f| f.read(sz*(last-start+1)) }
    end
    str = ""
    open_at(level, start, 'rb'){|f| str << f.read }
    full_level_files.each{|lf|
      open_at(level, lf * ipl, 'rb'){|f| str << f.read }
    }
    if level_end_idx != level_start_idx
      open_at(level, start+length, 'rb'){|f|
        sz = f.pos+1
        f.rewind
        str << f.read(sz)
      }
    end
    str
  end

  def read_images(level, indexes)
    reads = indexes.zip((0...indexes.size).to_a).sort_by{|a,b| a }
    sz = 2**(2*level) * 4
    stream_limit = 2**18 / sz # reading 262kB / 80MB/s =~ 3ms
    result = indexes.dup
    spans = reads.inject([]){|s, (idx,j)|
      if s.last.nil? or s.last.first.end < idx-stream_limit
        s << [(idx..idx), [[0, j]]]
      else
        r,is = s.last
        s.last[0] = (r.begin..idx)
        is << [idx-r.begin, j]
      end
      s
    }
    spans.each{|span,is|
      puts "reading span #{span}"
      s = read_span_as_string(level, span.begin, span.end)
      is.each{|i,j|
        result[j] = s[i*sz,sz]
      }
    }
#     reads_per_thread = (indexes.size.to_f / @parallel_reads).ceil
#     pids = (0...[@parallel_reads, indexes.size].min).map{|i|
#       rd, wr = IO.pipe
#       preads = reads[i*reads_per_thread, reads_per_thread]
#       pid = fork do
#         rd.close
#         preads.each{|idx, j|
#           wr.write(open_at(level, idx, 'rb'){|f| f.read(sz) })
#         }
#         wr.close
#         exit
#       end
#       wr.close
#       [pid, rd, preads]
#     }
#     pids.each{|pid,rd,preads|
#       preads.each{|idx, j|
#         result[j] = rd.read(sz)
#       }
#       rd.close
#       Process.wait(pid)
#     }
    result
  end

  def read_images_as_string(*args)
    read_images(*args).join
  end

  def read_images_as_imlib(level, indexes)
    read_images(level, indexes).map{|d|
      Imlib2::Image.create_using_data(2**level, 2**level, d)
    }
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
      thumb_size = 1 << levels[i]
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

  def read_image_at(index, level, batch=nil)
    str = nil
    at(index, batch, [level]) do |cache_img, cache_idx|
      str = cache_img.read_image_at(cache_idx)
      cache_img.delete! unless batch
    end
    str
  end

end


class CacheImage

  attr_reader :directory, :image_size, :image, :filename, :thumb_size, :thumbs_per_row

  attr_accessor :key, :total, :count
  
  @@open_images = {}
  @@open_images_mutex = Mutex.new

  def self.new(*a)
    key = a
    @@open_images_mutex.synchronize do
      i = (@@open_images[key] ||= (
        img = allocate
        # expensive to serialize image loads?
        # (may improve performance on one-disk system by serializing reads?)
        img.instance_eval{ initialize(*a) } 
        img.key = key
        [img, 0]
      ))
      i[1] += 1 # increase refcount
      i[0]
    end
  end
  
  def self.release(key)
    @@open_images_mutex.synchronize do 
      i = @@open_images[key]
      return unless i
      if (i[1] -= 1) < 1 # decrease refcount, delete image if refcount reaches zero
        @@open_images.delete(key)
        i[0].image.delete!
        #p [i[0].filename, i[0].total, i[0].count, i[0].total/i[0].count] if i[0].count > 0
      end
    end
  end
  
  def initialize(file_prefix, image_size, thumb_size, image_type_suffix = 'png')
    @mutex = Mutex.new
    @total = 0
    @count = 0
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
    @changed = nil
  end

  def init_ctx
    ctx = Imlib2::Context.get
    ctx.blend = false
    ctx.color = Imlib2::Color::TRANSPARENT
    ctx.op = Imlib2::Op::COPY
  end

  def draw_at(idx, img)
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    larger = [img.width, img.height].max
    iw = (@thumb_size.to_f*img.width / larger).round
    ih = (@thumb_size.to_f*img.height / larger).round
    simg = img.crop_scaled(0,0,img.width,img.height,iw,ih)
    @mutex.synchronize do
      init_ctx
      image.fill_rectangle([x*thumb_size,y*thumb_size, thumb_size,thumb_size])
      image.blend!(simg, 0,0, iw,ih, x*thumb_size, y*thumb_size, iw,ih)
      @changed = true
    end
    simg.delete!(true)
  end
  
  def clear_at(idx)
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    @mutex.synchronize do
      init_ctx
      image.fill_rectangle([x*thumb_size,y*thumb_size, thumb_size,thumb_size])
      @changed = true
    end
  end

  def draw_image_at(idx, img, ix, iy)
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    sz = thumb_size
    @mutex.synchronize do
      #t = Time.now.to_f
      Imlib2::Context.get.blend = true
      img.blend!(image, x*sz, y*sz, sz, sz, ix, iy, sz, sz)
      #@total += Time.now.to_f - t
      #@count += 1
    end
  end

  def read_image_at(idx)
    x = idx % thumbs_per_row
    y = idx / thumbs_per_row
    sz = thumb_size
    @mutex.synchronize do
      #t = Time.now.to_f
      image.crop(x*sz,y*sz,sz,sz).data
      #@total += Time.now.to_f - t
      #@count += 1
    end
  end

  def save
    @mutex.synchronize do
      if @changed
        @image.save @filename
        @changed = false
      end
    end
  end
  
  def delete!(*a)
    @mutex.synchronize do
      self.class.release(key)
    end
  end
  
end


Future.image_cache = ImageCache.new


end
