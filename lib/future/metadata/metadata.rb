require 'future/metadata/mp3info'
require 'future/metadata/mime_info'
require 'iconv'
require 'time'
require 'future/base'
require 'future/models/items'


class Pathname

  def mimetype
    @mimetype ||= MimeInfo.get(to_s)
  end

  def pages
    @pages ||= (metadata.pages || 1)
  end
  
  def dimensions
    @dimensions ||= [width, height]
  end

  def metadata
    @metadata ||= OpenStruct.new(Future::MetadataExtractor[self, mimetype])
  end

  def length
    @length ||= (metadata.length or metadata.words.to_i / 250.0)
  end

  delegate :metadata, :width, :height

end


module Future


# Extracts metadata from a file.
#
# Future::MetadataExtractor['foo.png']
#
module MetadataExtractor
extend self

  def audio_mpeg(fn, charset)
    Mp3Info.open(fn) do |m|
      t = m.tag
      md = {
        :bitrate => m.bitrate.to_i*1000,
        :length => m.length.to_f,
        :samplerate => m.samplerate.to_i,
        :vbr => m.vbr,
        :author => enc_utf8(t['artist'], charset),
        :genre => enc_utf8(t['genre_s'], charset),
        :publish_time => parse_time(t['year'], charset),
        :album => enc_utf8(t['album'], charset),
        :title => enc_utf8(t['title'], charset),
        :tracknum => parse_num(t['tracknum'], charset)
      }
    end
  end

  def application_pdf(fname, charset)
    h = pdfinfo_extract_info(fname)
    h['words'] = `pdftotext #{fname.dump} - | wc -w 2>/dev/null`.strip.to_i
    {
      :title, enc_utf8(h['title'], charset),
      :author, enc_utf8(h['author'], charset),
      :publish_time, parse_time(h['moddate'] || h['creationdate']),
      :pages, h['pages'],
      :width, h['width'],
      :height, h['height'],
      :dimensions_unit, 'mm',
      :page_size, h['page size'],
      :words, h['words']
    }
  end

  def application_ps(fname, charset)
    i = image(fname)
    i[:'width'] = (i[:'width'] * 0.3528).round.to_i
    i[:'height'] = (i[:'height'] * 0.3528).round.to_i
    i[:'dimensions_unit'] = 'mm'
    i[:'pages'] = i[:'frames']
    i.delete :'frames'
    i[:words] = `ps2ascii #{fname.dump} | wc -w 2>/dev/null`.strip.to_i
    i
  end

  def text_html(fname, charset)
    words = `html2text #{fname.dump} | wc -w 2>/dev/null`.strip.to_i
    {
      :words => words
    }
  end

  def text(fname, charset)
    words = `wc -w #{fname.dump} 2>/dev/null`.strip.to_i
    {
      :words => words
    }
  end

  def video(fname, charset)
    h = mplayer_extract_info(fname)
    info = {
      :length, (h['length'].to_i > 0) ? h['length'] : nil,
      :width, h['video_width'],
      :height, h['video_height'],
      :fps, h['video_fps'],
      :audio_bitrate, h['audio_bitrate'],
      :video_bitrate, h['video_bitrate'],
      :bitrate, (h['video_bitrate'].to_i + h['audio_bitrate'].to_i),
      :video_format, h['video_format'].to_s,
      :audio_format, h['audio_format'].to_s,
      :samplerate, h['audio_rate']
    }
  end

  alias_method(:application_x_flash_video, :video)

  def image(fname, charset)
    id_out = `identify #{fname.dump}`
    w,h = id_out.scan(/[0-9]+x[0-9]+/)[0].split("x",2)
    exif = extract_exif(fname)
    info = {
      :width => parse_val(w),
      :description => enc_utf8(exif["Image Description"], charset),
      :author => enc_utf8(exif["Artist"], charset),
      :height => parse_val(h),
      :frames => id_out.split("\n").size,
      :exif => enc_utf8(exif.map{|r| r.join("\t")}.join("\n"), charset)
    }
    if t = exif["Date and Time"]
      info[:publish_time] = parse_time(t.split(":",3).join("-"))
    end
    info
  end

  def extract(filename, mimetype=MimeInfo.get(filename.to_s), charset=nil)
    filename = filename.to_s
    major,minor = mimetype.to_s.gsub("-","_").split("/")
    mn = [major,minor].join("_")
    new_methods = public_methods(false)
    if new_methods.include?( mn )
      __send__ mn, filename, charset
    elsif new_methods.include?( major )
      __send__ major, filename, charset
    else
      {}
    end
  end

  def extract_text(filename, mimetype=MimeInfo.get(filename.to_s), charset=nil)
    return nil
    filename = filename.to_s
    major,minor = mimetype.to_s.gsub("-","_").split("/")
    mn = [major,minor,"_gettext"].join("_")
    new_methods = public_methods(false)
    if new_methods.include?( mn )
      __send__ mn, filename, charset
    elsif new_methods.include?( major )
      __send__ major, filename, charset
    else
      nil
    end
  end

  alias_method :[], :extract

  def text_plain__gettext(filename, charset)
    enc_utf8(File.read(filename), charset)
  end
  
  private

  def mplayer_extract_info(fname)
    output = IO.popen("mplayer -identify -vo null -ao null -frames 0 -playlist -", "r+"){|mp|
      mp.puts fname
      mp.close_write
      mp.read
    }
    ids = output.split("\n").grep(/^ID_/).map{|t|
      k,v, = t.split("=",2)
      k = k.downcase[3..-1]
      v = parse_val(v)
      [k,v]
    }
    Hash[*ids.flatten]
  end

  def extract_exif(fname)
    h = {}
    `exif -m #{fname.dump}`.strip.split("\n").each do |t|
      k,v = t.split("\t")
      h[k] = v
    end
    h
  end

  def pdfinfo_extract_info(fname)
    ids = `pdfinfo #{fname.dump}`.strip.split("\n").map{|r|
      k,v = r.split(":",2)
      k = k.downcase
      v = parse_val(v.strip)
      [k,v]
    }
    i = Hash[*ids.flatten]
    if i['page size']
      w,h = i['page size'].scan(/[0-9]+/)[0,2]
      wmm = w.to_f * 0.3528
      hmm = h.to_f * 0.3528
      i['page size'] = i['page size'].scan(/\(([^)]+)\)/)[0].to_s
      i['width'] = wmm.round.to_i
      i['height'] = hmm.round.to_i
    end
    i
  end


  def parse_val(v)
    case v
    when /^[0-9]+$/: v.to_i
    when /^[0-9]+(\.[0-9]+)?$/: v.to_f
    else
      v
    end
  end

  def enc_utf8(s, charset)
    return nil if s.nil? or s.empty?
    us = nil
    charsets = ['utf-8','shift-jis','euc-jp','iso8859-1','cp1252','big-5']
    charsets.unshift(charset) if charset
    charsets.find{|c|
      ((us = Iconv.iconv('utf-8', c, s)[0]) rescue false)
    }
    us ||= s.gsub(/[^0-9a-z._ '"\*\+\-]/,'?')
    us.gsub!(/^(\xFF\xFE|\xEF\xBB\xBF|\xFE\xFF)/, '') # strip UTF BOMs
    us
  end

  def parse_num(s)
    return s if s.is_a? Numeric
    return nil if s.nil? or s.empty?
    s.scan(/[0-9]+/)[0]
  end

  def parse_time(s)
    return s if s.is_a? StandardDateTime
    return nil if s.nil? or s.empty?
    StandardDateTime.parse(s.to_s)
  rescue
    t = s.to_s.scan(/[0-9]{4}/)[0]
    unless t.nil?
      t += "-01-01"
      StandardDateTime.parse(t)
    end
  end


end


end
