require 'future/metadata/mp3info'
require 'future/metadata/mime_info'
require 'imlib2'
require 'iconv'
require 'time'
require 'future/base'
require 'future/models/items'

class Pathname

  attr_accessor :mimetype

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


class Numeric
  
  def points_to_mm
    self * 0.3528
  end
  
  def mm_to_points
    self / 0.3528
  end
  
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
        :publish_time => parse_time(t['year']),
        :album => enc_utf8(t['album'], charset),
        :title => enc_utf8(t['title'], charset),
        :tracknum => parse_num(t['tracknum'])
      }
    end
  end

  def application_pdf(fname, charset)
    h = pdfinfo_extract_info(fname)
    txt = `pdftotext #{fname.dump} - | head -c 65536`
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
      :words, h['words'],
      :charset, UniversalDetector.chardet(txt)['encoding']
    }
  end

  def application_ps(fname, charset)
    i = image(fname)
    i[:'width'] = i[:'width'].points_to_mm
    i[:'height'] = i[:'height'].points_to_mm
    i[:'dimensions_unit'] = 'mm'
    i[:'pages'] = i[:'frames']
    i.delete :'frames'
    i[:words] = `ps2ascii #{fname.dump} | wc -w 2>/dev/null`.strip.to_i
    i
  end

  def text_html(fname, charset)
    words = `html2text #{fname.dump} | wc -w 2>/dev/null`.strip.to_i
    charset = UniversalDetector.chardet(File.open(fname){|f| f.read 65536 })['encoding']
    {
      :words => words,
      :charset => charset
    }
  end

  def text(fname, charset)
    words = `wc -w #{fname.dump} 2>/dev/null`.strip.to_i
    charset = UniversalDetector.chardet(File.open(fname){|f| f.read 65536 })['encoding']
    {
      :words => words,
      :charset => charset
    }
  end

  def video(fname, charset)
    h = mplayer_extract_info(fname)
    info = {
      :length, (h['length'].to_i > 0) ? h['length'] : nil,
      :width, h['video_width'],
      :height, h['video_height'],
      :dimensions_unit, 'px',
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
    begin
      img = Imlib2::Image.load(fname.to_s)
      w = img.width
      h = img.height
      id_out = ""
      img.delete!
    rescue Exception
      id_out = `identify #{fname.dump}`
      w,h = id_out.scan(/[0-9]+x[0-9]+/)[0].split("x",2)
    end
    exif = extract_exif(fname)
    info = {
      :width => parse_val(w),
      :description => enc_utf8(exif["Image Description"], charset),
      :author => enc_utf8(exif["Artist"], charset),
      :height => parse_val(h),
      :dimensions_unit => 'px',
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
    major,minor = mimetype.to_s.gsub(/[^\/a-z0-9]/i,"_").split("/")
    mn = [major,minor].join("_")
    new_methods = public_methods(false)
    if new_methods.include?( mn )
      __send__ mn, filename, charset
    elsif new_methods.include?( major )
      __send__ major, filename, charset
    else
      extract_extract_info(filename)
    end
  end

  def extract_text(filename, mimetype=MimeInfo.get(filename.to_s), charset=nil)
    filename = filename.to_s
    major,minor = mimetype.to_s.gsub(/[^\/a-z0-9]/i,"_").split("/")
    mn = [major,minor,"_gettext"].join("_")
    mm = [major,"_gettext"].join("_")
    new_methods = public_methods(false)
    if new_methods.include?( mn )
      __send__ mn, filename, charset
    elsif new_methods.include?( mm )
      __send__ mm, filename, charset
    else
      ""
    end
  end

  alias_method :[], :extract

  def text__gettext(filename, charset)
    enc_utf8(File.read(filename), charset)
  end

  def text_html__gettext(filename, charset)
    enc_utf8(`unhtml #{filename.dump}`, charset)
  end

  def application_pdf__gettext(filename, charset)
    enc_utf8(`pdftotext #{filename.dump} -`, charset)
  end
  
  def application_postscript__gettext(filename, charset)
    enc_utf8(`ps2ascii #{filename.dump}`, charset)
  end

  def application_msword__gettext(filename, charset)
    enc_utf8(`antiword #{filename.dump}`, charset)
  end
  
  def application_rtf__gettext(filename, charset)
    enc_utf8(`catdoc #{filename.dump}`, charset)
  end
  
  def application_vnd_ms_powerpoint__gettext(filename, charset)
    enc_utf8(`catppt #{filename.dump}`, charset)
  end

  def application_vnd_ms_excel__gettext(filename, charset)
    enc_utf8(`xls2csv -d UTF-8 #{filename.dump}`, charset)
  end

  

  open_office_types = %w(
  application/vnd.oasis.opendocument.text
  application/vnd.oasis.opendocument.text-template
  application/vnd.oasis.opendocument.text-web
  application/vnd.oasis.opendocument.text-master
  application/vnd.oasis.opendocument.graphics
  application/vnd.oasis.opendocument.graphics-template
  application/vnd.oasis.opendocument.presentation
  application/vnd.oasis.opendocument.presentation-template
  application/vnd.oasis.opendocument.spreadsheet
  application/vnd.oasis.opendocument.spreadsheet-template
  application/vnd.oasis.opendocument.presentation
  application/vnd.oasis.opendocument.chart
  application/vnd.oasis.opendocument.formula
  application/vnd.oasis.opendocument.database
  
  application/vnd.sun.xml.writer
  application/vnd.sun.xml.writer.template
  application/vnd.sun.xml.calc
  application/vnd.sun.xml.calc.template
  application/vnd.sun.xml.impress
  application/vnd.sun.xml.impress.template
  application/vnd.sun.xml.writer.global
  application/vnd.sun.xml.math

  application/vnd.stardivision.writer
  application/vnd.stardivision.writer-global
  application/vnd.stardivision.calc
  application/vnd.stardivision.impress
  application/vnd.stardivision.impress-packed
  application/vnd.stardivision.math
  application/vnd.stardivision.chart
  application/vnd.stardivision.mail

  application/x-starwriter
  application/x-starcalc
  application/x-stardraw
  application/x-starimpress
  application/x-starmath
  application/x-starchart)

  office_types = %w(
  application/msword
  application/vnd.ms-powerpoint
  application/vnd.ms-excel
  application/rtf
  )

  def self.create_text_extractor(mimetype, &block)
    major,minor = mimetype.to_s.gsub(/[^\/a-z0-9]/i,"_").split("/")
    mn = [major,minor,"_gettext"].join("_")
    define_method(mn, &block)
  end

  def self.create_info_extractor(mimetype, &block)
    major,minor = mimetype.to_s.gsub(/[^\/a-z0-9]/i,"_").split("/")
    mn = [major,minor].join("_")
    define_method(mn, &block)
  end

  open_office_types.each{|t|
    create_text_extractor(t) do |filename, charset|
      pdf = File.join(File.dirname(filename.to_s), File.basename(filename.to_s)+"-temp.pdf")
      if File.exist?(pdf)
        application_pdf__gettext(pdf, charset)
      else
        ''
      end
    end
  }
  
  (open_office_types + office_types).each{|t|
    create_info_extractor(t) do |filename, charset|
      pdf = File.join(File.dirname(filename.to_s), File.basename(filename.to_s)+"-temp.pdf")
      if File.exist?(pdf)
        extract_extract_info(filename).merge(application_pdf(pdf, charset))
      else
        extract_extract_info(filename)
      end
    end
  }
  
  private

  def mplayer_extract_info(fname)
    mplayer = `which mplayer32`.strip
    mplayer = `which mplayer`.strip if mplayer.empty?
    mplayer = "mplayer" if mplayer.empty?
    output = IO.popen("#{mplayer.dump} -quiet -identify -vo null -ao null -frames 0 -playlist - 2>/dev/null", "r+"){|mp|
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

  def extract_extract_info(fname)
    h = `extract #{fname.dump}`.strip.split("\n").map{|s| s.split(" - ",2) }.to_hash
    {
      :title, enc_utf8(h['title'] || h['subject'], nil),
#       :language, enc_utf8(h['language'], nil),
      :author, enc_utf8(h['creator'], nil),
      :publish_time, parse_time(h['date'] || h['creation date']),
      :description, enc_utf8(h['description'], nil),
#       :software, enc_utf8(h['software'], nil),
      :words, h['word count']
    }
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
      w,h = i['page size'].gsub(/[^0-9.]/, ' ').strip.split(/\s+/)
      wmm = w.to_f.points_to_mm
      hmm = h.to_f.points_to_mm
      i['page size'] = i['page size'].scan(/\(([^)]+)\)/)[0].to_s
      i['width'] = wmm
      i['height'] = hmm
      i['dimensions_unit'] = 'mm'
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
    s.to_utf8(charset)
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
