class String
  def to_class_name
    gsub(/^.|_./){|m| m[-1,1].upcase }
  end
end


class MuryuQuery

  class Matcher
    def initialize(*sig, &block)
      @sig = sig
      @block = block if block_given?
    end
  
    def match(obj)
      @sig.all?{|s| obj.respond_to?(s)} and (!@block or @block.call(obj))
    end
  end

  class MuryuError < ArgumentError
  end
  
  class UnknownType < MuryuError
  end

  class NoListQuery < MuryuError
  end

  class BadMethod < MuryuError
  end
  
  class BadKey < MuryuError
  end
  
  class BadGet < MuryuError
  end
  
  class BadPost < MuryuError
  end
  
  attr_reader(:path, :type, :method, :key, :list_query, :get, :post, :cookies)

  class << self
    attr_accessor(:type_methods, :type_list_query, :type_keys, :type_method_get_validators, :type_method_post_validators)
  end
  
  self.type_methods = {
    'items' => %w(upload edit delete undelete purge json view thumbnail file),
    'files' => %w(view item),
    'sets' => %w(create json edit delete undelete view),
    'users' => %w(create login logout json edit delete view),
    'groups' => %w(create json edit delete undelete view),
    'tile' => %w(view),
    'tile_info' => %w(view)
  }
  
  uint = '(([1-9][0-9]*)|0)'
  int = "((-|\\+)?#{uint})"
  ufloat = "((#{uint}(\.[0-9])?|0\.[0-9])[0-9]*)"
  float = "((-|\\+)?#{ufloat})"
  relative_path = '([0-9A-Za-z._-]+/[0-9]{4}/[0-9]{2}-[0-9]{2}/[0-9A-Za-z._-]+)'
  items_query = '(.*)'
  itemkey = "(#{uint}|#{relative_path})"
  filename = '(\S+)'
  setname = '(.+)'
  username = '([0-9A-Za-z._-]+)'
  password = '(.+)'
  tagname = '(\S+)'
  setkey = "(#{username}/#{setname})"
  groupname = '([0-9A-Za-z._-]+)'
  tile = "(x[0-9]+\\.[0-9]+y[0-9]+\\.[0-9]+z#{uint}w#{uint}h#{uint})"
  boolean = '(true|false)'
  url = '(.*)'
  string = '(.*)'
  location = "(\\(#{float},#{float}\\))"
  mimetype = '([a-z]+/[0-9a-z._-]+)'
  date = '(-?[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})'
  color = '([0-9a-fA-F]{6})'
  file = Matcher.new(:[]){|o|
    o.is_a?(Hash) and o[:filename] and o[:tempfile]
  }

  def self.e(pattern)
    Regexp.new('\A'+pattern+'\Z')
  end
  
  self.type_keys = {
    'items' => e(itemkey),
    'files' => e(relative_path),
    'sets' => e(setkey),
    'users' => e(username),
    'groups' => e(groupname),
    'tile' => e(tile),
    'tile_info' => e(tile)
  }

  list_of = lambda{|r|
    /\A\s*((#{r})\s*,\s*)*(#{r})\s*\Z/
  }

  field_names = %w(image_index owner path deleted sha1_hash size source referrer created_at modified_at sets tags groups mimetype metadata all).join("|")

  up = {
    'username' => e(username),
    'password' => e(password)
  }
  
  self.type_list_query = {
    'items' => {
      'q' => e(items_query)
    },
    'files' => {
      'q' => e(items_query)
    },
    'sets' => {
      'name' => e(setname),
      'owner' => e(username)
    },
    'users' => false,
    'groups' => false,
    'tile' => false,
    'tile_info' => {
      'q' => e(items_query)
    }
  }
  
  self.type_method_get_validators = {
    'items' => {
      'view' => up,
      'file' => up,
      'thumbnail' => up,
      'json' => {
        'columns' => list_of[field_names]
      }.merge(up)
    },
    'files' => {
      'view' => up,
      'item' => up
    },
    'sets' => {
      'view' => up,
      'json' => up
    },
    'users' => {
      'view' => up,
      'json' => up
    },
    'groups' => {
      'view' => up,
      'json' => up
    },
    'tile' => {
      'view' => {
        'q' => e(string),
        'color' => e(boolean),
        'bgcolor' => e(color)
      }.merge(up)
    },
    'tile_info' => {
      'view' => {
        'q' => e(string),
        'color' => e(boolean),
        'columns' => list_of[field_names],
        'bgcolor' => e(color)
      }.merge(up)
    }
  }


  item_edit = up.merge({
    'filename' => e(string),
    'source' => e(url),
    'referrer' => e(url),
    'sets' => list_of[setname],
    'groups' => list_of[groupname],
    'tags' => list_of[tagname],
    'title' => e(string),
    'description' => e(string),
    'publish_time' => e(date),
    'publisher' => e(string),
    'author' => e(string),
    'album_art' => e(string),
    'genre' => e(string),
    'album' => e(string),
    'tracknum' => e(int),
    'location' => e(location)
  })
  self.type_method_post_validators = {
    'items' => {
      'upload' => item_edit.merge({
        'remote_file' => e(url),
        'remote_archive' => e(url),
        'local_file' => file,
        'local_archive' => file
      }),
      'edit' => item_edit,
      'delete' => up,
      'undelete' => up,
      'purge' => up
    },
    'files' => {},
    'sets' => {
      'create' => {
        'name' => e(setname)
      }.merge(up),
      'edit' => {
        'name' => e(setname)
      }.merge(up),
      'delete' => up,
      'undelete' => up
    },
    'users' => {
      'login' => up,
      'logout' => {
      },
      'create' => up,
      'edit' => {'new_password' => e(password)}.merge(up),
      'delete' => up,
      'undelete' => up
    },
    'groups' => {
      'create' => {
        'name' => e(string),
        'public' => e(boolean)
      }.merge(up),
      'edit' => {
        'name' => e(string),
        'public' => e(boolean)
      }.merge(up),
      'delete' => up,
      'undelete' => up
    }
  }
  
  def initialize(req)
    @get = req.get
    @post = req.post
    @cookies = req.cookies
    self.path = req.relative_path
  end

  def valid_methods
    self.class.type_methods[@type]
  end
  
  def valid_key_pattern
    self.class.type_keys[@type]
  end
  
  def valid_method?(name)
    valid_methods.include?(name)
  end
    
  def valid_type?
    self.class.type_methods.has_key?(@type)
  end
  
  def valid_key?(key)
    valid_key_pattern.match(key)
  end

  def valid_get?(key, val)
    validate('get', key, val)
  end
  
  def valid_post?(key, val)
    validate('post', key, val)
  end

  def validate(t, key, vals)
    v = self.class.__send__('type_method_'+t+'_validators')[@type][@method]
    raise(BadMethod, "#@type/#@method doesn't respond to #{t.upcase}") unless v
    if @list_query
      v = v.merge(self.class.type_list_query[@type])
    end
    return false unless v and v[key]
    vals.all?{|val| v[key].match(val) }
  end
  
  def has_list_query?
    self.class.type_list_query[@type]
  end

  def path=(path)
    @path = path
    @type, rest = path.split("/", 2)
    raise(UnknownType, "Unknown type: #@type.") unless valid_type?
    parts = rest.to_s.split("/").reject{|s| s.empty? }
    @list_query = false
    if parts.length > 1
      if valid_method?(parts.last)
        @method = parts.last
        @key = parts[0..-2].join("/")
      else
        @method = 'view'
        @key = parts.join("/")
      end
      raise(BadKey, "Malformed key for #@type: #@key") unless valid_key?(@key)
    elsif parts.length == 1 and not valid_method?(parts[0])
      @method = 'view'
      @key = parts[0]
      raise(BadKey, "Malformed key for #@type: #@key") unless valid_key?(@key)
    elsif (parts[0] == 'create' ||
           @type == 'items' && parts[0] == 'upload' ||
           @type == 'users' && parts[0] == 'login' )
      @method = parts[0]
    elsif (has_list_query?)
      @method = parts[0] || 'view'
      @list_query = true
    else
      raise(NoListQuery, "You tried to reach #@type/#@method, but #@type doesn't have a list query.")
    end
    if @post and not @post.empty?
      bp = @post.find_all{|k,v| !valid_post?(k, v) }
      raise(BadPost, "Bad POST query arguments for #@type/#@method (#{
        @list_query ? 'list query' : "target: #{@key or 'new'}"
      }): "+bp.map{|k,v| k + " => " + v.join(",") }.join(", ")) unless bp.empty?
    elsif @get and not @get.empty?
      bg = @get.find_all{|k,v| !valid_get?(k, v) }
      raise(BadGet, "Bad GET query arguments for #@type/#@method (#{
        @list_query ? 'list query' : "target: #{@key or 'new'}"
      }): "+bg.map{|k,v| k + "=" + v.join(",") }.join(", ")) unless bg.empty?
    end
  end
  
