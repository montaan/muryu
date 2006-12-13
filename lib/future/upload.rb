#!/usr/bin/ruby

require 'future/base'
require 'future/metadata'
require 'future/storage'
require 'future/models/groups'
require 'future/models/metadata'

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
    options = {:groups => [[options[:user].group, true]], :tags => [], :sets => []}.merge(options)
    unless options[:io]
      if options[:text]
        options[:io] = StringIO.new(options[:text])
        options[:filename] ||= "note"
      elsif options[:source]
        options[:io] = DownloadIO.new(options[:source]) if options[:source]
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
    store_item(*[:io, :filename, :user, :groups, :can_modify, :metadata_info].map{|f| options[f]})
  end

  # finds user/YYYY/MM-DD/preferred_filename[.n].ext that doesn't exist yet
  def create_unique_filename preferred_filename, user, ext
    dir = today user
    preferred_filename = preferred_filename.sub(/#{Regexp.escape(ext)}\Z/i, '')
    base = File.join(dir, sanitize(preferred_filename))
    latest_numbered = Items.find(:path => /^#{base}\.[0-9]+?#{Regexp.escape(ext)}/, 
                                 :order_by => [[:path, :desc]])
    # FIXME: breaks after .999
    if latest_numbered
      fn = latest_numbered.path
      num = fn.split(".")[-2].to_i + 1
      base + (".%03d" % num) + ext
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

  # store item to db and file store
  def store_item(io, preferred_filename, owner, groups, can_modify, metadata_info)
    handle = @store.store(preferred_filename, io)
    mimetype = metadata_info[:mime_type] || MimeInfo.get(handle.full_path)
    major, minor = mimetype.to_s.split("/")
    metadata = MetadataExtractor[ handle.full_path, mimetype.to_s ]
    item = nil
    attemps = MAX_ATTEMPS
    begin
      DB.transaction do
        mimetype_id = Mimetypes.find_or_create(:major => major, :minor => minor)
        # create new metadata to avoid nasty surprises with metadata edits?
        metadata_id = Metadata.create(metadata)
        path = create_unique_filename(preferred_filename, owner, mimetype.extname)
        item = Items.create(
                            :path => path, :size => handle.size,
                            :internal_path => handle.full_path,
                            :source => metadata_info[:source], :referrer => metadata_info[:referrer],
                            :sha1_hash => handle.sha1digest, :deleted => false,
                            :mimetype_id => mimetype_id, :metadata_id => metadata_id,
                            :owner_id => owner.id, :created_at => Time.now.to_s)
        groups.each do |gname, can_modify|
          group = Groups.find(:name => gname)
          # TODO: abort??
          next unless group
          # foreign key magic in dbconn.rb ?
          ItemsGroups.create(:item_id => item.id, :group_id => group.id,
                             :can_modify => can_modify)
        end
      end
    rescue => e
      retry if filename_violation?(e) && (attemps -= 1) > 0
      raise
    end
    item
  end
end # Uploader


end # Future
