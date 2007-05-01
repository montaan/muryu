#!/usr/bin/env ruby

MEMCACHE_SERVERS = ['127.0.0.1:11211']

require 'jcode'
require 'kconv'
$KCODE = 'u'

require 'webrick'
require 'future'
load 'future/search/search_query_parser.rb'
require 'builder'
require 'json'
require 'memcache'

$PRINT_QUERY_PROFILE = false
$CACHE_TILES = true

class StandardDateTime < DateTime
  def to_json(*a)
    strftime("new Date(\"%m/%d/%Y %H:%M:%S %z\")")
  end
end

class Time
  def to_json(*a)
    strftime("new Date(\"%m/%d/%Y %H:%M:%S %z\")")
  end
end

class Thread
  attr_accessor :servlet_target, :servlet_path, :servlet_root, :last_time,
    :servlet_target_path, :search_query, :session_id, :servlet_user, :request_time
    
  def telapsed
    t = self.last_time
    self.last_time = Time.now.to_f
    ms = (self.last_time - t) * 1000
    "[#{("#"*((ms*2).round)).rjust(16)[0,16]}] %.3fms" % [ms]
  end
  
end

class MemCachePool
  def initialize(servers, size=16)
    @queue = Queue.new
    size.times{ @queue.push(MemCache.new(servers)) }
    @local_cache = {}
    @timeouts = {}
    start_timeout_monitor
  end

  def get(a)
    lc = @local_cache[a]
    return lc if lc
    s = @queue.shift
    r = s.get(a)
    if r
      local_cache_set(a,r,60)
    end
    @queue.push(s)
    r
  end

  def set(*a)
    local_cache_set(*a)
    s = @queue.shift
    r = s.set(*a)
    @queue.push(s)
    r
  end

  def delete(a)
    @local_cache.delete(a)
    s = @queue.shift
    r = s.delete(a)
    @queue.push(s)
    r
  end

  private
  def local_cache_set(k, v, timeout=60)
    @timeouts[k] = timeout
    @local_cache[k] = v
  end

  def start_timeout_monitor
    @timeout_monitor = Thread.new{
      loop do
        sleep(1)
        @timeouts.each{|k,v|
          @timeouts[k] = v-1
        }
        @local_cache.delete_if{|k,v| @timeouts[k] < 0 }
      end
    } 
  end
  
end

$memcache = MemCachePool.new(MEMCACHE_SERVERS)


module Future
  
# API:
# 
# Non-namespaced / default-namespaced access:
# (groups default namespace is 'group', users handles user identity groups)
# 
# groups (= list)
# groups/create
# groups/foo_fighters      (= view)
# groups/foo_fighters/edit
# 
# groups/foo_fighters/users
# groups/foo_fighters/items
# groups/foo_fighters/sets
# groups/foo_fighters/tags
#
#
# Namespaced / hierarchical access:
#
# items/foo/2006/10-09/foo.jpg
# items/foo/2006/10-09/foo.jpg/edit
#
# items/foo/2006/10-09/foo.jpg/users
# items/foo/2006/10-09/foo.jpg/groups
# items/foo/2006/10-09/foo.jpg/sets
# items/foo/2006/10-09/foo.jpg/tags
# 
#
# Item -> file -mapping:
# 
# items/foo/2006/10-09/foo.jpg -> files/foo/2006/10-09/foo.jpg
# 
# 
# 

class Object
  def telapsed(t=Thread.current.last_time)
    Thread.current.last_time = Time.now.to_f
    (Thread.current.last_time - t)
  end
end

# do_add, etc primarily for Users, Groups, Sets, Items
module FutureServlet

  class WrapServlet < WEBrick::HTTPServlet::AbstractServlet
    delegate '@obj', :do_GET, :do_POST
    def initialize(obj)
      @obj = obj
    end
  end

  def get_instance(*a)
    WrapServlet.new(self)
  end
  
  def do_GET(req,res)
    handle_request(req,res)
  end
  
  def do_POST(req,res)
    if req.body
#       pp req.header
      nq = CGI.parse(req.body)
