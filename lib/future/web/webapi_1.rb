require 'jcode'
require 'kconv'
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
  
  attr_reader(:path, :type, :method, :key, :list_query, :get, :post, :cookies, :query, :session_id)

  class << self
    attr_accessor(:type_methods, :type_list_query, :type_keys, :type_method_get_validators, :type_method_post_validators)
  end
  
  self.type_methods = {
    'items' => %w(create json edit delete undelete purge view thumbnail file make_public make_private),
    'files' => %w(view item),
    'sets' => %w(create json edit delete undelete view),
    'users' => %w(create register login logout json edit delete purge view set_preferences delete_preferences clear_preferences create_workspace delete_workspace set_workspace),
    'groups' => %w(create json edit delete undelete view),
    'tile' => %w(view),
    'tile_info' => %w(view)
  }

  uint = '(0|([1-9][0-9]*))'
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
  tile = "(x#{uint}y#{uint}z#{uint})"
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
  any = Hash.new(Matcher.new{ true })
  
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
    'groups' => false,
    'tile' => false,
    'tile_info' => {
      'q' => e(items_query),
      'time' => e(uint)
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
      'logout' => up,
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
      'create' => item_edit.merge({
        'remote_file' => e(url),
        'remote_archive' => e(url),
        'local_file' => file,
        'local_archive' => file
      }),
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
        'name' => e(setname)
      }.merge(up),
      'delete' => up,
      'undelete' => up
    },
    'users' => {
      'login' => up,
      'logout' => up,
      'create' => up,
      'edit' => {'new_password' => e(password)}.merge(up),
      'delete' => up,
      'undelete' => up,
      'purge' => up,
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
        'public' => e(boolean)
      }.merge(up),
      'delete' => up,
      'undelete' => up
    }
  }
  
  def initialize(req,session_id)
    @get = req.get
    @post = req.post
    @request_method = req.request_method
    @session_id = session_id
    @query = @request_method == 'POST' ? @post : @get
    @headers = req.headers
    @cookies = req.cookies
    self.path = req.relative_path
  end

  def [](k)
    @headers[k]
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

  def supports_get?
    self.class.type_method_get_validators[@type][@method]
  end

  def supports_post?
    self.class.type_method_post_validators[@type][@method]
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
      }): "+bp.map{|k,v| k + " => " + v.join(",") }.join(", ")) unless bp.empty?
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
$CACHE_TILES = true

module MuryuDispatch

  def self.dispatch(req)
    dispatch_request(req)
  end

  def self.get_handler(type)
    const_get(type.to_class_name)
  end

  def self.authenticate(req, res)
    un = req.post['username'] || req.get['username']
    pw = req.post['password'] || req.get['password']
    cookies = req.cookies['future_session_id']
    cookies = [cookies].compact unless cookies.is_a?(Array)
    user = cookie = session_id = nil
    if cookies.size > 0
      cookie = cookies.find{|c|
        session_id = c
        user = nil
        user_id, user_name = Future.memcache.get("session-#{session_id}")
        if user_id
          user = Future::Users.new(user_id)
          user.instance_variable_set(:@name, user_name) if user_name
        else
          user = Future::Users.continue_session(session_id)
          Future.memcache.set("session-#{session_id}", [user.id, user.name], 3600) if user
        end
        user
      }
      if cookie
        if !user or req.post['logout'] or req.get['logout']
          if user
            user.logout
            user = nil
          end
          Future.memcache.delete("session-#{cookie}")
        end
      end
    end
    if un and pw
      if user
        user.logout
      end
      session_id = create_new_id
      user = Future::Users.login(un[0], pw[0], session_id)
      if user and user.name != 'anonymous'
        cookie = new_cookie = session_id
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
      res["Set-Cookie"] = "future_session_id=#{new_cookie}; Path=/; Max-Age=#{86400*7}; Version=1"
    elsif cookies.size > 0
      session_id = nil
    end
    if cookies.size > 0
      dc = cookies.map{|c| "future_session_id=#{c}; Path=/; Max-Age=0; Version=1" }.join(",")
      if res["Set-Cookie"]
        res["Set-Cookie"] += ","+dc
      else
        res["Set-Cookie"] = dc
      end
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
  
  def self.time(t0, msg)
    return t0 unless $PRINT_QUERY_PROFILE
    t1 = Time.now.to_f
    puts " #{(t1-t0) * 1000}\t: #{msg}"
    t1
  end
  
  def self.dispatch_request(req)
    t0 = time(0, "dispatch start")
    r = MuryuResponse.new
    r.status = 200
    r.content_type = 'text/html'
    r.body = ''
    r.headers = {}
    begin
      u,sid = authenticate(req,r)
      t0 = time(t0, "authenticated")
      q = MuryuQuery.new(req, sid)
      t0 = time(t0, "parsed")
      handler = get_handler(q.type)
      t0 = time(t0, "got_handler")
      if not q.key
        handler.__send__(q.method, u, q, r)
      else
        handler[u, q.key].__send__(q.method, q, r)
      end
      t0 = time(t0, "handled")
    rescue MuryuQuery::BadMethod => e
      r.status = 405
      r.body = error(e,r.status.to_s+" Unsupported method")
    rescue MuryuQuery::BadKey, MuryuQuery::BadGet, MuryuQuery::BadPost => e
      r.status = 400
      r.body = error(e,r.status.to_s+" Bad request")
    rescue MuryuQuery::NoListQuery, MuryuQuery::UnknownType, MuryuQuery::NotFound => e
      r.status = 404
      r.body = error(e,r.status.to_s+" File not found")
    rescue => e
      r.status = 500
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


