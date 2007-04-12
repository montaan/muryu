class String
  def to_class_name
    gsub(/^.|_./){|m| m[-1,1].upcase }
  end
end


class MuryuQuery

  class MuryuError < ArgumentError
  end
  
  class UnknownType < MuryuError
  end

  class NoListQuery < MuryuError
  end
  
  class BadKey < MuryuError
  end
  
  class BadGet < MuryuError
  end
  
  class BadPost < MuryuError
  end
  
  attr_reader(:path, :type, :method, :key, :list_query, :get, :post)

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
      'q' => e(string)
    },
    'files' => {
      'q' => e(string)
    },
    'sets' => {
      'name' => e(setname),
      'owner' => e(username)
    },
    'users' => false,
    'groups' => false,
    'tile' => false,
    'tile_info' => false
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
        'local_file' => e(string),
        'local_archive' => e(string)
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

  def validate(t, key, val)
    v = self.class.__send__('type_method_'+t+'_validators')[@type][@method]
    if @list_query
      v = v.merge(self.class.type_list_query[@type])
    end
    return false unless v and v[key]
    v[key].match(val)
  end
  
  def has_list_query?
    self.class.type_list_query[@type]
  end

  def path=(path)
    @path = path
    @type, rest = path.split("/", 2)
    raise(UnknownType, "@path=#@path, @type=#@type") unless valid_type?
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
      raise(BadKey, "@path=#@path, @type=#@type, @key=#@key}") unless valid_key?(@key)
    elsif parts.length == 1 and not valid_method?(parts[0])
      @method = 'view'
      @key = parts[0]
      raise(BadKey, "@path=#@path, @type=#@type, @key=#@key}") unless valid_key?(@key)
    elsif (parts[0] == 'create' ||
           @type == 'items' && parts[0] == 'upload' ||
           @type == 'users' && parts[0] == 'login' )
      @method = parts[0]
    elsif (has_list_query?)
      @method = parts[0] || 'view'
      @list_query = true
    else
      raise(NoListQuery, "@path=#@path, @type=#@type")
    end
    if @post and not @post.empty?
      bp = @post.find_all{|k,v| !valid_post?(k, v) }
      raise(BadPost, "@type=#@type, @method=#@method, @list_query=#@list_query, "+bp.inspect) unless bp.empty?
    elsif @get and not @get.empty?
      bg = @get.find_all{|k,v| !valid_get?(k, v) }
      raise(BadGet, "@type=#@type, @method=#@method, @list_query=#@list_query, "+bg.inspect) unless bg.empty?
    end
  end
  
end


class MuryuDispatch

  def self.dispatch(req)
    new.dispatch_request(req)
  end

  def get_handler(type)
    MuryuDispatch.const_get(type.to_class_name)
  end
  
  def dispatch_request(req)
    q = MuryuQuery.new(req)
    handler = get_handler(q.type)
    if q.list_query
      handler.__send__(q.method, q)
    else
      handler[q.key].__send__(q.method, q)
    end
  end
  
end