#       puts req.body
      nq.each{|k,v|
        req.query[k] = (v.size == 1 ? v[0] : v)
      }
    end
    handle_request(req,res)
  end

  def servlet_path_key
    :id
  end

  def servlet_uneditable_columns
    [:id, :owner_id, :created_at, :modified_at] | ((!servlet_target or servlet_target.writable_by(servlet_user)) ? [] : columns.keys)
  end

  def servlet_uneditable_column?(c)
    servlet_uneditable_columns.find{|ic| ic.to_s == c.to_s }
  end

  def servlet_invisible_columns
    [:id]
  end

  def servlet_invisible_column?(c)
    servlet_invisible_columns.find{|ic| ic.to_s == c.to_s }
  end

  @@mutex = Mutex.new
  delegate_accessor "Thread.current",
    :servlet_target, :servlet_path, :servlet_root, :servlet_target_path,
    :search_query, :session_id, :servlet_user, :request_time

  @@reqs = []
  @@log_mutex = Mutex.new
  
  def log_req val
    @@log_mutex.synchronize do
      @@reqs << val
      if @@reqs.size > 100
        oreqs = @@reqs
        @@reqs = []
        File.open("reqs.log", 'a'){|f| f.puts oreqs }
      end
    end
  end

  def telapsed
    Thread.current.telapsed
  end
  
  def handle_request(req, res)
    rt = Time.now.to_f
    self.request_time = rt
    Thread.current.last_time = rt
    DB::Conn.reserve do |conn|
      puts "#{telapsed} for DB::Conn.reserve" if $PRINT_QUERY_PROFILE
      Thread.current.conn = conn
      user_auth(req, res)
      puts "#{telapsed} for user auth" if $PRINT_QUERY_PROFILE
      self.servlet_root = req.script_name
      self.servlet_path, mode = File.split(req.path_info)
      unless servlet_modes.include? mode
        self.servlet_path = File.join(servlet_path, mode)
        mode = 'view'
      end
      servlet_path.gsub!(/^\//, '')
      self.servlet_target_path = File.join(servlet_root, servlet_path)
      if respond_to?(:rfind) and not servlet_path.empty?
        self.servlet_target = rfind(servlet_user,
          servlet_path_key => servlet_path,
          :columns => :all
        )
      else
        self.servlet_target = nil
      end
      parse_search_query(req) if respond_to?(:columns)
      mode = 'list' if ["/", ""].include?(req.path_info)
      __send__("do_#{mode}", req, res)
      Thread.current.conn = nil
    end
    sz = res.body.size
    log_req([rt, Time.now.to_f-rt, sz].join(" "))
  end

  def parse_search_query(req)
    qkeys = (req.query.keys & (columns.keys + ["sort"]))
    h = qkeys.map{|k| [k, [req.query[k].to_s]]}.to_hash
    words = req.query["text"].to_s.split(" ").map{|t| t.gsub(/\+/, ' ') }
    self.search_query = SearchQueryParser.tokens_and_words_to_query_hash(h, words)
  end
  
  def user_auth(req, res)
    un = req.query['username']
    pw = req.query['password']
    cookies = req.cookies.find_all{|c| c.name == 'future_session_id' }
    user = nil
    if cookies.size > 0
      cookies.each{|c| c.instance_variable_set(:@discard, true) }
      cookie = cookies.find{|cookie|
        self.session_id = cookie.value
        user = nil
        if user_id = $memcache.get("session-#{session_id}")
          user = Users.new(user_id)
        else
          user = Users.continue_session(session_id)
          $memcache.set("session-#{session_id}", user.id, 300) if user
        end
        user
      }
      if cookie
        cookie.instance_variable_set(:@discard, false)
        cookie.max_age = 3600 * 24 * 7
        if !user or req.query['logout']
          user.logout if user
          $memcache.delete("session-#{cookie.value}")
          cookie.instance_variable_set(:@discard, true)
          user = nil
        end
      end
      res.cookies.push *cookies
    end
    if un and pw
      if user
        user.logout
        cookie.instance_variable_set(:@discard, true)
      end
      self.session_id = create_new_id
      user = Users.login(un, pw, session_id)
      if user
        new_cookie = WEBrick::Cookie.new('future_session_id', session_id)
        new_cookie.max_age = 3600 * 24 * 7
        new_cookie.path = "/"
        res.cookies << new_cookie
      end
    end
    self.servlet_user = (user or Users.anonymous)
  end
  
  # From cgi/session.rb
  def create_new_id
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

  def servlet_modes
    ['create','edit','view','json','delete','undelete'] + sub_modes
  end

  def sub_modes
    []
  end

  def servlet_list_actions(req)
    if column? 'deleted'
      if req.query['deleted']
        [["Create new", File.join(servlet_target_path, "create")],
        ["List normal", servlet_target_path]
        ]
      else
        [["Create new", File.join(servlet_target_path, "create")],
        ["List deleted", '?deleted']
        ]
      end
    else
      [["Create new", File.join(servlet_target_path, "create")]]
    end
  end

  def servlet_view_actions(req)
    if servlet_target.writable_by(servlet_user)
      if column? 'deleted' and servlet_target.deleted
        [["Undelete", File.join(servlet_target_path, "undelete")]]
      else
        [["Delete", File.join(servlet_target_path, "delete")]]
      end
    else
      []
    end
  end

  def print_navigation_path(b)
    b.a("future", :href => File.split(servlet_root).first)
    b.text!("/")
    b.a(table_name, :href=> servlet_root)
  end

  def print_user_info(b)
    b.a(servlet_user.name, :href => "/users/#{servlet_user.name}")
    b.text!(" (")
    b.a("sign out", :href => "/users/logout")
    b.text!(")")
  end

  def servlet_list_rows(req)
    cols = req.query['columns'].to_s.split(",") & columns.keys
    cols = :all if cols.empty?
    q = {:order_by => servlet_path_key, :columns => cols}
    q.merge!(search_query) if search_query
    if column? 'deleted' and req.query['deleted']
      q[:deleted] = true
    end
    rfind_all(servlet_user, q)
  end

  def do_list(req,res)
    objs = servlet_list_rows(req)
    cols = req.query['columns'].to_s.split(",") & columns.keys
    cols = columns.keys if cols.empty?
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name) }
      b.body {
        b.h1 { print_navigation_path(b) }
        b.p { print_user_info(b) }
        b.h2("Actions")
        b.ul {
          servlet_list_actions(req).each{|name, href|
            b.li { b.a(name, :id => 'action_link', :href => href) }
          }
        }
        b.table(:border => 1){
          b.tr{
            b.td{ b.h3(servlet_path_key.to_s) }
            cols.each{|c,cl| b.td{ b.h3("#{c}") } unless c.to_s == servlet_path_key.to_s or servlet_invisible_column?(c)}
          }
          objs.each{|obj|
            b.tr {
              b.td{ b.a(obj[servlet_path_key].to_s, :href => File.join(servlet_root, obj[servlet_path_key].to_s)) }
              cols.each{|c,cl| b.td(obj[c]) unless c.to_s == servlet_path_key.to_s or servlet_invisible_column?(c) }
            }
          }
        }
      }
    end
  end

  def do_delete(req,res)
    servlet_target.rdelete(servlet_user)
    res.status = 302
    res['location'] = servlet_root
  end

  def do_undelete(req,res)
    servlet_target.rundelete(servlet_user)
    res.status = 302
    res['location'] = servlet_root
  end

  def do_create(req,res)
    unless req.query.empty?
      servlet_create(req)
      res.status = 302
      res['location'] = servlet_root
    else
      res.body = Builder::XmlMarkup.new.html do |b|
        b.head { b.title(table_name)
          b.style(:type => 'text/css'){
            b.comment!(%Q(
              .column_value {
                font-family: Arial, Helvetica;
                font-size: 10pt;
              }
            ))
          }
        }
        b.body {
          b.h1 {
            print_navigation_path(b)
            b.text!("/create")
          }
          b.p { print_user_info(b) }
          b.form(:method => 'POST'){
            columns.each{|c,cl|
              if !servlet_uneditable_column? c
                b.h3("#{c} (#{cl})")
                b.p {
                  b.input(:class => "column_value", :id => c, :type => 'text', :name => c)
                }
              end
            }
            b.p { b.input(:type => 'submit', :value => 'Create new') }
          }
        }
      end
    end
  end
  
  def do_edit(req,res)
    servlet_target_edit(req)
    res.status = 302
    res['location'] = servlet_target_path
  end
  
  def do_view(req,res)
    vals = columns.map{|c,cl| servlet_target[c] }
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name)
        b.style(:type => 'text/css'){
          b.comment!(%Q(
            .edit_input{
              display: none;
              font-family: Arial, Helvetica;
              font-size: 10pt;
            }
            .column_value {
              font-family: Arial, Helvetica;
              font-size: 10pt;
            }
            .editable:after {
              content: "edit";
              color: blue;
              text-decoration: underline;
              margin-left:6px;
              cursor: pointer;
            }
          ))
        }
        b.script {
          b.comment!(%Q(
            function makeEditable(i,s) {
              i.style.width = Math.max(parseInt(s.offsetWidth) + 20, 200) + 'px'
              i.style.marginTop = '-3px'
              i.style.marginBottom = '-3px'
              i.style.marginLeft = '-2px'
              s.style.display = 'none'
              i.style.display = 'inherit'
              i.focus()
            }
            function makeNotEditable(i,s) {
              i.style.marginTop = i.style.marginBottom = i.style.marginLeft = null
              i.style.display = 'none'
              s.innerHTML = i.value
              s.style.display = 'inline'
            }
            function initInput(i) {
              var s = document.getElementById("div_" + i.id)
              i.addEventListener("blur", function(){ makeNotEditable(i,s) }, false)
              s.addEventListener("click", function(){ makeEditable(i,s) }, false)
            }
            window.addEventListener("load", function(){
              var inputs = document.getElementsByTagName("input")
              for(var j=0; j<inputs.length; j++) {
                var i = inputs[j]
                if (i.className == 'edit_input') {
                  initInput(i)
                }
              }
              document.getElementById('edit_link').style.display = 'none'
            }, false)
          //))
        }
      }
      b.body {
        b.h1 {
          print_navigation_path(b)
          b.text!("/")
          b.a(servlet_path, :href => servlet_target_path)
        }
        b.p { print_user_info(b) }
        b.h2("Actions")
        b.ul {
          servlet_view_actions(req).each{|name, href|
            b.li { b.a(name, :id => 'action_link', :href => href) }
          }
        }
        b.form(:method => 'POST', :action => File.join(servlet_target_path, "edit")){
          columns.each{|c,cl|
            b.h3("#{c} (#{cl})")
            b.p {
              if servlet_uneditable_column? c
                b.span(servlet_target[c], :class => "column_value", :id => "div_#{c}")
              else
                b.span(servlet_target[c], :class => "column_value editable", :id => "div_#{c}")
                b.input(:class => "edit_input", :id => c, :type => 'text', :name => c, :value => servlet_target[c])
              end
            }
          }
          b.p { b.input(:type => 'submit', :value => 'Save changes' )}
        }
        b.p { b.a("Edit", :id => 'edit_link', :href => File.join(servlet_target_path, "edit")) }
      }
    end
  end

  def do_json(req, res)
    res['Content-type'] = 'text/plain'
    if servlet_target
      h = {}
      columns.map{|c, cl|
        h[c] = servlet_target[c] unless servlet_invisible_column?(c)
      }
      res.body = h.to_json
    else
      objs = servlet_list_rows(req)
      cols = req.query['columns'].to_s.split(",") & columns.keys
      cols = columns.keys if cols.empty?
      p columns, cols
      cols.delete_if{|c| servlet_invisible_column?(c) }
      res.body = objs.map{|o|
        cols.map{|c| [c, o[c]] }.to_hash
      }.to_json
    end
  end

  def servlet_create(req)
    edits = req.query.find_all{|k,v|
      column? k and !servlet_uneditable_column?(k)
    }
    rfind_or_create(servlet_user, edits.to_hash)
  end

  def servlet_target_edit(req)
    servlet_target.write(servlet_user) do
      DB.transaction do
        edits = req.query.find_all{|k,v|
          column? k and servlet_target[k].to_s != v and
          not servlet_uneditable_column?(k)
        }
#         pp edits
        edits.each{|k,v|
          servlet_target[k] = v
        }
        servlet_target[:modified_at] = Time.now.to_s if column?('modified_at')
        new_path = req.query[servlet_path_key.to_s]
        self.servlet_target_path = File.join(servlet_root, new_path) if new_path
      end
    end
  end
  
  def do_echo(req, res)
    res['Content-type'] = 'text/plain'
    res.body = (caller(0)[0,1] + ['', req.inspect.gsub(", ",",\n  ")]).join("\n")
  end

end


class Tile
extend FutureServlet

  class << self
    def servlet_modes
      []
    end

    delegate "Items", :columns

    def parse_search_query(req)
      self.search_query = SearchQueryParser.parse_query(req.query['q'].to_s, Items.columns)
    end
    
    def do_view(req,res)
      tile_start = Time.now.to_f
      puts "#{telapsed} for rest of handle_request" if $PRINT_QUERY_PROFILE
      res['Content-type'] = 'image/jpeg'
      x,y,z,w,h = parse_tile_geometry(servlet_path)
      color = (req.query['color'].to_s != 'false')
      bgcolor = (req.query.has_key?('bgcolor') ?
                  req.query['bgcolor'].to_s[0,6] : false)
      key = [servlet_user.id, servlet_path, color, bgcolor, search_query].join("::")
      puts "#{Thread.current.telapsed} for tile arg parsing" if $PRINT_QUERY_PROFILE
      tile = $memcache.get(key) if $CACHE_TILES
      puts "#{Thread.current.telapsed} for memcache get" if $PRINT_QUERY_PROFILE
      unless tile
        tile = Tiles.read(servlet_user, search_query, :rows, x, y, z, w, h,
                          color, bgcolor)
        puts "#{Thread.current.telapsed} for creating a JPEG" if $PRINT_QUERY_PROFILE
        Thread.new { $memcache.set(key, tile, 300) } if tile and $CACHE_TILES
      end
      if tile
        res.body = tile
      else
        res.status = 302
        res['location'] = '/empty.jpg'
      end
      puts "Tile time: #{"%.3fms" % [1000 * (Time.now.to_f - tile_start)]}" if $PRINT_QUERY_PROFILE
      puts "Total time: #{"%.3fms" % [1000 * (Time.now.to_f - request_time)]}" if $PRINT_QUERY_PROFILE
      puts
    end
  
    def do_list(req,res)
      res['Content-type'] = 'text/plain'
      res.status = 404
      res.body = 'File not found'
    end

    def parse_tile_geometry(str)
      ts = str.scan(/[a-z][-+]?[0-9]+/i).map{|t| [t[0,1], t[1..-1]] }.to_hash
      x = ts['x'].to_i
      y = ts['y'].to_i
      z = ts['z'].to_i
      w = (ts['w'] || 256).to_i
      h = (ts['h'] || 256).to_i
      [x,y,z,w,h]
    end
  end

end


class TileInfo
extend FutureServlet

  class << self
    def servlet_modes
      []
    end

    delegate "Items", :columns

    def parse_search_query(req)
      self.search_query = SearchQueryParser.parse_query(req.query['q'].to_s, Items.columns)
    end
    
    def do_view(req,res)
      res['Content-type'] = 'text/plain'
      x,y,z,w,h = Tile.parse_tile_geometry(servlet_path)
      sq = self.search_query.clone
      if z < 4
        res.body = [].to_json
        return
      end
      key = [servlet_user.id, servlet_path, search_query].join("::")
      jinfo = $memcache.get(key)
      unless jinfo
        if z >= 4
          sq[:columns] ||= []
          sq[:columns] << 'path'
        end
        if z >= 7
  #         sq['columns'].push(*['metadata.width', 'metadata.height'])
        end
        if z >= 8
  #         sq['columns'].push(*['owner.name', 'metadata'])
        end
        puts "#{telapsed} for tile_info init" if $PRINT_QUERY_PROFILE
        info = Tiles.info(
          servlet_user, sq,
          :rows, x, y, z, w, h
        ).to_a.map do |iind,((x,y,sz), info)|
          {:image_index => iind, :x => x, :y => y, :sz => sz, :info => info}
        end
        puts "#{telapsed} for fetching tile info" if $PRINT_QUERY_PROFILE
        jinfo = info.to_json
        puts "#{telapsed} for tile info jsonification" if $PRINT_QUERY_PROFILE
        $memcache.set(key, jinfo, 300)
      end
      res.body = jinfo
      puts "Total tile_info time: #{"%.3fms" % [1000 * (Time.now.to_f - request_time)]}" if $PRINT_QUERY_PROFILE
    end
  
    def do_list(req,res)
      res['Content-type'] = 'text/plain'
      res.body = {
        "maxZoom" => 15,
        "title" => servlet_user.name + ' ' + req.query['q'].to_s
      }.to_json
    end
  end

end


class Files
extend FutureServlet

  def self.table_name
    'files'
  end

  def self.do_list(req, res)
    objs = Items.rfind_all(servlet_user, :order_by => :path)
    cols = ['path']
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name) }
      b.body {
        b.h1 {
          print_navigation_path(b)
        }
        b.table(:border => 1){
          objs.each{|obj|
            b.p { b.a(obj['path'].to_s, :href => File.join(servlet_root, obj['path'].to_s)) }
          }
        }
      }
    end
  end

  def self.do_list(req,res)
  end

  def self.do_view(req, res)
    if servlet_path =~ /^[0-9]+$/
      item = Items.rfind(servlet_user, :image_index => servlet_path)
    else
      item = Items.rfind(servlet_user, :path => servlet_path)
    end
    if item
      res['Content-type'] = item.major + "/" + item.minor
      res.body = item.read
    else
      res['Content-type'] = 'text/html'
      res.body = "<html><body> File not found </body></html>"
      res.status = 404
    end
  end
  
  def self.servlet_modes
    ['items']
  end

