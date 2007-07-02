require 'future/upload'

module MuryuDispatch

  module Items
  include Handler
  extend self

    UPLOAD_FORM = <<-EOF
      <HTML>
      <HEAD>
      <TITLE>Upload items</TITLE>
      </HEAD>
      <BODY>
      <FORM METHOD="post" ENCTYPE="multipart/form-data" ACTION="/items/create">
      <P><A href="http://textism.com/tools/textile/" target="_new">TEXTILE</A><BR>
        <TEXTAREA NAME="text" ROWS="1" COLS="30"></TEXTAREA>
      </P>
      <P>GROUPS<BR>
        <INPUT name="groups" size="30" TYPE="text">
      </P>
      <P>SETS<BR>
        <INPUT name="sets" size="30" TYPE="text">
      </P>
      <P>TAGS<BR>
        <INPUT name="tags" size="30" TYPE="text">
      </P>
      <P>REMOTE FILES<BR>
        <INPUT name="url" size="30" TYPE="text" multiply="yes">
      </P>
      <P>REMOTE ARCHIVES<BR>
        <INPUT name="remote_compressed" size="30" TYPE="text" multiply="yes">
      </P>
      <P>LOCAL FILES<BR>
        <INPUT name="upload" size="15" TYPE="file" multiply="yes">
      </P>
      <P>ARCHIVES<BR>
        <INPUT name="compressed" size="15" TYPE="file" multiply="yes">
      </P>
      <P>BLANK FIELDS WILL BE IGNORED<BR>
        <INPUT TYPE="submit" VALUE="Send all this junk, pronto!">
      </P>
      </FORM>
      </BODY>
      </HTML>
    EOF
    
    METADATA_EDITABLE_COLUMNS = ['title', 'author', 'publisher', 'publish_time', 'description', 'location', 'genre', 'album', 'tracknum', 'album_art']

    ### VERBS
    
    def create(user, req, res)
      user = user
      if user != Future::Users.anonymous
        common_fields = {
          :groups => req.query['groups'],
          :public => req.query['public'],
          :sets => req.query['sets'],
          :tags => req.query['tags'],
          :referrer => req.headers['Referer']
        }
        common_fields.delete_if{|k,v| v.nil? or v.empty? }
        common_fields[:user] = user
        urls, texts, uploads, compressed, compressed_urls, sources, referrers = (
          ['url', 'text', 'upload',
          'compressed', 'remote_compressed',
          'source', 'referrer'
          ].map{|pat| req.query.keys.grep(/^#{pat}[0-9]*$/).
                      find_all{|k| req.query[k] and not req.query[k][0].empty? } }
        )
        p req.query
        unless [urls, texts, uploads, compressed, compressed_urls].all?{|k| k.empty?}
          urls.each{|u|
            num = u.scan(/[0-9]+/)[0]
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:source] = req.query[u][0]
            f[:referrer] = req.query[referrer][0] if referrer
            Future::Uploader.upload(common_fields.merge(f))
          }
          compressed_urls.each{|u|
            num = u.scan(/[0-9]+/)[0]
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:source] = req.query[u][0]
            f[:referrer] = req.query[referrer][0] if referrer
            Future::Uploader.upload_archive(common_fields.merge(f))
          }
          texts.each{|u|
            num = u.scan(/[0-9]+/)[0]
            source = sources.find{|r| r.scan(/[0-9]+/)[0] == num }
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:text] = req.query[u][0]
            f[:source] = req.query[source][0] if source
            f[:referrer] = req.query[referrer][0] if referrer
            Future::Uploader.upload(common_fields.merge(f))
          }
          uploads.each{|u|
            num = u.scan(/[0-9]+/)[0]
            source = sources.find{|r| r.scan(/[0-9]+/)[0] == num }
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:filename] = File.basename(req.query[u][0][:filename])
            f[:io] = req.query[u][0][:tempfile]
            next if f[:io].size == 0
            fd = f[:io]
            def fd.filename
              @filename
            end
            fd.instance_variable_set("@filename", f[:filename])
            f[:source] = req.query[source][0] if source
            f[:referrer] = req.query[referrer][0] if referrer
            Future::Uploader.upload(common_fields.merge(f))
          }
          compressed.each{|u|
            num = u.scan(/[0-9]+/)[0]
            source = sources.find{|r| r.scan(/[0-9]+/)[0] == num }
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:filename] = File.basename(req.query[u][0][:filename])
            f[:io] = req.query[u][0][:tempfile]
            next if f[:io].size == 0
            fd = f[:io]
            def fd.filename
              @filename
            end
            fd.instance_variable_set("@filename", f[:filename])
            f[:source] = req.query[source][0] if source
            f[:referrer] = req.query[referrer][0] if referrer
            Future::Uploader.upload_archive(common_fields.merge(f))
          }
          changed
        end
        if req.query.has_key?('close_when_done')
          res.body = <<-EOF
            <html><head><script>setTimeout(window.close,3000)</script></head>
            <body>Got item A-OK! Keep up the good work!</body></html>
          EOF
        elsif req.query.has_key?('json')
          res['Content-type'] = "text/plain"
          res.body = "Got it, thanks!"
        else
          res.status = 302
          res['Location'] = '/'
        end
      else
        res.body = <<-EOF
          <html><body>Please log in first.</body></html>
        EOF
        res.status = 401
      end
    end

    def edit(u, q,r)
    end

    def delete(u, q,r)
    end

    def undelete(u, q,r)
    end

    def purge(u, q,r)
    end

    ### PROPERTIES

    def json(user, q,res)
      first = 0
      last = 1000
      if q.query['first']
        first = q.query['first'][0].to_i
      end
      if q.query['last']
        last = q.query['last'][0].to_i
      end
      if q.query['offset']
        first = q.query['offset'][0].to_i
      end
      if q.query['limit']
        last = first + q.query['limit'][0].to_i-1
      end
      if last > first + 100000
        last = first + 100000
      end
      search_query = parse_search_query(user, q.query['q'].to_s)
      res.body = get_info_list(user, search_query, first, last, q.query['time'])
      res.content_type = 'application/json'
    end

    def view(u, q,res)
      ### TODO generate upload form with groups & sets & tags
      res.body = UPLOAD_FORM
    end

    def thumbnail(u, q,r)
    end

    def file(u, q,r)
    end

    ### helpers

    def changed
      $indexes_changed = true
      $info_changed = true
    end

    def get_matching_items(user, q, cols = :all)
      search_query = parse_search_query(user, q.query['q'].to_s)
      limit = 100
      if q.query['limit']
        limit = [0, [q.query['limit'][0].to_i, limit].min].max
      end
      offset = 0
      if q.query['offset']
        offset = [0, q.query['offset'][0].to_i].max
      end
      Future::Items.rfind_all(user, search_query.merge(:limit => limit, :columns => cols, :offset => offset))
    end

    def parse_search_query(user, q)
      puts "#{Thread.current.telapsed} for rest of handle_request" if $PRINT_QUERY_PROFILE
      parser = QueryStringParser.new
      default_query = if user.name == 'anonymous'
        "sort:date"
      else
        "user:#{user.name} sort:date"
      end
      query = parser.parse((q && !q.empty?) ? q : default_query)
      puts "#{Thread.current.telapsed} for search query parsing" if $PRINT_QUERY_PROFILE
      search_query = make_query_hash(query)
      puts "#{Thread.current.telapsed} for making a dbconn hash out of the AST" if $PRINT_QUERY_PROFILE
      search_query
    end

    def make_query_hash(query)
      h = {}
      collect_query(query, h)
      if h['mimetype_id']
        mimetypes = Future::Mimetypes.find_all(:columns => :all)
        mh = {}
        mimetypes.each{|mt| mh[mt.id] = [mt.major, mt.minor].join("/") }
        h['mimetype_id'] = extract_mimetypes(h['mimetype_id'], mh)
      end
      if h['deleted']
        if h['deleted'].downcase == 'any'
          h.delete('deleted')
        else
          h['deleted'] = h['deleted'].downcase == 'true'
        end
      end
      unless h[:order_by]
        h[:order_by] = [['image_index', :asc]]
      end
      h
    end

    def extract_mimetypes(arr, mh)
      case arr
      when String
        r = Regexp.new(arr)
        a = mh.find_all{|k,v|
          v =~ r
        }.map{|k,v| k }
        a.predicate = 'ANY'
        a
      else
        a = arr.map{|c| extract_mimetypes(c, mh) }.flatten
        a.predicate = 'ANY'
        a
      end
    end

    def collect_query(query, h=nil)
      case query
      when QueryStringParser::BinaryAnd
        +[collect_query(query.left,h),
          collect_query(query.right,h)]
      when QueryStringParser::BinaryOr
        a = [collect_query(query.left,h),
             collect_query(query.right,h)]
        a.predicate = 'ANY'
        a
      when QueryStringParser::SortExpr
        return unless h
        h[:order_by] ||= []
        h[:order_by] << sort_key(query.key, query.direction)
        nil
      when QueryStringParser::KeyValExpr
        return unless h
        h[column_key(query.key)] = collect_query(query.values)
      when String
        if h
          h[:path] ||= +[]
          h[:path] << /#{query}/i
        end
        query
      end
    end

    def sort_key(key, dir)
      dir_f = dir == 'asc' ? -1 : 1
      case key
      when 'modified'
        column = 'modified_at'
      when 'created'
        column = 'image_index'
      when 'new'
        column = 'image_index'
        dir_f *= -1
      when 'old'
        column = 'image_index'
      when 'date'
        column = 'image_index'
      when 'big'
        column = 'size'
        dir_f *= -1
      when 'small'
        column = 'size'
      when 'size'
        column = 'size'
      when 'user'
        column = 'owner_id'
      when 'source'
        column = 'source'
      when 'referrer'
        column = 'referrer'
      when 'type'
        column = 'mimetype_id'
      when 'name'
        column = 'path'
      end
      [column, dir_f == -1 ? :asc : :desc]
    end

    def column_key(key)
      case key
      when 'user'
        'owner.name'
      when 'deleted'
        'deleted'
      when 'set'
        'sets.name'
      when 'tag'
        'tags.name'
      when 'group'
        'groups.name'
      when 'type'
        'mimetype_id'
      when 'author'
        'metadata.author'
      when 'name'
        'metadata.title'
      when 'source'
        'source'
      when 'referrer'
        'referrer'
      when 'size'
        'size'
      when 'date'
        'created_at'
      when 'length'
        'metadata.length'
      when 'width'
        'metadata.width'
      when 'height'
        'metadata.height'
      when 'pages'
        'metadata.pages'
      when 'words'
        'metadata.words'
      when 'bitrate'
        'metadata.bitrate'
      when 'rating'
        'metadata.rating'
      end
    end
    
    def get_info_list(user, search_query, first, last, time)
      sq = search_query.clone
      key = Digest::MD5.hexdigest([user.id, "f#{first}l#{last}", sq, time].join("::"))
      jinfo = Future.memcache.get(key, true) if $CACHE_INFO and not $info_changed
      unless jinfo
        sq[:columns] ||= []
        sq[:columns] << 'path'
        sq[:columns] << 'deleted'
        puts "#{Thread.current.telapsed} for tile_info init" if $PRINT_QUERY_PROFILE
        items = Future::Tiles.info(
          user, sq, time,
          :rawlist, first, last, 0, 0, 0
        ).to_a.map do |iind,(_, info)|
          {:index => info[:index], :path => info[:path], :deleted => info[:deleted]}
        end.sort_by{|h| h[:index] }
        info = {:items => items, :itemCount => Future::Tiles.item_count(user, sq, time)}
        puts "#{Thread.current.telapsed} for fetching tile info" if $PRINT_QUERY_PROFILE
        jinfo = info.to_json
        puts "#{Thread.current.telapsed} for tile info jsonification" if $PRINT_QUERY_PROFILE
        Future.memcache.set(key, jinfo, 300, true) if $CACHE_INFO
      end
      jinfo
    end
    
    class Item < SingleHandler
      self.table = Future::Items
      attr_accessor :key_column

      def initialize(user, key)
        if key =~ /\A[0-9]+\Z/
          self.key_column = 'image_index'
        else
          self.key_column = 'path'
        end
        super
      end

      ### VERBS

      def make_public(req, res)
        target.radd_groups(user, ['public'])
        res['Content-type'] = 'text/plain'
        res.body = 'OK'
      end
      
      def make_private(req, res)
        target.rremove_groups(user, ['public'])
        res['Content-type'] = 'text/plain'
        res.body = 'OK'
      end
      
      def edit(req, res)
        unless req.query['filename'].to_s.empty?
          fn = req.query['filename'].to_s
          target.write(user) do
            parts = target.path.split("/")
            basename = parts.last
            baseparts = basename.split(".")
            if baseparts[0..-2].join(".") != fn
              newname = fn.gsub(/[^a-z0-9_., -]/i, "_") + "." + baseparts.last
              target.path = parts[0..-2].join("/") + "/" + newname
            end
          end
        end
        if req.query.has_key?('tags')
          tags = req.query['tags'].join(",").split(",").map{|t|t.strip}
          unless tags.empty?
            target.rset_tags(user, tags)
          end
        end
        if req.query.has_key?('groups') or req.query.has_key?('groups.new')
          gs = req.query['groups'] || []
          target.rset_groups(user, gs.find_all{|g|g.strip.length > 0})
        end
        if req.query.has_key?('sets') or req.query.has_key?('sets.new')
          gs = req.query['sets'] || []
          target.rset_sets(user, gs.find_all{|g|g.strip.length > 0})
        end
        if req.query.has_key?('groups.new')
          gs = req.query['groups.new'].join(",").split(",").find_all{|g|g.strip.length > 0}
          unless gs.empty?
            target.write(user) do
              gs.each do |g|
                target.add_group(Future::Groups.rfind_or_create(user, :name => g.strip))
              end
            end
          end
        end
        if req.query.has_key?('sets.new')
          gs = req.query['sets.new'].join(",").split(",")
          unless gs.empty?
            target.write(user) do
              gs.each do |g|
                target.add_set(Future::Sets.rfind_or_create(user, :name => g.strip))
              end
            end
          end
        end

        super

        target.write(user) do
          metadata_fields = req.query.keys.find_all{|k|
            k.split(".").first == 'metadata'
          }.map{|k| [k.split(".")[1], req.query[k]] }.find_all{|k,v|
            metadata_editable_column?(k)
          }
          DB.transaction do
            edits = metadata_fields.find_all{|k,v|
              target.metadata[k].to_s != v[0]
            }
            edits.each{|k,v|
              target.metadata[k] = v[0]
            }
            target[:modified_at] = Time.now.to_s
          end
          changed
        end
      end

      def purge(req, res)
        log_debug("purge: #{target.path} by #{user.name}")
        target.rpurge(user)
        changed
        res.body = 'OK'
      end

      def delete(req, res)
        log_debug("delete: #{target.path} by #{user.name}")
        target.rdelete(user)
        changed
        idxs = Future::Items.rfind_all(user, {:columns => [:image_index, :mimetype_id, :deleted], :as_array => true})
        tr = 't'
        nidxs = idxs.map{|i|
          ii = Integer(i[0])
          mi = (i[2] == tr ? Future::Tiles::MIMETYPE_DELETED : Integer(i[1]) + 1)
          [ii, mi]
        }
        t = [nidxs, nidxs.transpose.map{|ix| ix.pack("I*") }]
        res.body = 'OK'
      end
      
      def undelete(req, res)
        log_debug("undelete: #{target.path} by #{user.name}")
        target.rundelete(user)
        changed
        res.body = 'OK'
      end
      
      ### PROPERTIES

      def json(q,res) 
        res.content_type = 'application/json'
        res.body = to_hash.to_json
      end

      def view(q,r)
        super
      end

      def thumbnail(q,res)
        lm = @target.modified_at.httpdate
        if q['If-Modified-Since'] == lm
          res.status = 304
        else
          res['Last-Modified-At'] = lm
          res.body = @target.thumbnail.open('rb')
          res.content_type = 'image/png'
        end
      end

      def file(q,res)
        res.status = 302
        res['Location'] = '/files/' + @target.path
      end

      ### helpers

      def view_properties(req)
        ['file', 'thumbnail', 'json']
      end

      def view_actions(req)
        super + if target.writable_by(user)
          [
            ['Make public', File.join('/',req.path,'make_public')],
            ['Make private', File.join('/',req.path,'make_private')]
          ]
        else
          []
        end
      end
    
      def uneditable_columns
        super | ['modified_at', 'created_at', 'size',
                'sha1_hash', 'image_index', 'metadata_id',
                'internal_path', 'path']
      end

      def invisible_columns
        super | ['internal_path']
      end
    
      def changed
        $indexes_changed = true
        $info_changed = true
      end

      def metadata_editable_column?(k)
        METADATA_EDITABLE_COLUMNS.include?(k)
      end
      
      def to_hash
        ### FIXME too many db queries make jack a dull boy
        target = @target
        h = target.to_hash
        %w(mimetype_id owner_id metadata_id internal_path).each{|k| h.delete(k)}
        h[:groups] = target.groups.map{|g| g.name }
        h[:sets] = target.sets.map{|g| g.namespace+"/"+g.name }
        h[:tags] = target.tags.map{|g| g.name }
        h[:owner] = target.owner.name
        h[:metadata] = target.metadata.to_hash.reject{|k,v| v.nil? }
        h[:mimetype] = target.mimetype
        h[:writable] = !!target.writable_by(@user)
        h
      end
    
    end
    self.single_handler = Item
  end

end