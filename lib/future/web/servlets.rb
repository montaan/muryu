#!/usr/bin/env ruby
require 'webrick'
require 'future'
load 'future/search/search_query_parser.rb'
require 'builder'
require 'json'


class StandardDateTime < DateTime
  def to_json(*a)
    strftime("new Date(\"%m/%d/%Y %H:%M:%S %z\")")
  end
end


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
    handle_request(req,res)
  end

  def servlet_path_key
    :id
  end

  def servlet_uneditable_columns
    [:id, :owner_id, :created_at, :modified_at] | ((!@servlet_target or @servlet_target.writable_by(@servlet_user)) ? [] : columns.keys)
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

  def handle_request(req, res)
    @@mutex.synchronize do
      user_auth(req, res)
      @servlet_root = req.script_name
      @servlet_path, mode = File.split(req.path_info)
      unless servlet_modes.include? mode
        @servlet_path = File.join(@servlet_path, mode)
        mode = 'view'
      end
      @servlet_path.gsub!(/^\//, '')
      @servlet_target_path = File.join(@servlet_root, @servlet_path)
      if respond_to?(:rfind) and not @servlet_path.empty?
        @servlet_target = rfind(@servlet_user,
          servlet_path_key => @servlet_path,
          :columns => :all
        )
      else
        @servlet_target = nil
      end
      if respond_to?(:columns)
        qkeys = (req.query.keys & (columns.keys + ["sort"]))
        h = qkeys.map{|k| [k, [req.query[k].to_s]]}.to_hash
        words = req.query["text"].to_s.split(" ").map &[[:gsub, /\+/, " "]]
        @search_query = SearchQueryParser.tokens_and_words_to_query_hash(h, words)
        #p SearchQueryParser.parse_query(req.query['q'].to_s, columns)
      end
      mode = 'list' if ["/", ""].include?(req.path_info)
      __send__("do_#{mode}", req, res)
    end
  end
  
  def user_auth(req, res)
    un = req.query['username']
    pw = req.query['password']
    cookies = req.cookies.find_all{|c| c.name == 'future_session_id' }
    user = nil
    if cookies.size > 0
      cookies.each{|c| c.instance_variable_set(:@discard, true) }
      cookie = cookies.find{|cookie|
        @session_id = cookie.value
        user = Users.continue_session(@session_id)
      }
      cookie.instance_variable_set(:@discard, false)
      cookie.max_age = 3600 * 24 * 7
      if !user or req.query['logout']
        user.logout if user
        cookie.instance_variable_set(:@discard, true)
        user = nil
      end
      res.cookies.push *cookies
    end
    if un and pw
      if user
        user.logout
        cookie.instance_variable_set(:@discard, true)
      end
      @session_id = create_new_id
      user = Users.login(un, pw, @session_id)
      if user
        new_cookie = WEBrick::Cookie.new('future_session_id', @session_id)
        new_cookie.max_age = 3600 * 24 * 7
        new_cookie.path = "/"
        res.cookies << new_cookie
      end
    end
    @servlet_user = (user or Users.anonymous)
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
    @new_session = true
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
        [["Create new", File.join(@servlet_target_path, "create")],
        ["List normal", @servlet_target_path]
        ]
      else
        [["Create new", File.join(@servlet_target_path, "create")],
        ["List deleted", '?deleted']
        ]
      end
    else
      [["Create new", File.join(@servlet_target_path, "create")]]
    end
  end

  def servlet_view_actions(req)
    if @servlet_target.writable_by(@servlet_user)
      if column? 'deleted' and @servlet_target.deleted
        [["Undelete", File.join(@servlet_target_path, "undelete")]]
      else
        [["Delete", File.join(@servlet_target_path, "delete")]]
      end
    else
      []
    end
  end

  def print_navigation_path(b)
    b.a("future", :href => File.split(@servlet_root).first)
    b.text!("/")
    b.a(table_name, :href=> @servlet_root)
  end

  def print_user_info(b)
    b.a(@servlet_user.name, :href => "/users/#{@servlet_user.name}")
    b.text!(" (")
    b.a("sign out", :href => "/users/logout")
    b.text!(")")
  end

  def servlet_list_rows(req)
    cols = req.query['columns'].to_s.split(",") & columns.keys
    cols = :all if cols.empty?
    q = {:order_by => servlet_path_key, :columns => cols}
    q.merge!(@search_query) if @search_query
    if column? 'deleted' and req.query['deleted']
      q[:deleted] = true
    end
    rfind_all(@servlet_user, q)
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
              b.td{ b.a(obj[servlet_path_key].to_s, :href => File.join(@servlet_root, obj[servlet_path_key].to_s)) }
              cols.each{|c,cl| b.td(obj[c]) unless c.to_s == servlet_path_key.to_s or servlet_invisible_column?(c) }
            }
          }
        }
      }
    end
  end

  def do_delete(req,res)
    @servlet_target.rdelete(@servlet_user)
    res.status = 302
    res['location'] = @servlet_root
  end

  def do_undelete(req,res)
    @servlet_target.rundelete(@servlet_user)
    res.status = 302
    res['location'] = @servlet_root
  end

  def do_create(req,res)
    unless req.query.empty?
      servlet_create(req)
      res.status = 302
      res['location'] = @servlet_root
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
    unless req.query.empty?
      servlet_target_edit(req)
    end
    res.status = 302
    res['location'] = @servlet_target_path
  end
  
  def do_view(req,res)
    vals = columns.map{|c,cl| @servlet_target[c] }
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
          b.a(@servlet_path, :href => @servlet_target_path)
        }
        b.p { print_user_info(b) }
        b.h2("Actions")
        b.ul {
          servlet_view_actions(req).each{|name, href|
            b.li { b.a(name, :id => 'action_link', :href => href) }
          }
        }
        b.form(:method => 'POST', :action => File.join(@servlet_target_path, "edit")){
          columns.each{|c,cl|
            b.h3("#{c} (#{cl})")
            b.p {
              if servlet_uneditable_column? c
                b.span(@servlet_target[c], :class => "column_value", :id => "div_#{c}")
              else
                b.span(@servlet_target[c], :class => "column_value editable", :id => "div_#{c}")
                b.input(:class => "edit_input", :id => c, :type => 'text', :name => c, :value => @servlet_target[c])
              end
            }
          }
          b.p { b.input(:type => 'submit', :value => 'Save changes' )}
        }
        b.p { b.a("Edit", :id => 'edit_link', :href => File.join(@servlet_target_path, "edit")) }
      }
    end
  end

  def do_json(req, res)
    res['Content-type'] = 'text/plain'
    if @servlet_target
      h = {}
      columns.map{|c, cl|
        h[c] = @servlet_target[c] unless servlet_invisible_column?(c)
      }
      res.body = h.to_json
    else
      objs = servlet_list_rows(req)
      cols = req.query['columns'].to_s.split(",") & columns.keys
      cols = columns.keys if cols.empty?
      cols.delete_if?{|c| servlet_invisible_column?(c) }
      res.body = objs.map{|o|
        cols.map{|c| [c, o[c]] }.to_hash
      }.to_json
    end
  end

  def servlet_create(req)
    edits = req.query.find_all{|k,v|
      column? k and !servlet_uneditable_column?(k)
    }
    rfind_or_create(@servlet_user, edits.to_hash)
  end

  def servlet_target_edit(req)
    @servlet_target.write(@servlet_user) do
      DB.transaction do
        edits = req.query.find_all{|k,v|
          column? k and @servlet_target[k].to_s != v and
          not servlet_uneditable_column?(k)
        }
        edits.each{|k,v|
          @servlet_target[k] = v
        }
        @servlet_target[:modified_at] = Time.now.to_s if column?('modified_at')
        new_path = req.query[servlet_path_key.to_s]
        @servlet_target_path = File.join(@servlet_root, new_path) if new_path
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

    delegate "Items", :rfind, :rfind_all, :columns


    def do_view(req,res)
      res['Content-type'] = 'image/jpeg'
      x,y,z,w,h = parse_tile_geometry(@servlet_path)
      res.body = Tiles.read(@servlet_user, @search_query, :rows, x, y, z, w, h)
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

    delegate "Items", :rfind, :rfind_all, :columns

    def do_view(req,res)
      res['Content-type'] = 'text/plain'
      x,y,z,w,h = Tile.parse_tile_geometry(@servlet_path)
      res.body = Tiles.info(@servlet_user, @search_query.merge(:columns => [:path]), :rows, x, y, z, w, h).to_a.to_json
    end
  
    def do_list(req,res)
      res['Content-type'] = 'text/plain'
      res.body = {
        "maxZoom" => Future.image_cache.max_zoom,
        "title" => @servlet_user.name
      }.to_json
    end
  end

