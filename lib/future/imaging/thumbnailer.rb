require 'future/metadata'
require 'fileutils'
require 'pathname'

class Pathname

  def mkdir_p
    FileUtils.mkdir_p(to_s)
  end

  def glob(subpath, *args)
    self.class.glob((self+subpath).to_s, *args)
  end

end


class Pathname

  def thumbnail(thumb_filename, *args)
    mimetype.thumbnail(self, thumb_filename, *args)
  end

  def mimetype
    MimeInfo.get to_s
  end

end


module Mimetype

  def thumbnail(filename, thumb_filename, thumb_size=128, page=nil, crop='0x0+0+0')
    if to_s =~ /video/
      page ||= 5.7
      video_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    else
      page ||= 0
      image_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    end or
    icon_thumbnail(filename, thumb_filename, thumb_size, crop)
  end

  def icon_thumbnail(filename, thumb_filename, thumb_size=128, crop='0x0+0+0')
    image_thumbnail(icon(thumb_size), thumb_filename, thumb_size, 0, crop)
  end

  def icon(thumb_size)
    ancestors.map do |klass|
      Future.icon_dir + thumb_size.to_s + (klass.to_s.gsub(/\//, '_')+".png")
    end.find{|pn| pn.exist? }
  end

  def image_thumbnail(filename, thumb_filename, thumb_size, page=0, crop='0x0+0+0')
    dimstrs = `identify "#{filename}"[0]`.scan(/ [0-9]+x[0-9]+ /)
    return false if dimstrs.empty?
    dims = dimstrs[0].strip.split("x").map{|c|c.to_f}
    if dims.min < thumb_size
      scale_fac = thumb_size / dims.min
    elsif dims.max > thumb_size
      scale_fac = thumb_size / dims.max
    else
      scale_fac = 1
    end
    density = scale_fac * 72
    args = ["-density", density.to_s,
            "#{filename}[#{page}]",
            "-scale", "#{thumb_size}x#{thumb_size}",
            "-crop", crop.to_s,
            thumb_filename]
    system("convert", *args)
    File.exist?(thumb_filename)
  end

  def video_thumbnail(filename, thumb_filename, thumb_size, page, crop)
    video_cache_dir = Future.cache_dir + 'videotemp'
    video_cache_dir.mkdir_p
    video_cache_dir.glob("*").each{|e| e.unlink }
    system("mplayer", "-nosound", "-ss", page.to_s, "-vf", "scale",
           "-vo", "jpeg:outdir=#{video_cache_dir}", "-frames", "10", filename)
    j = Dir[video_cache_dir + "*.jpg"].sort.last
    image_thumbnail(j, thumb_filename, thumb_size, 0, crop) if j
    File.exist?(thumb_filename)
  end
  
end