end


class Subfiles
extend FutureServlet
  def self.handle_request(req, res)
    rt = Time.now.to_f
    self.request_time = Time.now.to_f
    DB::Conn.reserve do |conn|
      Thread.current.conn = conn
      user_auth(req, res)
      spl = req.path_info.split("/")
      path = spl[0,5].join("/")[1..-1]
      rest = spl[5..-1].join("/")
      item = Items.rfind(servlet_user, :path => path)
      p [path, rest]
      if item
        ip = File.split(item.internal_path).first
        sp = rest.gsub(/\A\.*\/|(\/\.\.\/)|(\/\.\.\Z)/, '')
        fn = File.join(ip, sp)
        if fn.index(File.dirname(ip)) == 0
          if File.directory?(fn)
            res.status = 403
            res.body = "<html><body> No directory listings </body></html>"
          else
            res.body = File.read(fn)
          end
        else
          res.status = 404
          res.body = "<html><body> File not found </body></html>"
        end
      else
        res.status = 404
        res.body = "<html><body> File not found </body></html>"
      end
      Thread.current.conn = nil
    end
    sz = res.body.size
    log_req([rt, Time.now.to_f-rt, sz].join(" "))
  end
end


class Mimetypes
extend FutureServlet

  class << self
    def modes
      ['json']
    end

    def do_view(req,res)
      do_list(req,res)
    end

    def do_list(req,res)
      do_json(req,res)
    end

    def do_json(req,res)
      res['Content-type'] = 'text/plain'
      res.body = find_all.map{|t| t.major + "/" + t.minor }.to_json
    end
  end

