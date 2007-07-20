require 'future/metadata'
require 'future/utils'
require 'fileutils'
require 'imlib2'


class Pathname

  def thumbnail(thumb_filename, *args)
    mimetype.thumbnail(self, thumb_filename, *args)
  end

  def create_tiles(tile_size=256, image_size=dimensions.max, pages=(0...pages), &block)
    block = lambda{|pg, x, y| to_s+"_#{pg}_#{y}_#{x}.jpg"} unless block_given?
    pages.each do |page|
      (0 .. (image_size-1) / tile_size).each do |x|
        (0 .. (image_size-1) / tile_size).each do |y|
          thumbnail(block.call(page, x, y), image_size, page,
                    "%dx%d+%d+%d" % [tile_size, tile_size, x*tile_size, y*tile_size])
        end
      end
    end
  end
  
end


module Mimetype

  # Converts wanted page|layer|time of filename into an image,
  # scales the image to fit inside a thumbsize x thumbsize rectangle and
  # crops a WxH+X+Y rectangle out of the scaled image. Saves the image to
  # thumbnail.
  #
  #
  # Examples:
  #
  # Creating tiles from a PDF:
  #
  #   pdf = 'gsp0606.pdf'.to_pn
  #   tn_sz = pdf.dimensions.max
  #   pdf.pages.times do |page|
  #     (0 .. pdf.width / 256).each do |x|
  #       (0 .. pdf.height / 256).each do |y|
  #         pdf.thumbnail(pdf.to_s+"_#{page}_#{y}_#{x}.jpg", tn_sz, page,
  #                       "256x256+#{x*256}+#{y*256}")
  #       end
  #     end
  #   end
  #
  #
  # At specific size:
  #
  #   pdf = 'gsp0606.pdf'.to_pn
  #   tn_sz = 2048
  #   pdf.pages.times do |page|
  #     4.times do |x|
  #       4.times do |y|
  #         pdf.thumbnail(pdf.to_s+"_#{page}_#{y}_#{x}.jpg", tn_sz, page,
  #                       "512x512+#{x*512}+#{y*512}")
  #       end
  #     end
  #   end
  #
  #
  # Or just:
  # 
  #   pdf = 'gsp0606.pdf'.to_pn
  #   pdf.create_tiles    # (256, 1024, [3,4]){|pg,x,y| "#{pg}_#{y}_#{x}.png" }
  #
  def thumbnail(filename, thumb_filename, thumb_size=nil, page=nil, crop='0x0+0+0')
