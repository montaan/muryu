#!/usr/bin/ruby

require 'future/base'
require 'future/metadata'
require 'future/storage'

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
  # }
  #
  # Change this / upload.cgi / both to easiest to work with API.
  # Wanna figure out how to handle a webpage upload? :)
  # Should appear as a single item, bonus points for the ability to pick objects
  # from the page and turn them into separate items.
  #
  def handle(options)
    options = {:groups => [[options[:user].group, true]], :tags => [], :sets => []}.merge(options)
    options[:io] ||= StringIO.new(options[:text])
    options[:io] ||= DownloadIO.new(options[:source]) if options[:source]
    store_item(*[:io, :filename, :user, :groups, :source, :referrer, :text].map{|f| options[f]})
  end

  # finds user/YYYY/MM-DD/preferred_filename[.n].ext that doesn't exist yet
  def create_unique_filename preferred_filename, user, ext
    dir = today user
    preferred_filename = preferred_filename.sub(/\.#{ext}\Z/i, '')
    base = File.join(dir, sanitize(preferred_filename))
    latest = Items.find(:filename => /^#{base}(\.[0-9]+)?\.#{ext}/, :order_by => [[:filename, :desc]])
    if latest
      fn = latest.filename
      num = (fn =~ /^#{base}\.#{ext}/) ? 1 : fn.split(".")[-2].to_i+1
      base + ".#{num}." + ext
    else
      base + "." + ext
    end
  end

  def today user
    File.join(user.name, Time.now.strftime("%Y/%m-%d"))
  end

  def sanitize filename
    File.basename(filename).gsub(/[^a-z0-9,. _-]/i, '_')
  end

  def filename_violation? e
    e.message =~ /filename violates unique constraint/
  end

  # store item to db and file store
  def store_item(io, preferred_filename, owner, groups, source, referrer, text)
    handle = @store.store(preferred_filename, io)
    mimetype = "text/x-post" if text
    mimetype ||= MimeInfo.get(preferred_filename.to_s).to_s
    major, minor = mimetype.split("/")
    metadata = MetadataExtractor[ preferred_filename, mimetype ]
    item = nil
    DB.transaction do
      mimetype_id = Mimetypes.find_or_create(:major => major, :minor => minor)
      # create new metadata to avoid nasty surprises with metadata edits?
      metadata_id = Metadata.create(metadata)
      begin
        filename = create_unique_filename preferred_filename, owner, mimetype.ext
        item = Items.create(
              :filename => filename, :size => handle.size,
              :sha1_hash => handle.sha1digest, :deleted => false,
              :mimetype_id => mimetype_id, :metadata_id => metadata_id,
              :owner_id => owner.id)
      rescue => e
        retry if filename_violation? e # watch out for infinite loop
        raise
      end
      groups.each do |gname, can_modify|
        group = Groups.find(:name => gname)
        # foreign key magic in dbconn.rb ?
        ItemsGroups.create(:item_id => item.id, :group_id => group.id,
                                      :can_modify => can_modify)
      end
    end
    item
  end
end # Uploader


end # Future