end


class Items
extend FutureServlet

  class << self
    def sub_modes
      ['owner','file','groups','tags','sets','thumbnail','upload','purge']
    end
    
    def servlet_view_actions(req)
      if servlet_target.writable_by(servlet_user)
        if column? 'deleted' and servlet_target.deleted
          if servlet_target.sha1_hash
            [["Undelete", File.join(servlet_target_path, "undelete")],
             ["Purge", File.join(servlet_target_path, "purge")]
            ]
          else
            []
          end
        else
          [["Delete", File.join(servlet_target_path, "delete")],
           ["Purge", File.join(servlet_target_path, "purge")]
          ]
        end
      else
        []
      end
    end

    def servlet_path_key
      :path
    end

    def parse_search_query(req)
      self.search_query = SearchQueryParser.parse(req.query['q'].to_s)
    end
    
    def servlet_uneditable_columns
      super | ['modified_at', 'created_at', 'size',
               'sha1_hash', 'image_index', 'metadata_id',
               'internal_path', 'path']
    end

    def servlet_invisible_columns
      super | ['internal_path']
    end

    def do_json(req,res)
      if servlet_path =~ /^[0-9]+$/
        self.servlet_target = rfind(servlet_user, :image_index => servlet_path)
      end
      return false unless servlet_target
      h = servlet_target.to_hash
      %w(mimetype_id owner_id metadata_id internal_path).each{|k| h.delete(k)}
      h[:groups] = servlet_target.groups.map{|g| g.name }
      h[:sets] = servlet_target.sets.map{|g| g.name }
      h[:tags] = servlet_target.tags.map{|g| g.name }
      h[:owner] = servlet_target.owner.name
      h[:metadata] = servlet_target.metadata.to_hash
      h[:mimetype] = servlet_target.mimetype
      h[:writable] = !!servlet_target.writable_by(servlet_user)
      h[:emblems] = [
        ['e', 'FUNNY HATS!! - £4.99 from eBay.co.uk', 'http://www.ebay.co.uk'],
        ['euro', 'Rocket Ship - 8.49€ from Amazon.de', 'http://www.amazon.com'],
        ['location', 'Bavaria, Germania', 'http://maps.google.com']
      ]
      res.body = h.to_json
    end

    def metadata_editable_column?(k)
      ['title', 'author', 'publisher', 'publish_time', 'description',
       'location', 'genre', 'album', 'tracknum', 'album_art']
    end
    
    def servlet_target_edit(req)
      if req.query.has_key?('filename')
        fn = req.query['filename']
        servlet_target.write(servlet_user) do
          parts = servlet_target.path.split("/")
          basename = parts.last
          baseparts = basename.split(".")
          if baseparts[0..-2].join(".") != fn
            newname = fn.gsub(/[^a-z0-9_.,-]/, "_") + "." + baseparts.last
