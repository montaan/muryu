#!/usr/bin/ruby

require 'future/base'
require 'future/metadata'
require 'future/storage'
require 'future/models/groups'
require 'future/models/metadata'
require 'future/recursive_downloader'
require 'uri'

module Future


class Uploader

  def self.upload(options)
    up = new BasicStore.new
    up.handle options
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

  # finds user/YYYY/MM-DD/preferred_filename[.n].ext that doesn't exist yet
  def create_unique_filename(preferred_filename, user, ext)
    dir = today(user)
    preferred_filename = preferred_filename.sub(/#{Regexp.escape(ext)}\Z/i, '')
    base = File.join(dir, sanitize(preferred_filename))
    latest_numbered = Items.find(:path => /^#{base}\.[0-9]+?#{Regexp.escape(ext)}/, 
                                 :order_by => [[:path, :desc]])
    if latest_numbered
      fn = latest_numbered.path
      num = fn.split(".")[-2].to_i + 1
      base + num.to_s.rjust(3, '0') + ext
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

  # Recursively stores the webpage and all images, stylesheets, scripts it
  # refers to. Assumes that URL is OK (untainted).
  def store_remote_item(url, owner, groups, can_modify, metadata_info)
    downloader = RecursiveDownloader.new(URI.parse(url))
    num_files = downloader.download
    fname_map = {} # uri => fname
    filenames = {} 
    uris = downloader.downloaded_files - [downloader.toplevel]
    toplevel = downloader.toplevel 
    log_debug("Page #{toplevel}, children #{uris.join(" ")}", "upload.rb")
    pending = []

    topname = File.basename(toplevel)
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

    pending.each do |fname, io|
      log_debug("Storing subitem #{fname} under #{item.path}.", "upload.rb")
      @store.store(fname, io, :sha1digest => item.sha1_hash,
                   :preserve_name => true)
      io.close # don't wait until it's GCed
    end
    item
  end

  # store item to db and file store
  def store_item(io, preferred_filename, owner, groups, can_modify, metadata_info)
    handle = @store.store(preferred_filename, io)
    mimetype = metadata_info[:mime_type] || MimeInfo.get(handle.full_path)
    major, minor = mimetype.to_s.split("/")
    metadata = MetadataExtractor[ handle.full_path, mimetype.to_s ] || {}
    item = nil
    attemps = MAX_ATTEMPS
    begin
      DB.transaction do
        mimetype_id = Mimetypes.find_or_create(:major => major, :minor => minor)
        # create new metadata to avoid nasty surprises with metadata edits
        metadata_id = Metadata.create(metadata)
        path = create_unique_filename(preferred_filename, owner, mimetype.extname)
        item = Items.create(
                            :path => path, :size => handle.size,
                            :internal_path => handle.full_path,
                            :source => metadata_info[:source], :referrer => metadata_info[:referrer],
                            :sha1_hash => handle.sha1digest, :deleted => false,
                            :mimetype_id => mimetype_id, :metadata_id => metadata_id,
                            :owner_id => owner.id, :created_at => Time.now.to_s)
        if "text/plain" == mimetype.to_s
          Itemtexts.find_or_create(:sha1_hash => handle.sha1digest, :text => item.read)
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
