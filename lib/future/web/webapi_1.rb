require 'jcode'
require 'kconv'
require 'digest/sha1'

$KCODE = 'u'

$NO_TILE_DRAWING = true

unless defined? QueryStringParser
  require 'future/search/search_query'
end
require 'future/database'
require 'future/models'
require 'future/metadata'
require 'future/imaging'
require 'future/web/memcachepool'
require 'builder'
require 'memcache'

require 'future/web/webapi_handlers'


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

  class NotFound < MuryuError
  end

  class BadMethod < MuryuError
  end
  
  class BadKey < MuryuError
  end
  
  class BadGet < MuryuError
  end
  
  class BadPost < MuryuError
  end
  
  attr_reader(:path, :type, :method, :key, :list_query, :get, :post, :cookies, :request_method, :query, :headers)
  attr_accessor(:session_id)
  
  class << self
    attr_accessor(:type_methods, :type_list_query, :type_keys, :type_method_get_validators, :type_method_post_validators)
  end

  uint = '(0|([1-9][0-9]*))'
  int = "((-|\\+)?#{uint})"
  ufloat = "((#{uint}(\.[0-9])?|0\.[0-9])[0-9]*)"
  float = "((-|\\+)?#{ufloat})"
  username = '([^<>/]{1,40})'
  password = '(.{6,40})'
  filename = '([^/]{1,200})'
  relative_path = "(#{username}/[0-9]{4}/[0-9]{2}-[0-9]{2}/#{filename})"
  items_query = '(.*)'
  itemkey = "(#{uint}|#{relative_path})"
  imagesize = "(full)"
  pagesize = "(2048|1024|128|64|32)"
  setname = '(.{1,80})'
  tagname = '(\S{1,80})'
  setkey = "(#{username}/#{setname})"
  groupname = setkey
  tile = "(x#{uint}y#{uint}z#{uint}(w#{uint}h#{uint})?)"
  boolean = '(true|false)'
  url = '(.*)'
  string = '(.*)'
  location = "(\\(#{float},#{float}\\))"
  mimetype = '([a-z]+/[0-9a-z._-]+)'
  date = '(-?[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} ([+-][0-9]{4})?)'
  color = '([0-9a-fA-F]{6})'
  file = Matcher.new(:[]){|o|
    o.is_a?(Hash) and o[:filename] and o[:tempfile]
  }
  any = Hash.new(Matcher.new{ true })
  
  def self.e(pattern)
    Regexp.new('\A'+pattern+'\Z', Regexp::MULTILINE, 'U')
  end
  
  def self.ee(pattern)
    Regexp.new('\A('+pattern+')?\Z', Regexp::MULTILINE, 'U')
  end
  

  self.type_keys = {
    'items' => e(itemkey),
    'files' => e(itemkey),
    'subfiles' => e(relative_path+"(/[0-9A-Za-z._-]*)?"),
    'sets' => e(setkey),
    'users' => e(username),
    'groups' => e(groupname),
    'tile' => e(tile),
    'tile_info' => e(tile)
  }

  list_of = lambda{|r|
    /\A\s*((#{r})\s*,\s*)*(#{r})\s*\Z/
  }
  elist_of = lambda{|r|
    /\A\s*(((#{r})\s*,\s*)*(#{r}))?\s*\Z/
  }

  json_array_of = lambda{|r, *a|
    count = a[0]
    if count
      "\\s*\\[\\s*((#{r})\\s*,\\s*){#{count-1}}(#{r})\\s*\\]\\s*"
    else
      "\\s*\\[\\s*((#{r})\\s*,\\s*)*(#{r})\\s*\\]\\s*"
    end
  }


  field_names = %w(image_index owner path deleted sha1_hash size source referrer created_at modified_at sets tags groups mimetype metadata all).join("|")

  up = {
    'username' => e(username),
    'password' => e(password),
    'password_hash' => e(password)
  }
  
  self.type_list_query = {
    'items' => {
      'q' => e(items_query),
      'first' => e(uint),
      'last' => e(uint),
      'time' => e(uint),
      'offset' => e(uint),
      'limit' => e(uint)
    },
    'files' => {
      'q' => e(items_query),
      'first' => e(uint),
      'last' => e(uint),
      'offset' => e(uint),
      'limit' => e(uint)
    },
    'sets' => {
      'name' => e(setname),
      'owner' => e(username)
    },
    'users' => {},
    'groups' => {
      'name' => e(groupname),
      'owner' => e(username)
    },
    'tile' => false,
    'tile_info' => {
      'q' => e(items_query),
      'time' => e(uint)
    }
  }
  
  self.type_method_get_validators = {
    'items' => {
      'view' => up,
      'image' => {'size' => e(imagesize) },
      'file' => up,
      'text' => up,
      'pdf' => up,
      'thumbnail' => up,
      'json' => {
        'columns' => list_of[field_names]
      }
    },
    'files' => {
      'page' => {
        'number' => e(uint),
        'size' => e(pagesize)
      },
      'view' => up,
      'item' => up
    },
    'subfiles' => {
      'view' => up
    },
    'sets' => {
      'view' => up,
      'json' => up
    },
    'users' => {
      'logout' => up,
      'view' => up,
      'json' => up,
      'register' => {}
    },
    'groups' => {
      'view' => up,
      'json' => up
    },
    'tile' => {
      'view' => {
        'q' => e(string),
        'color' => e(boolean),
        'layout' => e(string),
        'time' => e(int),
        'bgcolor' => e(color)
      }.merge(up)
    },
    'tile_info' => {
      'view' => {
        'q' => e(string),
        'color' => e(boolean),
        'time' => e(uint),
        'columns' => list_of[field_names],
        'bgcolor' => e(color),
        'tiles' => e(json_array_of[json_array_of[uint,3]])
      }.merge(up)
    }
  }


  item_edit = up.merge({
    'filename' => e(string),
    'source' => ee(url),
    'referrer' => ee(url),
    'sets' => ee(setname),
    'sets.new' => elist_of[setname],
    'groups' => ee(groupname),
    'groups.new' => elist_of[groupname],
    'tags' => elist_of[tagname],
    'year' => ee(string),
    'month' => ee(string),
    'day' => ee(string),
    'hour' => ee(string),
    'minute' => ee(string),
    'second' => ee(string),
    'metadata.title' => ee(string),
    'metadata.description' => ee(string),
    'metadata.publish_time' => ee(date),
    'metadata.publisher' => ee(string),
    'metadata.author' => ee(string),
    'metadata.album_art' => ee(string),
    'metadata.genre' => ee(string),
    'metadata.album' => ee(string),
    'metadata.tracknum' => ee(int),
    'metadata.location' => ee(location)
  })
  self.type_method_post_validators = {
    'items' => {
      'create' => any,
      'edit' => item_edit,
      'make_public' => up,
      'make_private' => up,
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
        'name' => e(setname),
        'groups' => ee(groupname),
        'groups.new' => elist_of[groupname]
      }.merge(up),
      'add_group' => {
        'name' => e(groupname),
        'can_modify' => e(boolean)
      },
      'remove_group' => {
        'name' => e(groupname)
      },
      'delete' => up,
      'undelete' => up
    },

    'users' => {
      'login' => up,
      'logout' => up,
      'create' => up,
      'edit' => {'new_password' => e(password)}.merge(up),
      'delete' => up,
      'set_preferences' => any,
      'delete_preferences' => any,
      'clear_preferences' => up,
      'set_workspace' => { 'name' => e(string) },
      'create_workspace' => { 'name' => e(string) },
      'delete_workspace' => { 'name' => e(string) },
    },
    
    'groups' => {
      'create' => {
        'name' => e(string),
        'public' => e(boolean)
      }.merge(up),
      'edit' => {
        'name' => e(string),
        'public' => e(boolean),
        'users' => ee(username),
        'users.new' => elist_of[username]
      }.merge(up),
      'add_member' => {
        'name' => e(username),
        'admin' => e(boolean)
      },
      'remove_member' => {
        'name' => e(username)
      },
      'delete' => up,
      'undelete' => up
    },

    'tile_info' => {
      'view' => {
        'q' => e(string),
        'color' => e(boolean),
        'time' => e(uint),
        'columns' => list_of[field_names],
        'bgcolor' => e(color),
        'tiles' => e(json_array_of[json_array_of[uint,3]])
      }.merge(up)
    }
  }
  
  def initialize(req)
    @get = req.get
    @post = req.post
    @request_method = req.request_method
    @query = @request_method == 'POST' ? @post : @get
    @headers = req.headers
    @cookies = req.cookies
    self.path = req.relative_path
  end

  def [](k)
    @headers[k]
  end
  
  def valid_key_pattern
    self.class.type_keys[@type]
  end
  
  def valid_method?(name)
    gv = self.class.type_method_get_validators[@type]
    pv = self.class.type_method_post_validators[@type]
    (gv and gv[name]) or (pv and pv[name])
  end
    
  def valid_type?
    self.class.type_method_get_validators.has_key?(@type) or
    self.class.type_method_post_validators.has_key?(@type)
  end
  
  def valid_key?(key)
    valid_key_pattern.match(key)
  end

  def valid_get?(key, val)
    validate('get', key, val)
  end
  
  def valid_post?(key, val)
    key == 'secret' or validate('post', key, val)
  end

  def supports_get?
    a = self.class.type_method_get_validators[@type]
    a and a[@method]
  end

  def supports_post?
    a = self.class.type_method_post_validators[@type]
    a and a[@method]
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
    parts = CGI.unescape(rest.to_s).split("/").reject{|s| s.empty? }
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
    elsif (parts[0] == 'create' || (@type == 'users' && parts[0] == 'login') )
      @method = parts[0]
    elsif (has_list_query?)
      @method = parts[0] || 'view'
      @list_query = true
    else
      raise(NoListQuery, "You tried to reach #@type/#@method, but #@type doesn't have a list query.")
    end
    if @request_method == 'POST' and supports_post?
      bp = @post.find_all{|k,v| !valid_post?(k, v) }
      raise(BadPost, "Bad POST query arguments for #@type/#@method (#{
        @list_query ? 'list query' : "target: #{@key or 'new'}"
      }): "+bp.map{|k,v| k + "=" + v.join(",") }.join(", ")) unless bp.empty?
    elsif @request_method == 'GET' and supports_get?
      bg = @get.find_all{|k,v| !valid_get?(k, v) }
      raise(BadGet, "Bad GET query arguments for #@type/#@method (#{
        @list_query ? 'list query' : "target: #{@key or 'new'}"
      }): "+bg.map{|k,v| k + "=" + v.join(",") }.join(", ")) unless bg.empty?
    else
      raise(BadMethod, "#@type/#@method doesn't respond to #@request_method")
    end
  end
  
end


MuryuResponse = Struct.new(:status, :content_type, :body, :headers)
class MuryuResponse
  def [](k)
    headers[k]
  end

  def []=(k,v)
    headers[k]=v
  end

  def cookies
    @cookies ||= Hash.new{|h,k| h[k] = [] }
  end

  def set_cookie(k,v)
    cookies[k] << v
  end
end

$PRINT_QUERY_PROFILE = false
$CACHE_INFO = true
$CACHE_TILES = false
$USE_DIPUS_TILE_INFO = true

module MuryuDispatch

  def self.dispatch(req)
    dispatch_request(req)
  end

  def self.get_handler(type)
    const_get(type.to_class_name)
  end

  def self.authenticate(req, res)
    un = req.query['username']
    tpw = req.query['password']
    pw = req.query['password_hash']
    if not pw and tpw
      pw = [Digest::SHA1.hexdigest(tpw.to_s+Future.salt).to_s]
    end
    cookies = req.cookies['future_session_id']
    cookies = [cookies].compact unless cookies.is_a?(Array)
    user = cookie = session_id = secret = nil
    if cookies.size > 0
      cookie = cookies.find{|c|
        session_id = c
        user = nil
        user_id, user_name, secret = Future.memcache.get("session-#{session_id}")
        if user_id
          user = Future::Users.new(user_id)
          user.instance_variable_set(:@name, user_name) if user_name
        else
          user = Future::Users.continue_session(session_id)
          Future.memcache.set("session-#{session_id}", [user.id, user.name, user.session.secret], 3600) if user
        end
        user
      }
      if cookie
        if !user or req.query['logout']
          if user
            user.logout
            user = nil
          end
          Future.memcache.delete("session-#{cookie}")
        end
      end
    end
    if un and pw and un != 'anonymous'
      if user
        user.logout
      end
      session_id = create_new_id
      user = Future::Users.login(un[0], pw[0], session_id)
      if user and user.name != 'anonymous'
        cookie = new_cookie = session_id
      else
        log_error "authentication failed for #{un[0]} (from #{req.headers["X-Real-Ip"]})"
      end
    end
    if req.request_method.downcase == 'get'
      if user and user.name != 'anonymous'
        res['Cache-Control'] = 'private'
      else
        res['Cache-Control'] = 'public'
      end
    end
    cookies.delete_at(cookies.index(cookie)) if cookies.index(cookie)
    if user and new_cookie
      res["Set-Cookie"] = "future_session_id=#{new_cookie};Domain=#{Future.domain};Path=/;Max-Age=#{86400*7};Version=1"
    elsif not user
      session_id = nil
    elsif req.request_method.downcase == 'post' and
    not (['users','items'].include?(req.type) and req.method == 'create') and
    not ((secret || (user.session && user.session.secret)) == req.post['secret'].to_s)
      raise(MuryuQuery::BadPost, "Invalid POST secret.")
    end
    [(user or Future::Users.anonymous), session_id]
  end
  
  # From cgi/session.rb
  def self.create_new_id
    require 'digest/md5'
    md5 = Digest::MD5::new
    now = Time::now
    md5.update(now.to_s)
    md5.update(String(now.usec))
    md5.update(String(rand(0)))
    md5.update(String($$))
    md5.update('foobar')
    md5.hexdigest
  end
  
  def self.time(msg)
    puts "#{Thread.current.telapsed} #{msg}" if $PRINT_QUERY_PROFILE
  end
  
  def self.dispatch_request(req)
    Thread.current.telapsed
    time("dispatch start")
    r = MuryuResponse.new
    r.status = 200
    r.content_type = 'text/html;charset=utf-8'
    r.body = ''
    r.headers = {}
    begin
      q = MuryuQuery.new(req)
      time("parsed")
      u,sid = authenticate(q,r)
      time("authenticated")
      q.session_id = sid
      handler = get_handler(q.type)
      time("got_handler")
      if not q.key
        handler.__send__(q.method, u, q, r)
      else
        handler[u, q.key].__send__(q.method, q, r)
      end
      time("handled")
    rescue MuryuQuery::BadMethod => e
      r.status = 405
      r.content_type = 'text/html'
      r.body = error(e,r.status.to_s+" Unsupported method")
    rescue MuryuQuery::BadKey, MuryuQuery::BadGet, MuryuQuery::BadPost => e
      r.status = 400
      r.content_type = 'text/html'
      r.body = error(e,r.status.to_s+" Bad request")
    rescue MuryuQuery::NoListQuery, MuryuQuery::UnknownType, MuryuQuery::NotFound => e
      r.status = 404
      r.content_type = 'text/html'
      r.body = error(e,r.status.to_s+" File not found")
    rescue => e
      r.status = 500
      r.content_type = 'text/html'
      r.body = error(e,r.status.to_s, true)
    end
    if r.content_type == 'application/json'
      r.content_type = 'text/plain'
      r.body = 'while(0){' << r.body << '}'
    end
    r
  end

  def self.error(e, s, print_backtrace = false)
    "
    <html>
      <head>
        <title>#{CGI.escapeHTML(s)}</title>
      </head>
      <body>
        <h1>#{CGI.escapeHTML(s)}</h1>
        <p>#{CGI.escapeHTML(e.message)}</p>
        #{ "<p>#{e.backtrace.map{|s| CGI.escapeHTML(s) }.join("<br/>")}</p>" if print_backtrace }
      </body>
    </html>"
  end

end


