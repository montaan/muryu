require 'future/base'
require 'thread'
require 'imlib2'

$imlib_mutex ||= Mutex.new

module Future


# ImageCache creates and updates the cache images used for drawing zoomable
# views.
#
class ImageCache

  attr_accessor :cache_dir
  attr_reader :max_thumbnail_size, :max_zoom, :raw_pyramid

  def initialize(cache_dir = Future.cache_dir + 'image_cache',
                 max_thumbnail_size = 128)
    @max_thumbnail_size = max_thumbnail_size
    @cache_dir = cache_dir
    @max_zoom = (Math.log(max_thumbnail_size) / Math.log(2)).to_i
    @raw_pyramid = RawPyramid.new(@cache_dir, 2**27, @max_zoom)
    @batch_ops = nil
  end

  def max_index
    if Future.constants.include?("Items")
      item = Items.find(:order_by => [[:image_index, :desc]])
      return 0 unless item
      item.image_index
    else # eh, where's the database?
      @raw_pyramid.max_index
    end
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
      if item.deleted and not item.thumbnail
        @raw_pyramid.clear_at(index)
      else
        @raw_pyramid.update_cache_at(index, mipmap(item))
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
    $imlib_mutex.synchronize do
      if item.deleted and not item.thumbnail
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
        sz = 2**i
        image = Imlib2::Image.new(sz, sz)
        image.has_alpha = true
        image.fill_rectangle(0,0, sz, sz, Imlib2::Color::TRANSPARENT)
        image.blend!(thumb, 0, 0, thumb.width, thumb.height,
                            0, 0, sz, sz)
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
      return unless item.thumbnail
      if zoom == 8
        return unless item.thumbnail and item.thumbnail.exist?
        $imlib_mutex.synchronize do
          t = Imlib2::Image.load(item.thumbnail.to_s)
          image.blend!(t, 0,0,t.width,t.height, x,y,t.width,t.height)
          t.delete!
        end
      else
        ### FIXME Make this a _lot_ faster. Keep original image cached so 
        ###       that there's no need to rescale every time. Do scaling on GPU.
        ###       Cache created tiles.
        pn = Pathname.new(item.internal_path)
        if item.major != 'image'
          pn = item.thumbnail
        end
        return unless pn.exist?
        tn = Future.cache_dir + "tmpthumb-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}.tga"
        w = 2**zoom
        $imlib_mutex.synchronize do
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
    else
      img = @raw_pyramid.read_images_as_imlib(zoom, [index])[0]
      image.blend!(img, 0, 0, img.width, img.height,
                        x, y, img.width, img.height)
      img.delete!
    end
  end

  def read_image_at(index, z)
    read_images_as_string(z, [index])
  end

  def read_images_as_string(z, indexes)
    @raw_pyramid.read_images_as_string(z, indexes)
  end

  def read_span_as_string(z, start, length)
    @raw_pyramid.read_span_as_string(z, start, length)
  end
  
  def read_images_as_jpeg(lvl,indexes)
    d = @raw_pyramid.read_images(lvl,indexes)
    d.inject(""){|s,i|
      j = crop_and_jpeg(i, lvl)
      s << ([j.size].pack("I")) << j
      s
    }
  end
  
  def read_span_as_jpeg(lvl,s,l)
    d = read_span_as_string(lvl,s,l)
    sz24 = 2**(lvl*2)*4
    str = ""
    0.step(d.size-1, sz24){|i|
      bgra = d[i,sz24]
      j = crop_and_jpeg(bgra, lvl)
      str << ([j.size].pack("I")) << j
    }
    str
  end

  def crop_and_jpeg(bgra, lvl)
    sz = 2**lvl
    i = 0
    w = 0
    while i < sz && w < sz
      nw = (bgra[i*sz*4,sz*4].index(/(\000\000\000\000)+\Z/) || (sz * 4)) / 4
      w = nw if nw > w
      i+=1
    end
    raise "BUG in width, #{w} > #{sz}" if w > sz
    if w == 0
      ""
    else
      h = ((bgra.index(/(\000\000\000\000)+\Z/) || sz*sz*4.0) / (sz*4.0)).ceil
      raise "BUG in height, #{h} > #{sz}" if h > sz
      img = nil
      $imlib_mutex.synchronize do
        img = Imlib2::Image.create_using_data(sz, sz, bgra)
        img.has_alpha = (bgra[3,1] == "\000")
        img.crop!(0,0,w,h)
      end
      a = ""
      a << Tiles.imlib_to_gray_jpeg(img, 75) if img.has_alpha?
      rgb = Tiles.imlib_to_jpeg(img, 75)
      [rgb.size].pack("I") << rgb << [a.size].pack("I") << a
    end
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

  def max_index
    dirname = File.join(@cache_dir, @levels.end.to_s)
    maxdir = Dir[dirname + "/*"].map{|n| File.split(n).last.to_i }.max
    maxfile = Dir[File.join(dirname, maxdir.to_s, "*")].map{|n| File.split(n).last.to_i }.max
    maxfile ||= 0
    ipl = @indexes_per_level.last
    ipl * (maxfile+1) - 1
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
      str = open_at(level, start, 'rb'){|f| f.read(sz) }
      if str.size != (last-start+1)*sz
        raise "Bad read! #{str.size} != #{(last-start+1)*sz}"
      end
      return str
    elsif start > last
      raise "Bad read! Start #{start} bigger than last #{last}"
    end
    ipl = @indexes_per_level[level].to_i
    level_start_idx = (start / ipl).to_i
    level_end_idx = (last / ipl).to_i
    full_level_files = (level_start_idx+1..level_end_idx-1)
    str = ""
    open_at(level, start, 'rb'){|f| str << f.read(sz*(last-start+1)) }
    full_level_files.each{|lf|
      open_at(level, lf * ipl, 'rb'){|f| str << f.read }
    }
    if level_end_idx != level_start_idx
      open_at(level, last, 'rb'){|f|
        rsz = f.pos
        f.rewind
        str << f.read(rsz+sz)
      }
    end
    if str.size != (last-start+1)*sz
      raise "Bad read! #{str.size} != #{(last-start+1)*sz}"
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
    total_span_length = spans.inject(0){|s,(sp,r)| s+(sp.end-sp.begin+1) }
    if indexes.size > total_span_length
      raise "Bad spans! #{total_span_length} < #{indexes.size}: #{spans.map{|s,i| s}}"
    end
    spans.each{|span,is|
      log "reading span #{span}"
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


Future.image_cache = ImageCache.new


end