end

# 
# class Zogen
# extend FutureServlet
# 
#   class << self
#     def servlet_modes
#       []
#     end
# 
#     def do_list(req,res)
#       res.body = File.read("./html/zogen.html")
#     end
# 
#     def do_view(req,res)
#       res.body = File.read("./html/rototype.js")
#     end
#   end
# 
# end


class Files
extend FutureServlet

  def self.table_name
    'files'
  end

  def self.do_list(req, res)
    objs = Items.rfind_all(@servlet_user, :order_by => :path)
    cols = ['path']
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name) }
      b.body {
        b.h1 {
          print_navigation_path(b)
        }
        b.table(:border => 1){
          objs.each{|obj|
            b.p { b.a(obj['path'].to_s, :href => File.join(@servlet_root, obj['path'].to_s)) }
          }
        }
      }
    end
  end

  def self.do_view(req, res)
    if @servlet_path =~ /^[0-9]+$/
      item = Items.rfind(@servlet_user, :image_index => @servlet_path)
    else
      item = Items.rfind(@servlet_user, :path => @servlet_path)
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


class Items
extend FutureServlet

  def self.sub_modes
    ['files','users','groups','tags','sets','thumbnail']
  end

  def self.servlet_path_key
    :path
  end

  def self.servlet_invisible_columns
    super | ['internal_path']
  end

  def self.do_json(req,res)
    if @servlet_path =~ /^[0-9]+$/
      @servlet_target = rfind(@servlet_user, :image_index => @servlet_path)
    end
    return false unless @servlet_target
    super
  end