#             p ['new_path', parts[0..-2].join("/") + "/" + newname]
            servlet_target.path = parts[0..-2].join("/") + "/" + newname
          end
        end
      end
      if req.query.has_key?('tags')
        tags = req.query['tags'].to_s.split(",").map{|t|t.strip}
        unless tags.empty?
          servlet_target.rset_tags(servlet_user, tags)
        end
      end
      if req.query.has_key?('groups')
        gs = req.query['groups']
        gs = [gs] unless gs.is_a?(Array)
        servlet_target.rset_groups(servlet_user, gs)
      end
      if req.query.has_key?('sets')
        gs = req.query['sets']
        gs = [gs] unless gs.is_a?(Array)
        servlet_target.rset_sets(servlet_user, gs)
      end
      if req.query.has_key?('groups.new')
        gs = req.query['groups.new'].to_s.split(",")
        unless gs.empty?
          servlet_target.write(servlet_user) do
            gs.each do |g|
              servlet_target.add_group(Groups.rfind_or_create(servlet_user, :name => g.strip))
            end
          end
        end
      end
      if req.query.has_key?('sets.new')
        gs = req.query['sets.new'].to_s.split(",")
        unless gs.empty?
          servlet_target.write(servlet_user) do
            gs.each do |g|
              servlet_target.add_set(Sets.rfind_or_create(servlet_user, :name => g.strip))
            end
          end
        end
      end
      super
      servlet_target.write(servlet_user) do
        metadata_fields = req.query.keys.find_all{|k|
          k.split(".").first == 'metadata'
        }.map{|k| [k.split(".")[1], req.query[k]] }.find_all{|k,v|
          metadata_editable_column?(k)
        }
        DB.transaction do
          edits = metadata_fields.find_all{|k,v|
            servlet_target.metadata[k].to_s != v
          }
