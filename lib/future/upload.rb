#!/usr/bin/ruby

require 'future/base'
require 'future/metadata'
require 'future/storage'
require 'future/models/groups'
require 'future/models/metadata'
require 'future/recursive_downloader'
require 'iconv'
require 'mechanize'
require 'uri'

module Future


class Uploader

  SITE_HANDLERS = [

    # Youtube video page
    #
    lambda{|u|
      if u.to_s =~ /\Ahttp:\/\/([a-z]+\.)?youtube\.com\/watch/
        yu = "http://www.youtube.com/watch?v=#{CGI.parse(u.query)['v'].to_s}"
        nu,title,thumb,*tags = `future-youtube-dl -q -s #{u.to_s.dump}`.strip.split("\n")
        nu = URI.parse nu
        thumb_uri = URI.parse thumb if thumb.size > 0
        cmd = "wget -q -k --no-check-certificate -U 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' -i - -O %output_filename"
        ext = '.flv'
        [cmd, title.to_s + ext, nu, title, thumb_uri, tags]
      end
    },

    # Wikipedia image page
    #
    lambda do |u|
      if u.to_s =~ /\Ahttp:\/\/[a-z]+\.?(wikipedia|wikipedia)\.org\/wiki\/(Imagen?|Bild|Kuva|Fil|Grafika|%E7%94%BB%E5%83%8F):/
        page = Hpricot.parse(open(u){|f| f.read })
        f = page / "#file"
        if f.at(:a)
          url = f.at(:a)[:href]
        else
          url = f.at(:img)[:src]
        end
        cmd = "wget -q -k --no-check-certificate -U " +
              "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
              "-i - -O %output_filename"
        [cmd, nil, URI.parse(url), false]
      end
    end,

    # Flickr image page
    #
    lambda do |u|
      if pid = u.to_s.scan(/\Ahttp:\/\/[^\.]*\.?flickr\.com\/photos\/[^\/]+\/([^\/]+)/).flatten.first
        page = Hpricot.parse(open(u){|f| f.read })
        title = page / "#title_div#{pid}"
        f = page / "#photoImgDiv#{pid}"
        unless (page/"#photo_gne_button_zoom").empty?
          zoom_url = URI.parse("http://flickr.com/photo_zoom.gne?id=#{pid}&size=o")
          zoom_page = Hpricot.parse(open(zoom_url){|f| f.read })
          url = (zoom_page.at("div.DownloadThis")/"img")[1][:src]
        else
          url = f.at(:img)[:src]
        end
        tags =  (page/"#thetags"/"a.Plain").map{|t| t.innerHTML }
        cmd = "wget -q -k --no-check-certificate -U " +
              "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
              "-i - -O %output_filename"
        [cmd, title.text.to_s + ".jpg", URI.parse(url), title.text, nil, tags]
      end
    end,

    # Google image search page
    #
    lambda do |u|
      if u.to_s =~ /\Ahttp:\/\/images\.google\...\.?.?.?\//
        q = CGI.parse u.query
        if q.has_key? "imgurl"
          url = q["imgurl"].first
          cmd = "wget -q -k --no-check-certificate -U " +
                "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
                "-i - -O %output_filename"
          query = nil
          if q.has_key? "prev"
            v = URI.parse(q["prev"][0])
            query = CGI.parse(v.query)["q"][0]
          elsif $referrer and $referrer =~ /\Ahttp:\/\/images\.google\...\.?.?.?\//
            v = URI.parse($referrer)
            q = CGI.parse(v.query)
            query = q["q"][0] if q.has_key? 'q'
          end
          [cmd, nil, URI.parse(url), false, nil, query]
        else
          nil
        end
      end
    end,
    
    # Blogger image page
    #
    lambda do |u|
      if u.to_s =~ /\Ahttp:\/\/([a-z0-9A-Z]+\.)?blogger.com\/.*\/s[0-9]+\-h\/[^\/]+\Z/
        nu = URI.parse(u.to_s.sub(/\-h(\/[^\/]+)\Z/, '\1'))
        cmd = "wget -q -k --no-check-certificate -U " +
              "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
              "-i - -O %output_filename"
        [cmd, nil, nu]
      end
    end
  ]

  PROTO_HANDLERS = [
    lambda{|u|
      if ['http','https','ftp'].include? u.scheme.downcase
        title = is_html = charset = content_type = nil
        unless u.to_s =~ /\.(jpg|gif|png|mov|wmv|avi|qt|3gp)$/i
          headers = IO.popen(
              "curl --head -A "+
              "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
              "--url #{u.to_s.dump}",
              'r'
          ){|f|
            f.read.split(/\r?\n/)
          }
          is_html = (headers.grep(/^Content-type: text\/x?html/i).size > 0)
        end
        if is_html
          content_type = "text/html"
          cmd = "wget --restrict-file-names=windows -nd -nH -q -p -k -K -E -H --no-check-certificate -U " +
                "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
                "-i - -P %output_filename"
          begin
            page = WWW::Mechanize.new.get(u.to_s)
            etitle = page.title
            charset = page.content_type.split(';').grep(/charset=/).first.to_s.split("=",2).last.to_s.strip
            if charset.size > 0 and not charset =~ /^utf-?8$/i
              title = Iconv.iconv('utf-8', charset, etitle)
            else
              title = Iconv.iconv('utf-8', 'utf-8', etitle)
            end
          rescue
          end
        else
          cmd = "wget -q -k --no-check-certificate -U " +
                "'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.0.4) Gecko/20060508 Firefox/1.5.0.4' " +
                "-i - -O %output_filename"
        end
        [cmd, nil, u, title, nil, nil, content_type, charset]
      end
    },
    lambda{|u|
      if ['mms','rtsp'].include? u.scheme.downcase
        cmd = "mplayer32 -dumpstream -dumpfile %output_filename -playlist - 2 >>mplayer.log"
        [cmd,nil,u]
      end
    }
  ]

  def self.upload(options)
    up = new BasicStore.new
    up.handle options
  end

  def self.upload_archive(options)
    up = new BasicStore.new
    up.handle_compressed options
  end

  def initialize(store, option = {})
    @store = store
  end

  # options = {
  #   :user => user
  #   :filename => local_filename
  #   [:io => io | :source => source | :text => text]
  #   [:source => source]
  #   [:referrer => referrer]
  #   [:groups => groups]
  #   [:tags => tags]
  #   [:sets => sets]
  #   [:mime_type => mime_type]
  #   [:can_modify => whether specified groups have write access]
  # }
  #
  # Change this / upload.cgi / both to easiest to work with API.
  # Wanna figure out how to handle a webpage upload? :)
  # Should appear as a single item, bonus points for the ability to pick objects
  # from the page and turn them into separate items.
  #
  def handle(options)
    options = {:groups => [], :tags => [], :sets => []}.merge(options)
    is_remote = false
    unless options[:io]
      if options[:text]
        options[:io] = StringIO.new(options[:text])
        options[:filename] ||= "note"
      elsif options[:source]
        is_remote = true
      else
        raise ArgumentError, "Either :io, :text or :source required."
      end
    end
    options[:metadata_info] = {
      :description => options[:description],
      :mime_type => options[:mime_type],
      :source   => options[:source],
      :referrer => options[:referrer],
      :user     => options[:user],
      :can_modify => options[:can_modify]
    }

    if is_remote
      item = store_remote_item(*[:source, :user, :groups, :can_modify, :metadata_info].map{|f| options[f]})
    else
      item = store_item(*[:io, :filename, :user, :groups, :can_modify, :metadata_info].map{|f| options[f]})
    end
    options[:tags].each do |tag|
      item.add_tag tag
    end
    options[:sets].each do |set_name|
      set_name = set_name.name if set_name.is_a? DB::Table
      set = Sets.rfind_or_create(options[:user], :name => set_name)
      item.add_set set
    end
    item
  end

  def handle_compressed(options)
    is_remote = false
    unless options[:io]
      if options[:source]
        is_remote = true
      else
        raise ArgumentError, "Either :io or :source required."
      end
    end
    if is_remote
      remote = URI.parse(options[:source])
      if ["http","https","ftp"].include?(remote.scheme.downcase)
        open(remote){|io|
          uncompress(io, remote.to_s){|uncompressed_file|
            handle(options.merge(:io => uncompressed_file,
                                :filename => File.basename(uncompressed_file.path)))
          }
        }
      else
        raise "Unsupported scheme (only http, https and ftp allowed): #{remote.scheme} in #{remote}"
      end
    else
      uncompress(options[:io]){|uncompressed_file|
        handle(options.merge(:io => uncompressed_file,
                             :filename => File.basename(uncompressed_file.path)))
      }
    end
  end

  def uncompress(compressed, path=compressed.filename)
    if compressed.is_a? StringIO
      data = compressed.read
      return if data.empty?
      tf = Tempfile.new('cgi')
      tf.write data
      tf.close
      filename = tf.path
    elsif compressed.is_a? String
      data = compressed.to_s
      return if data.empty?
      tf = Tempfile.new('cgi')
      tf.write data
      tf.close
      filename = tf.path
    else
      filename = compressed.path
    end
    ext = File.extname(compressed.filename)
    ziptemp = tempdir
    p ext, path
    case ext
    when ".zip"
      `unzip -qq -d #{ziptemp.dump} #{filename.dump}`
    when ".tar"
      `tar -C #{ziptemp.dump} -x -f #{filename.dump}`
    when ".bz2"
      return unless path =~ /\.tar\.bz2\Z/
      `tar -C #{ziptemp.dump} -x -j -f #{filename.dump}`
    when ".gz"
      return unless path =~ /\.tar\.gz\Z/
      `tar -C #{ziptemp.dump} -x -z -f #{filename.dump}`
    when ".rar"
      Dir.chdir(ziptemp) {
        `unrar x -p- -y #{filename.dump}`
      }
    when ".7z"
      `7z x -y -o#{ziptemp.dump} -- #{filename.dump}`
    end
    files = `find #{ziptemp.dump} -type f`.split("\n")
    files.sort.each{|fn|
      File.open(fn, "rb"){|f| yield f }
    }
    FileUtils.rm_rf(ziptemp)
    tf.close! if tf
  end

  # finds user/YYYY/MM-DD/preferred_filename[.n].ext that doesn't exist yet
  def create_unique_filename(preferred_filename, user, exts)
    dir = today(user)
    unless ext = exts.find{|e| e == File.extname(preferred_filename).downcase }
      ext = exts.first
    end
    # strip out extname if any
    preferred_filename = preferred_filename.sub(/(#{exts.map{|e| Regexp.escape(e) }.join("|")})\Z/i,'')
    base = File.join(dir, sanitize(preferred_filename))
    latest_numbered = Items.find(:path => /^#{base}\.[0-9]+?#{Regexp.escape(ext)}/, 
                                 :order_by => [[:path, :desc]])
    if latest_numbered
      fn = latest_numbered.path
      num = fn.split(".")[-2].to_i + 1
      s = base + "." + num.to_s.rjust(3, '0') + ext
      s
    elsif Items.find(:path => "#{base}#{ext}")
      base + ".001" + ext
    else
      base + ext
    end
  end

  def today user
    File.join(user.name, Time.now.strftime("%Y/%m-%d"))
  end

  def sanitize filename
    File.basename(filename).gsub(/[^a-z0-9,. _-]/i, '_')
  end

  def filename_violation? e
    e.message =~ /violates unique constraint/
  end

  # how many times we try to store the file until we give up since getting an
  # unused path seems impossible
  MAX_ATTEMPS = 10

  def tempdir
    tmp_dir = "/tmp/muryu_uploads/#{Process.pid}-#{Thread.current.object_id}"
    FileUtils.mkdir_p(tmp_dir)
    tmp_dir
  end

  # Recursively stores the webpage and all images, stylesheets, scripts it
  # refers to. Assumes that URL is OK (untainted).
  def store_remote_item(url, owner, groups, can_modify, metadata_info)
    uri = URI.parse(url.strip)
    handler = (SITE_HANDLERS + PROTO_HANDLERS).find{|h| h[uri] }
    if handler
      cmd, preferred_filename, uri, title, thumb_uri, tags, content_type, charset = handler[uri]
      metadata_info[:mime_type] ||= Mimetype[content_type] if content_type
      metadata_info[:charset] ||= charset if charset
      tmp_dir = tempdir
      df = File.join(tmp_dir, "data")
      fcmd = cmd.gsub("%output_filename", df)
      IO.popen(fcmd, 'wb+'){|f|
        f.puts uri.to_s
        f.close_write
        f.each_line{|l| }
      }
      preferred_filename ||= CGI.unescape(File.basename(uri.to_s.strip))
      if File.directory?(df)
        origs = Dir[File.join(df, "*.orig")]
        topname = origs[0].gsub(/\.orig\Z/,'')
        log_debug("Top-level page is #{topname}.", "upload.rb")
        item = File.open(topname, 'rb') { |io|
          store_item(io, preferred_filename, owner, groups, can_modify, metadata_info)
        }
        (Dir.entries(df)-['data','.','..',File.basename(topname)]).each do |fname|
          fname = File.join(df, fname)
          log_debug("Storing subitem #{fname} under #{item.path}.", "upload.rb")
          File.open(fname, 'rb') { |io|
            @store.store(File.basename(fname), io, :sha1digest => item.sha1_hash,
                        :preserve_name => true)
          }
        end
      else
        item = File.open(df,'rb') { |io|
          store_item(io, preferred_filename, owner, groups, can_modify, metadata_info)
        }
      end
      FileUtils.rm_rf(tmp_dir)
      item.metadata.title = title if title
      tags.each{|tag| item.add_tag(tag) } if tags
    else
      # this branch is probably never hit anymore, thx to wget stuff above :<
      page = WWW::Mechanize.new.get(uri.to_s)
      etitle = page.title
      charset = page.content_type.split(';').grep(/charset=/).first.to_s.split("=",2).last.to_s.strip
      if charset.size > 0 and not charset =~ /^utf-?8$/i
        title = Iconv.iconv('utf-8', charset, etitle)
      else
        title = Iconv.iconv('utf-8', 'utf-8', etitle)
      end
      downloader = RecursiveDownloader.new(URI.parse(url))
      num_files = downloader.download
      fname_map = {} # uri => fname
      filenames = {} 
      uris = downloader.downloaded_files - [downloader.toplevel]
      toplevel = downloader.toplevel 
      log_debug("Page #{toplevel}, children #{uris.join(" ")}", "upload.rb")
      pending = []

      topname = CGI.unescape(File.basename(toplevel))
      topname = "index.html" if topname.empty?
      topname.gsub(/(\.[^.]+)?$/, ".html")
      fname_map[toplevel] = topname
      log_debug("Top-level page is #{toplevel.to_s} (#{topname}).", "upload.rb")

      find_unique_name = lambda do |dest|
        if fn = fname_map[dest.to_s]
          fn
        else
          fname = File.basename(URI.parse(dest.to_s).path)
          fname = "_" + fname while filenames[fname]
          filenames[fname] = true
          fname_map[dest.to_s]  = fname
        end
      end
      uris.each do |uri|
        io    = downloader.processed_file(uri){|src, dest, io| find_unique_name.call(dest) }
        fname = find_unique_name.call(uri)
        pending << [fname, io]
      end
      # FIXME: raise exception?
      top_io = downloader.processed_file(toplevel){|src, dest, io| fname_map[dest.to_s] || "store_remote_item_error" }
      
      item = store_item(top_io, topname, owner, groups, can_modify, metadata_info)
      item.metadata.title = title if title

      pending.each do |fname, io|
        log_debug("Storing subitem #{fname} under #{item.path}.", "upload.rb")
        @store.store(fname, io, :sha1digest => item.sha1_hash,
                    :preserve_name => true)
        io.close # don't wait until it's GCed
      end
    end

    item
  end

  # store item to db and file store
  def store_item(io, preferred_filename, owner, groups, can_modify, metadata_info)
    handle = @store.store(preferred_filename, io)
    mimetype = metadata_info[:mime_type]
    charset = metadata_info[:charset]
    unless mimetype
      tmp = File.join(
              File.dirname(handle.full_path.to_s),
              Time.now.to_f.to_s + File.basename(preferred_filename).reverse[0,64].reverse)
      begin
        FileUtils.ln(handle.full_path, tmp)
        mimetype = MimeInfo.get(tmp)
      rescue
        mimetype = MimeInfo.get(handle.full_path)
      ensure
        File.unlink(tmp)
      end
    end
    major, minor = mimetype.to_s.split("/")
    metadata = MetadataExtractor[ handle.full_path, mimetype.to_s, charset ] || {}
    item = nil
    attemps = MAX_ATTEMPS
    begin
      DB.transaction do
        mimetype_id = Mimetypes.find_or_create(:major => major, :minor => minor)
        # create new metadata to avoid nasty surprises with metadata edits
        metadata_id = Metadata.create(metadata)
        path = create_unique_filename(preferred_filename, owner, mimetype.extnames)
        item = Items.create(
                            :path => path, :size => handle.size,
                            :internal_path => handle.full_path,
                            :source => metadata_info[:source], :referrer => metadata_info[:referrer],
                            :sha1_hash => handle.sha1digest, :deleted => false,
                            :mimetype_id => mimetype_id, :metadata_id => metadata_id,
                            :owner_id => owner.id, :created_at => Time.now.to_s)
        text = MetadataExtractor.extract_text(handle.full_path, mimetype, charset)
        if text
          Itemtexts.find_or_create(:sha1_hash => handle.sha1digest, :text => text)
        end
        ([[owner.group, true]] + groups).each do |group, cm|
          cm = can_modify if cm.nil?
          unless group.is_a? DB::Table
            group = Groups.rfind_or_create(owner, :name => group)
          end
          ItemsGroups.find_or_create(
            :item_id => item.id,
            :group_id => group.id,
            :can_modify => cm ? true : false)
        end
      end
      item.update_thumbnail
    rescue => e
      retry if filename_violation?(e) && (attemps -= 1) > 0
      raise
    end
    item
  end
end # Uploader


end # Future
