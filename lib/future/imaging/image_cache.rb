require 'future/base'
require 'future/imaging/utils'
require 'thread'
require 'imlib2'

$imlib_mutex ||= Mutex.new

module Future


# ImageCache creates and updates the cache images used for drawing zoomable
# views.
#
class ImageCache

  attr_accessor :cache_dir, :use_db
  attr_reader :max_thumbnail_size, :max_zoom, :raw_pyramid, :jpeg_pyramid, :jpeg_tiles

  def initialize(cache_dir = Future.cache_dir + 'image_cache',
                 max_thumbnail_size = 128, max_raw_size = 16)
    @max_thumbnail_size = max_thumbnail_size
    @cache_dir = cache_dir
    @max_zoom = (Math.log(max_thumbnail_size) / Math.log(2)).to_i
    @max_raw_zoom = (Math.log(max_raw_size) / Math.log(2)).to_i
    @raw_pyramid = RawPyramid.new(@cache_dir+'raw_pyramid', 2**27, @max_raw_zoom)
    @jpeg_pyramid = JPEGPyramid.new(@cache_dir+'jpeg_pyramid', 2**27, @max_raw_zoom+1, @max_zoom)
    @jpeg_tiles = JPEGTileStore.new(@cache_dir+'jpeg_tiles')
    @batch_ops = nil
    @total_data_read = 0
    @use_db = true
  end

  def max_index
    if @use_db and Future.constants.include?("Items")
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

  def regenerate!(start_idx=0, *a)
    item = Items.find(:order_by => [[:image_index, :desc]])
    max = item.image_index
    return if max < start_idx
    (0 .. (max-start_idx) / 100).each do |batch_idx|
      batch do
        Items.find_all(:order_by => [['image_index', :asc]],
                   :columns => [:deleted, :path],
                   :image_index => [:>=, start_idx],
                   :offset => batch_idx*100, :limit => 100).each{|i|
          puts "updating cache at #{i.image_index}"
          update_cache_at(i.image_index, i, *a)
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
  def update_cache_at(index, item = item_at(index), raw=true, jpeg=true, tiles=true, force=false)
    if item
      if item.deleted and not item.thumbnail
        clear_cache_at(index, raw, jpeg, tiles, force)
      else
        mipmap = mipmap(item, force)
        @raw_pyramid.update_cache_at(index, mipmap.map{|im| im.data_for_reading_only }) if raw
        @jpeg_pyramid.update_cache_at(index, mipmap.map{|im| imlib_to_rgb_alpha_jpeg(im) }) if jpeg
        @jpeg_tiles.update_cache_at(index, item) if tiles
      end
    else
      raise ArgumentError, 'Invalid index, should be a valid image_index for item.'
    end
  end

  def clear_cache_at(index, raw=true, jpeg=true, tiles=true, force=false)
    @raw_pyramid.clear_at(index) if raw
    @jpeg_pyramid.clear_at(index) if jpeg
    @jpeg_tiles.clear_at(index) if tiles
  end

  def init_ctx
    ctx = Imlib2::Context.get
    ctx.blend = false
    ctx.color = Imlib2::Color::TRANSPARENT
    ctx.op = Imlib2::Op::COPY
  end
  
  def mipmap(item, force_update=false)
    $imlib_mutex.synchronize do
      if item.deleted and not item.thumbnail
        thumb = Imlib2::Image.new(2**@max_zoom, 2**@max_zoom)
        thumb.has_alpha = true
        init_ctx
        thumb.fill_rectangle(0,0,2**@max_zoom, 2**@max_zoom,
                             Imlib2::Color::TRANSPARENT)
      else
        item.update_thumbnail(false, force_update) if item.respond_to?(:update_thumbnail)
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
        image
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
      @jpeg_tiles.draw_image_at(index, zoom, image, x, y)
    else
      if zoom > @max_raw_zoom
        img = @jpeg_pyramid.read_images_as_imlib(zoom, [index])[0]
      else
        img = @raw_pyramid.read_images_as_imlib(zoom, [index])[0]
      end
      $imlib_mutex.synchronize do
        img.has_alpha = true
        ctx = Imlib2::Context.get
        ctx.blend = true
        image.blend!(img, 0, 0, img.width, img.height,
                          x, y, img.width, img.height)
        img.delete!
      end
    end
  end

  def read_image_at(index, z)
    read_images_as_string(z, [index])
  end

  def read_image_as_imlib(lvl, index)
    if lvl <= @max_raw_zoom
      @raw_pyramid.read_images_as_imlib(lvl, [index])[0]
    elsif lvl <= @max_zoom
      @jpeg_pyramid.read_images_as_imlib(lvl, [index])[0]
    else
      raise "Level #{lvl} not in pyramids."
    end
  end

  def read_images_as_string(lvl, indexes)
    raise "No raw mipmap at that level." if lvl < 0 or lvl > @max_raw_zoom
    @raw_pyramid.read_images_as_string(lvl, indexes)
  end

  def read_span_as_string(lvl, start, last)
    raise "No raw mipmap at that level." if lvl < 0 or lvl > @max_raw_zoom
    d = @raw_pyramid.read_span_as_string(lvl, start, last)
    @total_data_read += d.size
    log_debug([:total_data_read, @total_data_read].inspect)
    d
  end
  
  def read_images_as_jpeg(lvl, indexes)
    raise "No JPEG mipmap at that level." if lvl < 0 or lvl > @max_zoom
    @jpeg_pyramid.read_images_as_string(lvl, indexes)
  end
  
  def read_span_as_jpeg(lvl, start, last)
    raise "No JPEG mipmap at that level." if lvl < 0 or lvl > @max_zoom
    d = @jpeg_pyramid.read_span_as_string(lvl, start, last)
    @total_data_read += d.size
    log_debug([:total_data_read, @total_data_read].inspect)
    d
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

  def bgra_to_rgb_alpha_jpeg(bgra)
    self.class.bgra_to_rgb_alpha_jpeg(bgra)
  end

  def imlib_to_rgb_alpha_jpeg(img)
    self.class.imlib_to_rgb_alpha_jpeg(img)
  end

  def crop_and_jpeg(bgra, lvl)
    self.class.crop_and_jpeg(bgra, lvl)
  end

  class << self
    def bgra_to_rgb_alpha_jpeg(bgra)
      sz = Math.sqrt(bgra.size / 4).to_i
      img = $imlib_mutex.synchronize{ Imlib2::Image.create_using_data(sz, sz, bgra) }
      imlib_to_rgb_alpha_jpeg(img)
    end

    def imlib_to_rgb_alpha_jpeg(img)
      a = ""
      a << ImagingUtils.imlib_to_gray_jpeg(img, 75) if img.has_alpha?
      rgb = ImagingUtils.imlib_to_jpeg(img, 75)
      rgba = [rgb.size].pack("I") << rgb << [a.size].pack("I") << a
      [rgba.size].pack("I") << rgba
    end

    def imlib_to_gray_jpeg(img)
      ImagingUtils.imlib_to_gray_jpeg(img, 75)
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
        rgba = ""
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
        a << ImagingUtils.imlib_to_gray_jpeg(img, 75) if img.has_alpha?
        rgb = ImagingUtils.imlib_to_jpeg(img, 75)
        rgba = [rgb.size].pack("I") << rgb << [a.size].pack("I") << a
      end
      [rgba.size].pack("I") << rgba
    end
  end

end


# The JPEGPyramid stores JPEG mipmap pyramids of images. Used by the TileDrawer
# to fill up its JPEG cache fast.
#
# The mipmap pyramids are stored in sequential files per zoom level. Each file
# contains the mipmaps of several images as RGB JPEG plus alpha grayscale JPEG.
# The sequential file has a fixed-length header with the mipmap offsets.
#
# Max single cache file size is 2GiB.
#
# Optimized for reading sequences of images at a given zoom level, reading a
# single image's full mipmap is a bad idea (takes around 2*max_zoom seeks (i.e.
# it's faster to read the highest resolution mip level and compute the rest on
# your own.))
#
class JPEGPyramid

  def initialize(cache_dir, cachefile_size=2**24, bottom_level=4, top_level=7)
    @cache_dir = cache_dir
    @cachefile_size = [2**31, cachefile_size].min
    @levels = (bottom_level..top_level)
    @parallel_reads = 8
    @indexes_per_level = {}
    @levels.each{|lvl|
      @indexes_per_level[lvl] = 2048 # @cachefile_size / (2**(2*lvl) * 4)
    }
    @update_mutex = Mutex.new
    @access_mutex = Mutex.new
  end

  def max_index
    dirname = File.join(@cache_dir, @levels.end.to_s)
    maxdir = Dir[dirname + "/*"].map{|n| File.basename(n).to_i }.max
    maxfile = Dir[File.join(dirname, maxdir.to_s, "*")].map{|n| File.basename(n).to_i }.max
    maxfile ||= 0
    ipl = @indexes_per_level[@levels.end]
    ipl * (maxfile+1) - 1
  end


  def verify
    max = max_index
    @levels.each do |lvl|
      ipl = @indexes_per_level[lvl]
      (0..(max_index / ipl.to_f).ceil).each{|i|
        open_at(lvl, i*ipl, 'rb'){|f,sz|
          len = f.stat.size
          f.seek(0)
          header = f.read(ipl*4).unpack("N*")
          prev = header.shift
          if ipl*4 != prev
            raise "#{ipl*4} != #{prev}, first index should be at end of header in file #{lvl}/#{i}."
          end
          idx = ipl*i
          until header.empty?
            f.seek(prev)
            jlen = f.read(4).unpack("I")[0]
            nxt = header.shift || len
            if nxt-prev != jlen+4 and jlen != 0
              raise "#{nxt-prev} != #{jlen+4} in file #{lvl}/#{i}, at index #{idx}."
            end
            prev = nxt
            idx += 1
          end
        }
      }
    end
  end
  
  def update_cache_at(index, data_levels)
  @update_mutex.synchronize do
    @levels.each{|lvl|
      next unless data_levels[lvl]
      open_at(lvl, index, 'rb+', true){|f,sz|
        f.write(data_levels[lvl])
      }
    }
  end
  end

  def clear_at(index)
  @update_mutex.synchronize do
    @levels.each{|lvl|
      open_at(lvl, index, 'rb+', true){|f,sz|
        f.write([0].pack("I"))
      }
    }
  end
  end

  # creates cache file with header, every entry pointing to a zero
  def create_cache_file(filename, level)
    File.open(filename, 'wb'){|f|
      f.flock(File::LOCK_EX)
      begin
        ipl = @indexes_per_level[level]
        f.write((0...ipl).map{|i| (i + ipl)*4 }.pack("N*"))
        f.write("\000\000\000\000"*ipl)
      ensure
        f.flock(File::LOCK_UN)
      end
    }
    log_debug([:created_jpeg_cache, level, File.size(filename), filename].inspect)
  end

  def open_at(level, index, mode, update_header=false)
  @access_mutex.synchronize do
    log_debug([:open_at, level, index, mode, update_header].inspect)
    ipl = @indexes_per_level[level].to_i
    level_idx = (index / ipl).to_i
    dirname = File.join(@cache_dir, level.to_s, (level_idx / 1000).to_s)
    FileUtils.mkdir_p(dirname)
    filename = File.join(dirname, level_idx.to_s)
    unless File.exist?(filename)
      create_cache_file(filename, level)
    end
    rel_idx = index % ipl
    File.open(filename, mode){|f|
      f.flock(File::LOCK_EX)
      begin
        log_debug([:seek_and_get_header, rel_idx, f.stat.size, f.pos].inspect)
        f.seek(rel_idx*4)
        header = f.read(4 + (rel_idx == ipl-1 ? 0 : 4))
        seek,nxt = header.unpack("NN")
        if update_header # update header with new index and seek to end of file
          if nxt
            f.seek(nxt)
            tail = f.read
          else
            tail = ""
          end
          sz = 0
          f.seek(seek)
          f.truncate(seek)
        else
          if nxt
            sz = nxt - seek
          else
            sz = f.stat.size - seek
          end
          f.seek(seek)
        end
        log_debug([:seek, seek, :sz, sz].inspect)
        res = yield(f, sz)
        if update_header
        #
        #
        # v
        # 4 5 6 7 | A B C D      -> 4 5
        #             v
        # 4 5 6 7 | A B C D      -> B C D
        #          v
        # 4 5 6 7 |              <- A A A
        #                v
        # 4 5 6 7 | A A A        <- B C D
        #                      v
        # 4 5 6 7 | A A A B C D
        #   v
        # 4 5 6 7 | A A A B C D  <- 7 8 9
        #           v
        # 4 7 8 9 | A A A B C D
        #
          start = f.pos
          f.write(tail)
          if nxt
            f.seek(rel_idx*4+4)
            tail_header = f.read((ipl-1-rel_idx)*4).unpack("N*")
            offset = start - tail_header[0]
          else
            tail_header = []
            offset = 0
          end
          new_tail_header = tail_header.map{|i| offset+i }.pack("N*")
          if new_tail_header.size != (ipl-1-rel_idx)*4
            raise "Bad tail header size! Got #{new_tail_header.size}, expected #{(ipl-1-rel_idx)*4}."
          end
          f.seek(rel_idx*4+4)
          f.write(new_tail_header) # update tail header
          f.seek(0)
          header = f.read(ipl*4).unpack("N*")
          if header[rel_idx] != seek
            raise "Botched header, should have #{seek} but has #{header[rel_idx]}"
          elsif header[rel_idx+1] and header[rel_idx+1] != start
            raise "Botched header tail, should start with #{start} but starts with #{header[rel_idx]}"
          elsif (not new_tail_header.empty?) and new_tail_header[-4,4].unpack("N")[0] != header.last
            raise "Botched header tail, should end with #{new_tail_header[-4,4].unpack("N")[0]} but ends with #{header.last}"
          end
        end
        res
      ensure
        f.flock(File::LOCK_UN)
      end
    }
  end
  end

  def get_next_seek(level, index)
  @access_mutex.synchronize do
    ipl = @indexes_per_level[level].to_i
    level_idx = (index / ipl).to_i
    dirname = File.join(@cache_dir, level.to_s, (level_idx / 1000).to_s)
    FileUtils.mkdir_p(dirname)
    filename = File.join(dirname, level_idx.to_s)
    unless File.exist?(filename)
      create_cache_file(filename, level)
    end
    rel_idx = index % ipl
    if rel_idx == ipl - 1
      return nil
    else
      File.open(filename, 'rb'){|f|
      f.flock(File::LOCK_EX)
      begin
        f.seek((rel_idx+1)*4)
        header = f.read(4)
        log_debug([:next_seek, header.unpack("N")].inspect)
        header.unpack("N")[0]
      ensure
        f.flock(File::LOCK_UN)
      end
      }
    end
  end
  end

  def read_span_as_string(level, start, last)
  @update_mutex.synchronize do
    log_debug([:read_span_as_string, level, start, last].inspect)
    if start == last
      sz = nil
      str = open_at(level, start, 'rb'){|f,sz|
        log_debug([:reading_one, f.pos, sz].inspect)
        f.read(sz)
      }
      return str
    elsif start > last
      raise "Bad read! Start #{start} bigger than last #{last}"
    end
    ipl = @indexes_per_level[level].to_i
    level_start_idx = (start / ipl).to_i
    level_end_idx = (last / ipl).to_i
    full_level_files = (level_start_idx+1..level_end_idx-1).to_a
    str = ""
    if level_end_idx == level_start_idx
      end_idx = get_next_seek(level, last)
      if end_idx
    log_debug( [:one_file_to_end_idx, start, last].inspect )
        open_at(level, start, 'rb'){|f,sz|
          log_debug([:reading_from, f.pos, :to, end_idx].inspect)
          begin
            str << f.read(end_idx-f.pos)
          rescue => e
            log_error([:error, start, last, end_idx, ipl, f.pos, sz].inspect)
            raise
          end
        }
      else
    log_debug( [:one_file_to_end, start].inspect )
        open_at(level, start, 'rb'){|f,sz|
          str << f.read
        }
      end
      return str
    else
      open_at(level, start, 'rb'){|f,sz|
    log_debug( [:first_file_to_end, start, f.pos, f.stat.size-f.pos].inspect )
        str << f.read
      }
    end
    full_level_files.each{|lf|
      open_at(level, lf * ipl, 'rb'){|f,sz|
    log_debug( [:full_file, lf*ipl, f.pos, f.stat.size-f.pos].inspect )
        str << f.read
      }
    }
    if level_end_idx != level_start_idx
      open_at(level, last, 'rb'){|f,sz|
        rsz = f.pos
        f.seek(ipl*4) # beginning of data
    log_debug( [:last_file, last, ipl*4, rsz, sz, (rsz-ipl*4)+sz].inspect )
        str << f.read((rsz-ipl*4)+sz)
      }
    end
    str
  end
  end

  def read_images(level, indexes)
    reads = indexes.zip((0...indexes.size).to_a).sort_by{|a,b| a }
    esz = 2**(2*level) * 4 / 15.0
    stream_limit = 2**18 / esz # reading 262kB / 80MB/s =~ 3ms
    result = indexes.dup
    spans = reads.inject([]){|s, (idx,j)|
      if s.last.nil? or s.last.first.end < idx-stream_limit
        s << [(idx..idx), {0 => j}]
      else
        r,is = s.last
        s.last[0] = (r.begin..idx)
        is[idx-r.begin] = j
      end
      s
    }
    total_span_length = spans.inject(0){|s,(sp,r)| s+(sp.end-sp.begin+1) }
    if indexes.size > total_span_length
      raise "Bad spans! #{total_span_length} < #{indexes.size}: #{spans.map{|s,i| s}}"
    end
    spans.each{|span,is|
      log_debug "reading span #{span}"
      s = read_span_as_string(level, span.begin, span.end)
      k = 0
      i = 0
      while k < s.size
        sz = s[k,4].unpack("I")[0]
        if is[i]
          result[is[i]] = s[k, sz+4]
        end
        k += sz+4
        i += 1
      end
    }
    result
  end

  def read_images_as_string(level, indexes)
    read_images(level, indexes).join
  end

  def read_images_as_imlib(level, indexes)
    read_images(level, indexes).map{|rgb_alpha_jpeg|
      bgra = ImagingUtils.decompress_rgb_alpha_jpeg(rgb_alpha_jpeg, 2**level, 2**level)
      $imlib_mutex.synchronize{ Imlib2::Image.create_using_data(2**level, 2**level, bgra) }
    }
  end

end


# The JPEGTileStore takes images and creates a mipmap of tile_size*tile_size
# tiles. An image is split into tiles and the tiles recursively merged until there
# is only one tile at top. Each tile consists of an RGB JPEG and an alpha channel
# grayscale JPEG.
#
# The tiles are stored as sequential files with a header that contains the
# mipmap level dimensions and tile offsets. Each mipmap level is in its own file.
# The usual use case is to read a screenful of tilerows, which
# needs (screen_height/tile_size).ceil seeks (with the assumption that
# read time <<< seek time.)
#
# The header format is:
#  [width:big-endian long,
#   height:big-endian long,
#   tile_offsets_from_start_of_file:list of big-endian longs]
#
# The tiles are ordered by row, top row first, with tiles within a row
# proceeding from left to right.
#
# Optimized for reading single images, not sequences of images.
#
class JPEGTileStore

  attr_reader :tile_size

  def initialize(cache_dir, tile_size=256)
    @cache_dir = cache_dir
    @tile_size = tile_size
    @init_mutex = Mutex.new
    @update_mutexes = {}
  end

  def get_dirname(index)
    File.join(@cache_dir, (index / 10000).to_s, index.to_s)
  end

  def clear_at(index)
    create_cache_files(index, 0, 0)
  end

  # Creates the cache files and writes the header struct.
  def create_cache_files(index, width, height)
    larger = [width,height].max
    if larger < tile_size or tile_size == 0
      levels = 0
    else
      levels = (Math.log(larger / tile_size.to_f) / Math.log(2)).ceil
    end
    dirname = get_dirname(index)
    if File.exist?(dirname)
      FileUtils.rm_rf(dirname)
    end
    FileUtils.mkdir_p(dirname)
    levels.downto(0) do |lvl|
      index_count = (width / tile_size.to_f).ceil * (height / tile_size.to_f).ceil
      log_debug([:new_header, index, lvl, width, height, index_count].inspect)
      File.open(File.join(dirname, lvl.to_s), 'wb') {|f|
      f.flock(File::LOCK_EX)
      begin
        f.write([width,height].pack("NN"))
        f.write(([0].pack("N"))*index_count)
      ensure
        f.flock(File::LOCK_UN)
      end
      }
      log_debug([:wrote_header, File.size(File.join(dirname, lvl.to_s))].inspect)
      width = (width / 2.0).ceil
      height = (height / 2.0).ceil
    end
    levels
  end

  def synchronize(index)
    tmm = @init_mutex.synchronize do
      m = (@update_mutexes[index] ||= [Mutex.new, 0])
      m[1] += 1
      m
    end
    # starvation possible here (get mutex, other thread gets mutex, locks)
    tmm[0].synchronize do
      tmm[1] -= 1
      rv = yield
      @init_mutex.synchronize do
        if tmm[1] == 0 # no other threads waiting
          @update_mutexes.delete(index)
        end
      end
      rv
    end
  end

  def update_cache_at(index, item)
    synchronize(index) do
      if item.respond_to?(:full_size_image) and item.full_size_image.exist?
       retried = false
       begin
        if item.respond_to?(:mimetype) and
        ["image/png","image/gif","image/jpg","image/tga"].include?(item.mimetype)
          pn = item.internal_path.to_pn
          pn.mimetype = Mimetype[item.mimetype]
        elsif item.full_size_image.to_pn.dimensions.max <= 256
          pn = item.thumbnail.to_pn
          pn.mimetype = Mimetype['image/png']
        else
          pn = item.full_size_image.to_pn
          pn.mimetype = Mimetype['image/jpeg']
        end
        w,h = pn.dimensions
       rescue
         item.full_size_image.unlink if item.full_size_image.exist?
         unless retried
           item.update_thumbnail(false)
           retried = true
           retry
         end
         raise
       end
      else
        pn = (item.internal_path || item.thumbnail).to_pn
        pn.mimetype = Mimetype[item.mimetype || pn.mimetype.to_s]
        w,h = pn.dimensions
        if !w or !h
          pn = item.thumbnail.to_pn
          pn.mimetype = Mimetype['image/png']
          w,h = pn.dimensions
        end
        if ['application/pdf','application/postscript'].include?(pn.mimetype.to_s)
          larger = [w,h].max
          scale_to = 2048.0
          fac = (scale_to / larger)
          w = (w * fac).round
          h = (h * fac).round
        end
      end
      larger = [w,h].max
      bound = [2**(Math.log(larger) / Math.log(2)).ceil, tile_size].max
      bfac = bound / larger.to_f
      w = (w * bfac).round
      h = (h * bfac).round
      levels = create_cache_files(index, w, h)
      log_debug([:levels, levels, w, h].inspect)
      if w > 0 and h > 0
        dirname = get_dirname(index)
        image = if pn.mimetype.to_s =~ /^image/
          begin
            Imlib2::Image.load(pn.to_s)
          rescue Exception => e
          end
        end
        if not image
          temp = File.join(dirname, "temp-#{Process.pid}-#{Thread.object_id}.png")
          $imlib_mutex.synchronize{ pn.thumbnail(temp, larger, 0) }
          image = Imlib2::Image.load(temp)
        end
        begin
          pages = 1 # pn.pages or item.metadata.pages
          tn_sz = bound.to_i
          width = w
          height = h
          levels.downto(0) do |level|
            log_debug([:w_h_tn_sz, width, height, tn_sz].inspect)
            File.open(File.join(dirname, level.to_s), 'rb+') {|f|
            f.flock(File::LOCK_EX)
            begin
              header = [f.stat.size] # header size
              log_debug([level, header].inspect)
              f.seek(0, IO::SEEK_END)
              pages.times do |page|
                (0 ... (height / tile_size.to_f).ceil).each do |y|
                  (0 ... (width / tile_size.to_f).ceil).each do |x|
                    img = image_thumbnail(image, tn_sz, page,
                      "#{tile_size}x#{tile_size}+#{x*tile_size}+#{y*tile_size}"
                    )
                    if (img.width != tile_size || img.height != tile_size)
                      raise "Bad tile size! Got #{img.width}x#{img.height}, should be #{tile_size}x#{tile_size}"
                    end
                    tile = ImageCache.imlib_to_rgb_alpha_jpeg(img)
                    f.write(tile)
                    header << header.last+tile.size
                  end
                end
              end
              f.rewind
              header.pop # last index is too many
              packed_header = [width,height].pack("NN") << header.pack("N*")
              if packed_header.size > header[0]
                raise "Bad header size! Got #{packed_header.size}, expected #{header[0]}."
              end
              f.write(packed_header)
            ensure
              f.flock(File::LOCK_UN)
            end
            }
            height /= 2
            width /= 2
            tn_sz /= 2
          end
        ensure
          $imlib_mutex.synchronize{ image.delete!(true) } if image
          File.unlink(temp) if temp and File.exist?(temp)
        end
      end
    end
  end

  def image_thumbnail(img, thumb_size, page=0, crop='0x0+0+0')
  $imlib_mutex.synchronize do
    ow, oh = img.width, img.height
    larger = [ow, oh].max
    wr = img.width.to_f / larger
    hr = img.height.to_f / larger
    sr = larger / thumb_size.to_f
    w,h,x,y = crop.scan(/[+-]?[0-9]+/).map{|i|i.to_i}
    w = thumb_size * wr if w == 0
    h = thumb_size * hr if h == 0
    rx,ry,rw,rh = [x,y,w,h].map{|i| i * sr }
    ctx = Imlib2::Context.get
    ctx.blend = false
    ctx.color = Imlib2::Color::TRANSPARENT
    ctx.op = Imlib2::Op::COPY
    if rx > ow or ry > oh
      nimg = Imlib2::Image.new(w, h)
      nimg.has_alpha = true
      nimg.fill_rectangle([0, 0, w, h])
    else
      nimg = Imlib2::Image.new(w,h)
      nimg.has_alpha = true
      nimg.fill_rectangle([0,0,w,h])
      tmp = img.crop_scaled(rx,ry,rw,rh, w, h)
      nimg.blend!(tmp,0,0,tmp.width,tmp.height,0,0,tmp.width,tmp.height)
      tmp.delete!(true)
      if rx+rw > ow
        nimg.has_alpha = true
        d = rx+rw - ow
        nimg.fill_rectangle([w - d / sr, 0, w, h])
      elsif ry+rh > oh
        nimg.has_alpha = true
        d = ry+rh - oh
        nimg.fill_rectangle([0, h - d / sr, w, h])
      elsif !img.has_alpha
        nimg.has_alpha = false
      end
    end
    ctx.blend = true
    nimg
  end
  end

  def clear_cache_at(index)
    synchronize(index) do
      create_cache_files(index, 0, 0)
    end
  end
  
  def draw_image_at(index, zoom, image, x, y)
    synchronize(index) do
      dir = get_dirname(index)
      level = zoom - (Math.log(tile_size) / Math.log(2)).to_i
      log_debug([:wanted_zoom_and_level, zoom, level].inspect)
      levels = Dir[dir+"/*"].map{|i| i.split("/").last.to_i }
      return if levels.empty?
      max = levels.max
      min = levels.min
      tsz = tile_size
      if level > max
        fac = 2**(level - max)
        tsz *= fac
        level = max
      elsif level < min
        fac = 2**(min - level)
        tsz *= fac
        level = min
      end
      log_debug([:clamped_level, level, levels.sort].inspect)
      first_x_tile = (-x / tsz.to_f).floor
      first_y_tile = (-y / tsz.to_f).floor
      last_x_tile = ((-x+image.width-1) / tsz.to_f).floor
      last_y_tile = ((-y+image.height-1) / tsz.to_f).floor
      x_range = (first_x_tile..last_x_tile)
      y_range = (first_y_tile..last_y_tile)
      filename = File.join(dir, level.to_s)
      File.open(filename, 'rb'){|f|
      f.flock(File::LOCK_EX)
      begin
        w,h = f.read(8).unpack("NN")
        cols = (w / tile_size.to_f).ceil
        rows = (h / tile_size.to_f).ceil
        offsets = f.read(cols * rows * 4).unpack("N*")
        log_debug([filename, w,h,cols,rows].inspect)
        y_range.each_with_index{|ty,i|
          next if ty < 0 or ty >= rows
          row_data = row_offsets = nil
          x_range.each_with_index{|tx,j|
            next if tx < 0 or tx >= cols
            unless row_data
              start_idx = ty*cols+tx
              end_idx = ty*cols+[x_range.end+1, cols].min
              sof = offsets[start_idx]
              eof = offsets[end_idx]
              row_offsets = offsets[start_idx...end_idx].map{|idx| idx-sof }
              f.seek(sof)
              row_data = eof ? f.read(eof-sof) : f.read
              row_offsets.push(row_data.size)
            end
            image_data = row_data[row_offsets[0]...row_offsets[1]]
            log_debug([:image_data, image_data.size].inspect)
            row_offsets.shift
            if image_data[0,4].unpack("I")[0] != image_data.size-4
              raise "Bad RGB-Alpha JPEG header! Got #{image_data[0,4].unpack("I")[0]}, expected #{image_data.size-4}."
            end
            data = ImagingUtils.decompress_rgb_alpha_jpeg(image_data, tile_size, tile_size)
            $imlib_mutex.synchronize do
              ctx = Imlib2::Context.get
              ctx.blend = true
              ctx.color = Imlib2::Color::TRANSPARENT
              ctx.op = Imlib2::Op::COPY
              img = Imlib2::Image.create_using_data(tile_size, tile_size, data)
              img.has_alpha = true
              ix = x + tx * tsz
              iy = y + ty * tsz
              log_debug([:blending, ix, iy, tsz].inspect)
              image.blend!(img, 0,  0,  img.width, img.height,
                                ix, iy, tsz, tsz)
              img.delete!(true)
            end
          }
        }
      ensure
        f.flock(File::LOCK_UN)
      end
      }
    end
  end

  def load_tile_at(index, level, x, y)
    synchronize(index) do
      dir = get_dirname(index)
      filename = File.join(dir, level.to_s)
      File.open(filename, 'rb'){|f|
      f.flock(File::LOCK_EX)
      begin
        w,h = f.read(8).unpack("NN")
        cols = (w / tile_size.to_f).ceil
        rows = (h / tile_size.to_f).ceil
        raise ArgumentError, "Coords out of bounds" if x < 0 or y < 0 or x >= cols or y >= rows
        offsets = f.read(cols * rows * 4).unpack("N*")
        start_idx = y*cols+x
        end_idx = start_idx+1
        sof = offsets[start_idx]
        eof = offsets[end_idx]
        f.seek(sof)
        image_data = eof ? f.read(eof-sof) : f.read
        if image_data[0,4].unpack("I")[0] != image_data.size-4
          raise "Bad RGB-Alpha JPEG header! Got #{image_data[0,4].unpack("I")[0]}, expected #{image_data.size-4}."
        end
        data = ImagingUtils.decompress_rgb_alpha_jpeg(image_data, tile_size, tile_size)
      ensure
        f.flock(File::LOCK_UN)
      end
      }
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
      f.flock(File::LOCK_EX)
      begin
        f.truncate(@cachefile_size)
      ensure
        f.flock(File::LOCK_UN)
      end
      }
    end
    File.open(filename, mode){|f|
    f.flock(File::LOCK_EX)
    begin
      f.seek((index % ipl) * 2**(2*level) * 4)
      yield(f)
    ensure
      f.flock(File::LOCK_UN)
    end
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
      log_debug "reading span #{span}"
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