#     puts "called thumbnail for #{filename} (#{to_s})"
    if to_s =~ /video/
      page ||= 5.7
      video_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    elsif to_s =~ /html/
      page ||= 0
      html_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    elsif to_s =~ /pdf/
      page ||= 0
      pdf_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    elsif to_s =~ /image|postscript/
      page ||= 0
      image_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    end or icon_thumbnail(filename, thumb_filename, thumb_size, crop)
  end

  def icon_thumbnail(filename, thumb_filename, thumb_size, crop='0x0+0+0')
    Mimetype['image/png'].image_thumbnail(icon(thumb_size), thumb_filename, thumb_size, 0, crop)
  end

  def icon(thumb_size=128)
    ancestors.map do |klass|
      Future.icon_dir + (klass.to_s.downcase.gsub(/\//, '-')+".png")
    end.find{|pn| pn.exist? }
  end

  def image_thumbnail(filename, thumb_filename, thumb_size, page=0, crop='0x0+0+0')
    tfn = thumb_filename.to_pn
    tmp_filename = tfn.dirname + ".tmp#{Process.pid}-#{Thread.object_id}#{tfn.extname}"
    if to_s =~ /^image/
      img = Imlib2::Image.load(filename.to_s)
      begin
        ow, oh = img.width, img.height
        larger = [ow, oh].max
        wr = img.width.to_f / larger
        hr = img.height.to_f / larger
        thumb_size ||= larger
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
          nimg = img.crop_scaled(rx,ry,rw,rh, w, h)
          nimg.has_alpha = true
          if rx+rw > ow
            d = rx+rw - ow
            nimg.fill_rectangle([w - d / sr, 0, w, h])
          elsif ry+rh > oh
            d = ry+rh - oh
            nimg.fill_rectangle([0, h - d / sr, w, h])
          end
        end
        ctx.blend = true
        nimg.save(tmp_filename.to_s)
      ensure
        img.delete!
        nimg.delete!(true) if nimg
      end
    else
#       puts "going to non-image fork"
      original_filename = filename
      filename = tfn.dirname + ".tmp#{Process.pid}-#{Thread.object_id}-src#{extname}"
      begin
        FileUtils.ln_s(original_filename.to_s, filename.to_s)
        filename.mimetype = self
        dims = filename.dimensions
        return false unless dims[0] and dims[1]
        larger = dims.max
        thumb_size ||= 2048
        case filename.metadata.dimensions_unit
        when 'mm'
          scale_fac = larger.mm_to_points / 72
        else
          scale_fac = larger / 72
        end
        density = thumb_size / scale_fac
        args = ["-density", density.to_s,
                "#{filename}[#{page}]",
                "-scale", "#{thumb_size}x#{thumb_size}",
                "-crop", crop.to_s,
                tmp_filename.to_s]
        log_debug('convert ' + args.join(" "))
        system("convert", *args)
      ensure
        filename.unlink if filename.exist?
      end
    end
    if tmp_filename.exist?
      tmp_filename.rename(tfn)
      true
    else
      false
    end
  end
  
  PNMPROGS = {
    ".jpg" => "pnmtojpeg",
    ".png" => "pnmtopng"
  }
  
  def pdf_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    w,h,x,y = crop.scan(/[+-]?[0-9]+/).map{|i|i.to_i}
    args = ["-x", x, 
            "-y", y,
            "-W", w,
            "-H", h,
            "-scale-to", thumb_size || 2048,
            "-f", page + 1,
            "-l", page + 1,
            filename.to_s.dump]
    ext = File.extname(thumb_filename.to_s)
    args += ["|", PNMPROGS[ext], ">", thumb_filename.to_s.dump]
    log_debug("pdftoppm " + args.join(" "))
    system("pdftoppm " + args.join(" "))
    if File.exist?(thumb_filename) and File.size(thumb_filename) > 0
      true
    else
      false
    end
  end

  def html_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    tfn = thumb_filename.to_pn
    tmp_filename = tfn.dirname + ".tmp#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}-moz.png"
    system('ruby',
      File.join(File.dirname(__FILE__), 'moz-snapshooter.rb'),
      "file://" + File.expand_path(filename),
      tmp_filename.expand_path
    )
    rv = Mimetype['image/png'].image_thumbnail(tmp_filename, thumb_filename, thumb_size, page, crop)
    tmp_filename.unlink if tmp_filename.exist?
    rv
  end

  def web_thumbnail(url, thumb_filename, thumb_size=nil, page=0, crop='0x0+0+0')
    tfn = thumb_filename.to_pn
    tmp_filename = tfn.dirname + ".tmp#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}-moz.png"
    system('ruby',
      File.join(File.dirname(__FILE__), 'moz-snapshooter.rb'),
      url.to_s,
      tmp_filename.expand_path
    )
    rv = Mimetype['image/png'].image_thumbnail(tmp_filename.expand_path, thumb_filename, thumb_size, page, crop)
    tmp_filename.unlink if tmp_filename.exist?
    rv
  end

  def video_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    video_cache_dir = Future.cache_dir + "videotemp-#{Process.pid}-#{Thread.object_id}-#{Time.now.to_f}"
    video_cache_dir.mkdir_p
    mplayer = `which mplayer32`.strip
    mplayer = `which mplayer`.strip if mplayer.empty?
    mplayer = "mplayer" if mplayer.empty?
    system(mplayer, "-nosound", "-ss", page.to_s, "-vf", "scale",
           "-vo", "jpeg:outdir=#{video_cache_dir}", "-frames", "10", filename)
    j = video_cache_dir.glob("*.jpg").sort.last
    Mimetype['image/jpeg'].image_thumbnail(j, thumb_filename, thumb_size, 0, crop) if j
    video_cache_dir.rmtree
    File.exist?(thumb_filename)
  end
  
end
