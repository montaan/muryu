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
    if tag_name.is_a?(DB::Table)
      t = tag_name
    else
      t = Tags.find_or_create(:name => tag_name)
    end
    ItemsTags.find_or_create(:item => self, :tag => t)
    remove_instance_variable(:@tags) rescue nil
    remove_instance_variable(:@items_tags) rescue nil
  end

  def write(*args)
    super
    self.modified_at = Time.now
  end

  def remove_tag(tag_name)
    if tag_name.is_a?(DB::Table)
      t = tag_name
    else
      t = Tags.find(:name => tag_name)
    end
    return unless t
    ItemsTags.delete_all(:item => self, :tag => t)
    remove_instance_variable(:@tags) rescue nil
    remove_instance_variable(:@items_tags) rescue nil
  end

  def rset_tags(user, new_tag_names)
    write(user) do
      new_tags = []
      DB.transaction do
        new_tags = new_tag_names.uniq.map{|t| Tags.find_or_create(:name => t) }
      end
      DB.transaction do
        (tags - new_tags).each{|t| remove_tag(t) }
      end
      DB.transaction do
        (new_tags - tags).each{|t| add_tag(t) }
      end
    end
  end

  def rset_sets(user, new_set_names)
    return unless readable_by(user)
    new_sets = []
    DB.transaction do
      new_sets = new_set_names.uniq.map{|t|
        ns,n = t.split("/",2)
        unless n
          n = ns
          ns = user.name
        end
        Sets.rfind_or_create(user, :name => n, :namespace => ns)
      }.compact
    end
    DB.transaction do
      (sets - new_sets).each{|t|
        t.write(user) do
          remove_set(t)
        end
      }
    end
    DB.transaction do
      (new_sets - sets).each{|t|
        t.write(user) do
          add_set(t)
        end
      }
    end
  end

  def rset_groups(user, new_group_names)
    write(user) do
      new_groups = []
      DB.transaction do
        new_groups = new_group_names.uniq.map{|t|
          Groups.rfind_or_create(user, :name => t)
        }
      end
      DB.transaction do
        (groups - new_groups).each{|t| remove_group(t) }
      end
      DB.transaction do
        (new_groups - groups).each{|t| add_group(t) }
      end
    end
  end

  def radd_groups(user, new_group_names)
    write(user) do
      new_groups = []
      DB.transaction do
        new_groups = new_group_names.uniq.map{|t|
          Groups.rfind_or_create(user, :name => t)
        }
      end
      DB.transaction do
        (new_groups - groups).each{|t| add_group(t) }
      end
    end
  end

  def rremove_groups(user, new_group_names)
    write(user) do
      new_groups = []
      DB.transaction do
        new_groups = new_group_names.uniq.map{|t|
          Groups.rfind(user, :name => t)
        }.compact
      end
      DB.transaction do
        (groups & new_groups).each{|t| remove_group(t) }
      end
    end
  end

  def add_group(group)
    ItemsGroups.find_or_create(:item => self, :group => group)
    remove_instance_variable(:@groups) rescue nil
    remove_instance_variable(:@items_groups) rescue nil
  end

  def remove_group(group)
    return if (group.namespace == 'users' and group.owner_id == owner_id)
    ItemsGroups.delete_all(:item => self, :group => group)
    remove_instance_variable(:@groups) rescue nil
    remove_instance_variable(:@items_groups) rescue nil
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

  def purge
    if self.class.find_all(:sha1_hash => sha1_hash).size == 1
      File.unlink(internal_path) if File.exist?(internal_path)
      File.unlink(thumbnail) if File.exist?(thumbnail)
      File.unlink(full_size_image) if File.exist?(full_size_image)
    end
    self.sha1_hash = nil
    self.internal_path = '/dev/null'
    self.size = 0
    self.mimetype_id = Mimetypes.find_or_create(:major => 'inode', :minor => 'chardevice').id
    self.path = image_index.to_s
    self.deleted = true
    self.source = nil
    self.referrer = nil
    self.metadata.to_hash.each{|k,v|
      self.metadata[k] = nil if k.to_s != 'id'
    }
    ItemsTags.delete_all(:item_id => id)
    ItemsSets.delete_all(:item_id => id)
    Itemtexts.delete_all(:item_id => id)
    update_image_cache
  end

  def thumbnail
    return nil unless sha1_hash
    Future.thumbnail_dir.join(*sha1_hash.scan(/(..)(..)(.*)/)[0]) + "256.png"
  end

  def full_size_image
    return nil unless sha1_hash
    Future.thumbnail_dir.join(*sha1_hash.scan(/(..)(..)(.*)/)[0]) + "fullsize.jpg"
  end

  def medium_size_image
    return nil unless sha1_hash
    Future.thumbnail_dir.join(*sha1_hash.scan(/(..)(..)(.*)/)[0]) + "mediumsize.jpg"
  end
  
  def update_metadata(charset=nil)
    ext_metadata = MetadataExtractor[ internal_path, mimetype.to_s, charset ] || {}
    md = self.metadata
    DB.transaction do
      ext_metadata.each{|k,v| md[k] = v }
    end
  end

  def update_thumbnail(update_image_cache_too=true, force_update=false)
    tn = thumbnail
    full_res = full_size_image
    if force_update or not tn.exist? or not full_res.exist?
      tn.dirname.mkdir_p
      created = false
      if mimetype == "text/html" and source and not source.empty?
        src = URI.parse(source)
        if ['http','https'].include?( src.scheme.downcase )
          begin
            Mimetype["text/html"].web_thumbnail(src, full_res.to_s)
            Mimetype["image/jpeg"].thumbnail(full_res.to_s, tn.to_s, 256)
            created = true
          rescue Exception => e
          end
        end
      end
      unless created
        Mimetype[mimetype.to_s].thumbnail(internal_path, full_res.to_s)
        Mimetype[mimetype.to_s].thumbnail(internal_path, tn.to_s, 256)
        if full_res.exist? and full_res.dimensions.max > 1024
          full_res.thumbnail(medium_size_image.to_s, 1024)
        end
      end
    end
    update_image_cache if update_image_cache_too
  end

  NON_FTS_METADATA_FIELDS = %w(exif album_art dimensions_unit color_depth frames fps id length pages samplerate vbr words)
  NON_FTS_METADATA = {}
  NON_FTS_METADATA_FIELDS.each{|f| NON_FTS_METADATA[f] = true }

  def text_file(layout=false)
    txtfile = thumbnail.dirname + "text_content-#{layout ? "layout" : "plain"}.txt"
    unless txtfile.exist?
      txtfile.open("wb"){|f|
        f.write(MetadataExtractor.extract_text(internal_path, mimetype, metadata.charset, layout))
      }
    end
    rv = tx = (txtfile.exist? ? txtfile.open("rb") : StringIO.new(""))
    if block_given?
      rv = yield tx
      tx.close
    end
    rv
  end

  def update_full_text_search
    str = ""
    text = []
    begin
      text << text_file{|f| f.read }
    rescue => e
      log_error([e, e.message, e.backtrace].join("\n"))
    end
    str = text.join("\n\n")
    if non_volatile = itemtexts.find{|it| not it.volatile }
      non_volatile.text = str
    else
      Itemtexts.find_or_create(:item_id => id, :text => str, :volatile => false)
    end
    update_volatile_full_text_search
  end

  def update_volatile_full_text_search
    str = ""
    text = []
    begin
      text << "#{owner.name}"
      text << [
        File.basename(path.to_s),
        File.basename(CGI.unescape(source.to_s)),
        File.basename(CGI.unescape(referrer.to_s)),
        tokenize_filename(File.basename(path.to_s)),
        tokenize_filename(CGI.unescape(source.to_s)),
        tokenize_filename(CGI.unescape(referrer.to_s)),
        major, minor].join("\n")
      text << metadata.to_hash.map{|k,v|
        if not NON_FTS_METADATA[k.to_s] and v and not v.to_s.empty?
          v
        else
          nil
        end
      }.compact.join("\n")
      if metadata.width and metadata.height
        text.last << "\n#{metadata.width}x#{metadata.height}"
        text.last << "\n#{metadata.width.to_i}x#{metadata.height.to_i}"
        text.last << "\n#{metadata.width.to_i} #{metadata.height.to_i}"
      end
      text << tags.map{|tag| tag.name }.join(" ")
    end
    str = text.join("\n\n")
    if volatile = itemtexts.find{|it| it.volatile }
      volatile.text = str
    else
      Itemtexts.find_or_create(:item_id => id, :text => str, :volatile => true)
    end
  end

  def tokenize_filename(fn)
    fn.gsub(/[a-z]{2,}(?=[A-Z0-9])|[A-Z](?=[0-9])|[0-9](?=[a-zA-Z])/){|m| m + " " }.
       gsub(/[^a-zA-Z0-9]/, ' ').
       gsub(/\s+/, ' ')
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
    ws = "WHERE ((itexts.item_id = items.id) AND itexts.fti_vector @@ to_tsquery(#{quote(query)}))"
    set = false
    qs.each do |line|
      if /^WHERE/ =~ line
        line.sub!("WHERE", ws + " AND ")
        set = true
        break
      end
    end
    qs = qs.insert(-2, ws) unless set
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
