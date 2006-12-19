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

  def thumbnail(thumb_filename, thumb_size=128)
    mimetype.thumbnail(self, thumb_filename, thumb_size)
  end

  def mimetype
    MimeInfo.get to_s
  end

end


module Mimetype

  def thumbnail(filename, thumb_filename, thumb_size=128)
    if to_s =~ /video/
      video_thumbnail(filename, thumb_filename, thumb_size)
    else
      image_thumbnail(filename, thumb_filename, thumb_size)
    end or
    icon_thumbnail(filename, thumb_filename, thumb_size)
  end

  def icon_thumbnail(filename, thumb_filename, thumb_size=128)
    icon(thumb_size).cp(thumb_filename)
  end

  def icon(thumb_size)
    ancestors.map do |klass|
      Future.icon_dir + thumb_size.to_s + (klass.to_s.gsub(/\//, '_')+".png")
    end.find{|pn| pn.exist? }
  end

  def image_thumbnail(filename, thumb_filename, thumb_size)
    system("convert", "#{filename}[0]", "-scale", "#{thumb_size}x#{thumb_size}", thumb_filename)
    File.exist?(thumb_filename)
  end

  def video_thumbnail(filename, thumb_filename, thumb_size)
    video_cache_dir = Future.cache_dir + 'videotemp'
    video_cache_dir.mkdir_p
    video_cache_dir.glob("*").each{|e| e.unlink }
    system("mplayer", "-nosound", "-ss", "5.7", "-vf", "scale",
           "-vo", "jpeg:outdir=#{video_cache_dir}", "-frames", "10", filename)
    j = Dir[video_cache_dir + "*.jpg"].sort.last
    image_thumbnail(j, thumb_filename, thumb_size) if j
    File.exist?(thumb_filename)
  end
  
end
