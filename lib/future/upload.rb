#!/usr/bin/ruby

require 'future/base'
require 'future/metadata'

module Future
class Uploader
  def initialize(store, option = {})
    @store = store
  end

  # options = {
  #   :user => user
  #   :filename => preferred_filename
  #   [:io => io | :source => source | :text => text]
  #   [:source => source]
  #   [:referrer => referrer]
  #   [:groups => groups]
  #   [:tags => tags]
  #   [:sets => sets]
  #   [:description => description]
  # }
  #
  # Change this / upload.cgi / both to easiest to work with API.
  # Wanna figure out how to handle a webpage upload? :)
  # Should appear as a single item, bonus points for the ability to pick objects
  # from the page and turn them into separate items.
  #
  def handle(options)
    options = {:groups => [[user.group, true]], :tags => [], :sets => []}.merge(options)
    options[:io] ||= StringIO.new(options[:text])
    options[:io] ||= DownloadIO.new(options[:source]) if options[:source]
    options[:metadata] = extract_metadata(
      options[:io], options[:description], options[:source],
      options[:referrer], options[:user]
    )
    store_item(*[:io, :filename, :user, :groups, :metadata].map{|f| options[f]})
  end

  # finds user/YYYY/MM-DD/preferred_filename[.n].ext that doesn't exist yet
  def create_unique_filename preferred_filename
  end

  # runs file through metadata extractor befitting its type
  def extract_metadata
  end

  def filename_violation? e
    e.message =~ /filename violates unique constraint/
  end

  # store item to db and file store
  def store_item(io, preferred_filename, owner, groups, metadata)
    handle = @store.store(filename, io)
    mimetype = MimeInfo.get(filename.to_s)
    major, minor = mimetype.gsub("-","_").split("/")
    DB.transaction do
      mimetype_id = Mimetypes.find_or_create(:major => major, :minor => minor)
      # create new metadata to avoid nasty surprises with metadata edits
      metadata_id = Metadata.create(metadata)
      item = nil
      begin
        filename = create_unique_filename preferred_filename
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
  end
end
