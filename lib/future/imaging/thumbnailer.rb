require 'future/metadata'
require 'pathname'


class Pathname

  def thumbnail(thumb_filename)
    mimetype.thumbnail(self, thumb_filename)
  end

  def mimetype
    MimeInfo.get to_s
  end

end


module Mimetype

  # Default thumbnailer uses the mimetype icon as the thumbnail.
  def thumbnail(filename, thumb_filename)
    if to_s =~ /video/
      video_thumbnail(filename, thumb_filename)
    else
      image_thumbnail(filename, thumb_filename)
    end or
    icon_thumbnail(filename, thumb_filename)
  end

  def icon_thumbnail(filename, thumb_filename)
    icon.cp(thumb_filename)
  end

  def icon
    ancestors.map do |klass|
      Future.icon_dir + (klass.to_s.gsub(/\//, '_')+".png")
    end.find{|pn| pn.exist? }
  end

  def image_thumbnail(filename, thumb_filename)
    system("convert", filename, "-scale", '128x128>', thumb_filename)
    File.exist?(thumb_filename)
  end

  def video_thumbnail(filename, thumb_filename)
    video_cache_dir = Future.cache_dir + 'videotemp'
    video_cache_dir.mkdir_p
    video_cache_dir.glob("*").each{|e| e.unlink }
    system("mplayer", "-nosound", "-ss", "5.7", "-vf", "scale",
           "-vo", "jpeg:outdir=#{video_cache_dir}", "-frames", "10", filename)
    j = Dir[video_cache_dir + "*.jpg"].sort.last
    image_thumbnail(j, thumb_filename) if j
    File.exist?(thumb_filename)
  end
  
end
