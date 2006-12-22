require 'future/base'


module Future

class Tags < DB::Tables::Tags
end

class ItemsTags < DB::Tables::ItemsTags
end

class Itemtexts < DB::Tables::Itemtexts
end

class Items < DB::Tables::Items

  def get_text
    read
  end

  def add_tag(tag_name)
    tag_name = tag_name.name if tag_name.is_a? DB::Table
    t = Tags.find_or_create(:name => tag_name)
    ItemsTags.find_or_create(:item => self, :tag => t)
    remove_instance_variable(:@tags) rescue nil
    remove_instance_variable(:@items_tags) rescue nil
  end

  def remove_tag(tag_name)
    tag_name = tag_name.name if tag_name.is_a? DB::Table
    t = Tags.find(:name => tag_name)
    return unless t
    ItemsTags.delete_all(:item => self, :tag => t)
    remove_instance_variable(:@tags) rescue nil
    remove_instance_variable(:@items_tags) rescue nil
  end

  def add_set(set)
    ItemsSets.find_or_create(:item => self, :set => set)
    remove_instance_variable(:@sets) rescue nil
    remove_instance_variable(:@items_sets) rescue nil
  end

  def remove_set(set)
    ItemsSets.delete_all(:item => self, :set => set)
    remove_instance_variable(:@sets) rescue nil
    remove_instance_variable(:@items_sets) rescue nil
  end

  def read
    File.open(internal_path, "rb"){|f| f.read}
  end

  def open
    if block_given?
      File.open(internal_path, "rb"){|f| yield f}
    else
      File.open(internal_path, "rb")
    end
  end

  def thumbnail(sz=256)
    Future.thumbnail_dir.join(*sha1_hash.scan(/(..)(..)(.*)/)[0]) + "#{sz}.png"
  end

  def update_thumbnail
    tn = thumbnail(256)
    unless tn.exist?
      tn.dirname.mkdir_p
      Mimetype[mimetype.to_s].thumbnail(internal_path, tn.to_s, 256)
    end
    update_image_cache
  end

  def update_image_cache
    Future.image_cache.update_cache_at(image_index, self)
  end
  
  def mimetype
    [major, minor].join("/")
  end

  def title
    if @title and @title.empty?
      nil
    else
      @title
    end
  end

  def info
    @info ||= parse_info
  end
  
  def parse_info
    stitle = self.title
    if m=metadata[0]
      stitle = [m['title'] || m['album']].
              reject{|i| i.to_s.empty? }.
              join(" - ") if title.nil? or title.empty?
      if stitle.nil? or stitle.empty?
        if title.nil? or title.empty?
          stitle = File.basename(filename).gsub("_"," ")
        else
          stitle = title
        end
      end
      stitle = m['author'] + " - " + stitle if m['author']
      dimensions = []
      dimensions << "%d:%02d" % [m['length'].to_i / 60, m['length'].to_i % 60] if m['length']
      if m['width'] and m['height']
        dimensions << "%dx%d%s%s" % [m['width'].to_i, m['height'].to_i, m['dimensions_unit'], (m['page_size'].to_s.size > 0 ? " ("+m['page_size']+")" : '')]
      end
      #dimensions << "#{m['bitrate'].to_i.mag('', 0)}bps" if m['bitrate']
      dimensions << "%d pages" % [m['pages'].to_i] if m['pages']
      if m['words'] and m['words'].to_i > 0
        dimensions << "#{m['words'].to_i.mag ' '}words"
        mins = m['words'].to_i / 300
        hours = mins / 60
        if mins > 0
          dimensions << "~#{hours > 0 ? "#{hours}h " : ""}#{mins % 60}min"
        else
          dimensions << "~#{m['words'].to_i / 5}s"
        end
      end
      stitle += " ("+dimensions.join(", ")+")" unless dimensions.empty?
    elsif title.nil? or title.empty?
      stitle = File.basename(filename).gsub("_", " ")
    end
    stitle
  end

  def description
    if desc=descriptions[0]
      desc unless bad_description? desc
    end
  end

  def bad_description? desc
    BAD_DESCRIPTIONS.find{|bd| bd =~ desc }
  end

  BAD_DESCRIPTIONS = [
    /\A *[A-Z ]+DIGITAL CAMERA *\Z/,
    /\A[a-z]+ DSC( [a-z]+)?\Z/i,
    /\A\(null\)\Z/i
  ]

  def self.rfind_all_fts(user, query, h = {})
    h = find_parse_args(user, h)
    h["groups"] = [h["groups"]] if h["groups"] and not h["groups"][0].is_a? Array
    h["groups"] ||= []
    h["groups"] << user.groups
    find_all_fts(query, h)
  end

  def self.find_all_fts(query, h={})
    qs = parse_query(h)
    qs = qs.split(/\n/)
    qs[2].sub!("FROM", "FROM itemtexts itexts,")
    ws = "WHERE ((itexts.sha1_hash = items.sha1_hash) AND itexts.fti_vector @@ to_tsquery(#{quote(query)}))"
    set = false
    qs.each do |line|
      if /^WHERE/ =~ line
        line.sub!("WHERE", ws + " AND ")
        set = true
        break
      end
    end
    qs << ws unless set
    q = DB::Conn.exec(qs.join("\n"))
    idx = -1
    q.map{|i| new q, idx+=1 }
  rescue
    log_debug("BAD QUERY")
    log_debug(h.inspect)
    log_debug(qs.join("\n"))
    raise
  end

end


end
