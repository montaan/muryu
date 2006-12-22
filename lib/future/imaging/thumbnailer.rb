require 'future/metadata'
require 'future/utils'
require 'fileutils'


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
  def thumbnail(filename, thumb_filename, thumb_size=128, page=nil, crop='0x0+0+0')
    if to_s =~ /video/
      page ||= 5.7
      video_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    elsif to_s =~ /image|pdf|postscript|html/
      page ||= 0
      image_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    end or icon_thumbnail(filename, thumb_filename, thumb_size, crop)
  end

  def icon_thumbnail(filename, thumb_filename, thumb_size=128, crop='0x0+0+0')
    image_thumbnail(icon(thumb_size), thumb_filename, thumb_size, 0, crop)
  end

  def icon(thumb_size)
    ancestors.map do |klass|
      Future.icon_dir + (klass.to_s.gsub(/\//, '_')+".png")
    end.find{|pn| pn.exist? }
  end

  def image_thumbnail(filename, thumb_filename, thumb_size, page=0, crop='0x0+0+0')
    dims = filename.to_pn.dimensions
    return false unless dims[0] and dims[1]
    scale_fac = 1
    if dims.min < thumb_size
      scale_fac = thumb_size / dims.min.to_f
    elsif dims.max > thumb_size
      scale_fac = thumb_size / dims.max.to_f
    end
    density = scale_fac * 72
    tfn = thumb_filename.to_pn
    tmp_filename = tfn.dirname + ".tmp#{Process.pid}-#{Thread.object_id}#{tfn.extname}"
    args = ["-density", density.to_s,
            "#{filename}[#{page}]",
            "-scale", "#{thumb_size}x#{thumb_size}",
            "-crop", crop.to_s,
            tmp_filename.to_s]
    system("convert", *args)
    if tmp_filename.exist?
      tmp_filename.rename(tfn)
      true
    else
      false
    end
  end

  def video_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    video_cache_dir = Future.cache_dir + "videotemp-#{Process.pid}-#{Thread.object_id}"
    video_cache_dir.mkdir_p
    system("mplayer", "-nosound", "-ss", page.to_s, "-vf", "scale",
           "-vo", "jpeg:outdir=#{video_cache_dir}", "-frames", "10", filename)
    j = video_cache_dir.glob("*.jpg").sort.last
    image_thumbnail(j, thumb_filename, thumb_size, 0, crop) if j
    video_cache_dir.rmtree
    File.exist?(thumb_filename)
  end
  
end