#           pp edits
          edits.each{|k,v|
            servlet_target.metadata[k] = v
          }
          servlet_target[:modified_at] = Time.now.to_s if column?('modified_at')
        end
      end
    end
    
    def do_list(req,res)
    end

    def do_file(req, res)
      return unless servlet_target
      res['Content-type'] = servlet_target.major + "/" + servlet_target.minor
      res.body = File.read(servlet_target.internal_path)
    end

    def do_owner(req,res)
      return unless servlet_target
      res.body = {:name => servlet_target.owner['name']}.to_json
    end

    def do_groups(req,res)
      return unless servlet_target
      res.body = servlet_target.groups.map{|g| {:name => g.name, :namespace => g.namespace}}.to_json
    end

    def do_tags(req, res)
      return unless servlet_target
      res.body = servlet_target.tags.map{|g| {:name => g.name, :namespace => g.namespace}}.to_json
    end

    def do_sets(req, res)
      return unless servlet_target
      res.body = servlet_target.sets.map{|g| {:name => g.name, :namespace => g.namespace}}.to_json
    end

    def do_thumbnail(req, res)
      if servlet_target
        res['Content-type'] = 'image/png'
        res.body = servlet_target.thumbnail.read
      end
    end

    def do_purge(req, res)
      servlet_target.rpurge(servlet_user)
    end

    def do_delete(req, res)
      servlet_target.rdelete(servlet_user)
    end
    
    def do_undelete(req, res)
      servlet_target.rundelete(servlet_user)
      Tiles.module_eval do
        @@indexes.clear
        @@infos.clear
      end
    end
    
    ### FIXME implement compressed and remote_compressed uploads.
    def do_create(req, res)
    p req.query
      if servlet_user != Users.anonymous
        common_fields = {
          :groups => req.query['groups'],
          :public => req.query['public'],
          :sets => req.query['sets'],
          :tags => req.query['tags']
        }
        common_fields.delete_if{|k,v| v.nil? or v.empty? }
        common_fields[:user] = servlet_user
        urls, texts, uploads, compressed, compressed_urls, sources, referrers = (
          ['url', 'text', 'upload',
          'compressed', 'remote_compressed',
          'source', 'referrer'
          ].map{|pat| req.query.keys.grep(/^#{pat}[0-9]*$/).
                      find_all{|k| req.query[k] and not req.query[k].empty? } }
        )
        unless [urls, texts, uploads, compressed, compressed_urls].all?{|k| k.empty?}
          urls.each{|u|
            num = u.scan(/[0-9]+/)[0]
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:source] = req.query[u]
            f[:referrer] = req.query[referrer] if referrer
            Uploader.upload(common_fields.merge(f))
          }
          texts.each{|u|
            num = u.scan(/[0-9]+/)[0]
            source = sources.find{|r| r.scan(/[0-9]+/)[0] == num }
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:text] = req.query[u]
            f[:source] = req.query[source] if source
            f[:referrer] = req.query[referrer] if referrer
            Uploader.upload(common_fields.merge(f))
          }
          uploads.each{|u|
            num = u.scan(/[0-9]+/)[0]
            source = sources.find{|r| r.scan(/[0-9]+/)[0] == num }
            referrer = referrers.find{|r| r.scan(/[0-9]+/)[0] == num }
            f = {}
            f[:filename] = 'unnamed'
            f[:io] = req.query[u]
            f[:source] = req.query[source] if source
            f[:referrer] = req.query[referrer] if referrer
            Uploader.upload(common_fields.merge(f))
          }
        end
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
        res['location'] = '/items'
      end
    end

    def do_list(req, res)
      res.body = <<-EOF
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
      EOF
    end

  end