end


class Thumbnails
extend FutureServlet

  class << self
  
    def table_name
      'thumbnails'
    end

    def do_list(req, res)
      return false
    end

    def do_view(req, res)
      if @servlet_path =~ /^[0-9]+$/
        item = Items.rfind(@servlet_user, :image_index => @servlet_path)
      else
        item = Items.rfind(@servlet_user, :path => @servlet_path)
      end
      if item
        res['Content-type'] = 'image/png'
        res.body = item.thumbnail.read
      else
        res['Content-type'] = 'text/html'
        res.body = "<html><body> File not found </body></html>"
        res.status = 404
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
        ["Register new account", File.join(@servlet_target_path, "create")],
        ["Sign in", File.join(@servlet_target_path, "login")],
        ["Sign out", File.join(@servlet_target_path, "logout")]
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
      if @servlet_user != Users.anonymous
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Already logged in") }
          b.body {
            b.h1 { print_navigation_path(b) }
            b.h2("Welcome back, #{@servlet_user.name}!")
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
      @servlet_user.logout if @servlet_user
      user_auth(req, res)
      do_login(req,res)
    end

    def do_create(req,res)
      un = req.query['username']
      pw = req.query['password']
      if un and pw
        @servlet_user.logout if @servlet_user
        if (not find(:name => un)) and @servlet_user = register(un, pw)
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

end


class Groups
extend FutureServlet

  def self.servlet_uneditable_columns
    super | [:namespace]
  end

  def self.sub_modes
    ['files','users','items','tags','sets']
  end

end


end


