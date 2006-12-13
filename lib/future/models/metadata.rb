
require 'future/metadata'

module Future

class Items < DB::Tables::Items

  def update_metadata
    md = Metadata.find_or_create(:item_id => id)
    autodetect_metadata.each{|k,v|
      md[k] = v
    }
  end

  def autodetect_metadata
    MetadataExtractor[Future.items_dir+filename, mimetype]
  end
  
end


class Metadata < DB::Tables::Metadata
end


class Mimetypes < DB::Tables::Mimetypes
end

end