end


class Thumbnails
extend FutureServlet

  class << self
  
    def table_name
      'thumbnails'
    end

    def do_list(req, res)
    end

    def do_view(req, res)
      if servlet_path =~ /^[0-9]+$/
        item = Items.rfind(servlet_user, :image_index => servlet_path)
      else
        item = Items.rfind(servlet_user, :path => servlet_path)
      end
      if item
        res['Content-type'] = 'image/png'
        res.body = item.thumbnail.read
      end
    end
    
    def servlet_modes
      []
    end

  end

end


class Users
extend FutureServlet

  class << self
    def servlet_list_actions(req)
      [
        ["Register new account", File.join(servlet_target_path, "create")],
        ["Sign in", File.join(servlet_target_path, "login")],
        ["Sign out", File.join(servlet_target_path, "logout")]
      ]
    end
  
    def sub_modes
      ['files','items','groups','tags','sets', 'login', 'logout']
    end

    def servlet_path_key
      :name
    end

    def servlet_invisible_columns
      super + [:password]
    end

    def do_login(req,res)
      if servlet_user != Users.anonymous
        res.status = 302
        res['location'] = '/'
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Already logged in") }
          b.body {
            b.h1 { print_navigation_path(b) }
            b.h2("Welcome back, #{servlet_user.name}!")
            b.a(:href => 'logout') { b.h2("Log out?") }
          }
        end
      elsif req.query['username']
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Failed to log in.") }
          b.body {
            b.h1 { print_navigation_path(b) }
            b.h2("Login failed, please try again.")
            b.p { b.a("Register new account", :href=>'create') }
            login_form(b)
          }
        end
      else
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Log in") }
          b.body {
            b.h1 { print_navigation_path(b) }
            b.h2("Come on in!")
            b.p { b.a("Register new account", :href=>'create') }
            login_form(b)
          }
        end
      end
    end

    def do_logout(req,res)
      servlet_user.logout if servlet_user
      user_auth(req, res)
      do_login(req,res)
      res.status = 302
      res['location'] = '/'
    end

    def do_create(req,res)
      un = req.query['username']
      pw = req.query['password']
      if un and pw
        servlet_user.logout if servlet_user
        if (not find(:name => un)) and servlet_user = register(un, pw)
          user_auth(req, res)
          res.body = Builder::XmlMarkup.new.html do |b|
            b.head { b.title("Registered new account!") }
            b.body {
              b.h1 { print_navigation_path(b) }
              b.h2( "Welcome aboard, #{un}! We hope you enjoy the ride!" )
            }
          end
        else
          res.body = Builder::XmlMarkup.new.html do |b|
            b.head { b.title("Registration failed") }
            b.body {
              b.h1 { print_navigation_path(b) }
              b.h2("Failed to register account, someone is already using '#{un}'.")
              b.h2("Please try another name.")
              registration_form(b)
            }
          end
        end
      else
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Registering account.") }
          b.body {
            b.h1 { print_navigation_path(b) }
            b.h2('Register')
            registration_form(b)
          }
        end
      end
    end

    def registration_form(b)
      b.form(:method => 'POST') {
        b.h3("Username")
        b.input(:type => 'text', :name => 'username')
        b.h3("Password")
        b.input(:type => 'password', :name => 'password')
        b.br
        b.input(:type => 'submit', :value => 'Register')
      }
    end
    
    def login_form(b)
      b.form(:method => 'POST') {
        b.h3("Username")
        b.input(:type => 'text', :name => 'username')
        b.h3("Password")
        b.input(:type => 'password', :name => 'password')
        b.br
        b.input(:type => 'submit', :value => 'Log in')
      }
    end
    
  end