end


MuryuResponse = Struct.new(:status, :content_type, :body, :headers)


module MuryuDispatch

  def self.dispatch(req)
    dispatch_request(req)
  end

  def self.get_handler(type)
    const_get(type.to_class_name)
  end
  
  def self.dispatch_request(req)
    r = MuryuResponse.new
    r.status = 200
    r.content_type = 'text/html'
    r.body = ''
    r.headers = {}
    begin
      q = MuryuQuery.new(req)
      handler = get_handler(q.type)
      if not q.key
        handler.__send__(q.method, q, r)
      else
        handler[q.key].__send__(q.method, q, r)
      end
    rescue MuryuQuery::BadMethod => e
      r.status = 405
      r.body = error(e,r.status.to_s+" Unsupported method")
    rescue MuryuQuery::BadKey, MuryuQuery::BadGet, MuryuQuery::BadPost => e
      r.status = 400
      r.body = error(e,r.status.to_s+" Bad request")
    rescue MuryuQuery::NoListQuery, MuryuQuery::UnknownType => e
      r.status = 404
      r.body = error(e,r.status.to_s+" File not found")
    end
    r
  end

  def self.error(e, s)
    "
    <html>
      <head>
        <title>#{s}</title>
      </head>
      <body>
        <h1>#{s}: #{e.class.name}</h1>
        <p>#{e.message}</p>
      </body>
    </html>"
  end

  module Items
  extend self
    def [](key)
      self
    end

    ### VERBS
    
    def upload(q,r)
    end

    def edit(q,r)
    end

    def delete(q,r)
    end

    def undelete(q,r)
    end

    def purge(q,r)
    end

    ### PROPERTIES

    def json(q,r)
    end

    def view(q,r)
    end

    def thumbnail(q,r)
    end

    def file(q,r)
    end
  end


  module Files
  extend self

    def [](key)
      self
    end

    ### PROPERTIES
  
    def view(q,r)
    end

    def item(q,r)
    end
  end


  module Sets
  extend self

    def [](key)
      self
    end

    ### VERBS

    def create(q,r)
    end

    def edit(q,r)
    end

    def delete(q,r)
    end

    def undelete(q,r)
    end

    ### PROPERTIES

    def json(q,r)
    end

    def view(q,r)
    end

  end


  module Users
  extend self

    def [](key)
      self
    end

    ### VERBS

    def create(q,r)
    end

    def login(q,r)
    end

    def logout(q,r)
    end

    def edit(q,r)
    end

    def delete(q,r)
    end

    ### PROPERTIES

    def json(q,r)
    end

    def view(q,r)
    end

  end


  module Groups
  extend self

    def [](key)
      self
    end

    ### VERBS

    def create(q,r)
    end

    def edit(q,r)
    end

    def delete(q,r)
    end

    def undelete(q,r)
    end

    ### PROPERTIES

    def json(q,r)
    end

    def view(q,r)
    end

  end


  module Tile
  extend self

    def [](key)
    end

    def view(q,r)
    end

  end


  module TileInfo
  extend self

    def [](key)
    end

    def view(q,r)
    end

  end
  
end



