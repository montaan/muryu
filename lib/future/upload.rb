#!/usr/bin/ruby

require 'future/base'
require 'future/metadata'

module Future
class Uploader
  def initialize(store, option = {})
    @store = store
  end

  def store_item(io, filename, timestamp, owner_name, groups, can_modify, mimetype, metadata)
    owner = DB::Tables::Users.find(:name => owner_name)
    # FIXME: appropriate exception
    raise ArgumentError unless owner
    # TODO: wrap in transaction
    handle = @store.store(filename, io)
    mimetype = MimeInfo.get(filename.to_s)
    major, minor = mimetype.gsub("-","_").split("/")
    mimetype_id = DB::Tables::Mimetypes.find_or_create(:major => major, :minor => minor)
    metadata_id = DB::Tables::Metadata.find_or_create(Metadata[handle.full_path])
    item = DB::Tables::Items.create(:filename => filename, :size => handle.size,
                             :sha1_hash => handle.sha1digest, :deleted => false,
                             :created_at => timestamp, :modified_at => timestamp, 
                             :mimetype_id => mimetype_id, :metadata_id => metadata_id, 
                             :owner_id => owner.id)
    groups.each do |gname|
      group = DB::Tables::Groups.find(:name => gname)}
      # foreign key magic in dbconn.rb ?
      DB::Tables::ItemsGroups.create(:item_id => item.id, :group_id => group.id, 
                                     :can_modify => can_modify)
    end
  end
end