end


class Sets
extend FutureServlet

  def self.servlet_uneditable_columns
    super | [:namespace, :deleted]
  end

  def self.sub_modes
    ['files','users','groups','tags','sets']
  end

  def self.servlet_invisible_columns
    super | [:owner_id]
  end

  def self.do_json(req,res)
    res['Content-type'] = 'text/plain'
    if servlet_target
      h = {}
      columns.map{|c, cl|
        h[c] = servlet_target[c] unless servlet_invisible_column?(c)
      }
      h['owner'] = servlet_target.owner.name
      res.body = h.to_json
    else
      req.query['columns'] = 'name'
      res.body = servlet_list_rows(req).map{|c| c.name }.to_json
    end
  end

end


class Groups
extend FutureServlet

  def self.servlet_uneditable_columns
    super | [:namespace]
  end

  def self.servlet_invisible_columns
    super | [:owner_id]
  end

  def self.sub_modes
    ['files','users','items','tags','sets']
  end

  def self.do_json(req,res)
    res['Content-type'] = 'text/plain'
    if servlet_target
      h = {}
      columns.map{|c, cl|
        h[c] = servlet_target[c] unless servlet_invisible_column?(c)
      }
      h['owner'] = servlet_target.owner.name
      res.body = h.to_json
    else
      req.query['columns'] = 'name'
      res.body = servlet_list_rows(req).map{|c| c.name }.to_json
    end
  end

end


end


