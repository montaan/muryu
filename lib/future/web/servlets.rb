#!/usr/bin/env ruby
require 'webrick'
require 'future'
require 'builder'

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

  def handle_request(req, res)
    user_auth(req, res)
    @servlet_path, mode = File.split(req.path_info)
    unless servlet_modes.include? mode
      @servlet_path = File.join(@servlet_path, mode)
      mode = 'view'
    end
    @servlet_path.gsub!(/^\//, '')
    unless @servlet_path.empty?
      @servlet_target = find(
        servlet_path_key => @servlet_path,
        :columns => :all
      )
    end
    mode = 'list' if ["/", ""].include?(req.path_info)
    __send__("do_#{mode}", req, res)
  end
  
  def user_auth(req, res)
    un = req.query['username']
    pw = req.query['password']
    cookies = req.cookies.find_all{|c| c.name == 'future_session_id' }
    cookie = cookies.first
    if cookie
      @session_id = cookie.value
      user = Users.continue_session(@session_id)
      res.cookies << cookie
      if !user or req.query['logout']
        user.logout if user
        res.cookies.delete cookie
        user = nil
      end
    end
    if un and pw
      if user
        user.logout
        res.cookies.delete cookie
      end
      @session_id = create_new_id
      user = Users.login(un, pw, @session_id)
      if user
        new_cookie = WEBrick::Cookie.new('future_session_id', @session_id)
        new_cookie.max_age = 3600
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
    ['create','edit','view'] + sub_modes
  end

  def sub_modes
    []
  end

  def do_list(req,res)
    objs = find_all(:columns => :all).map{|o|
      columns.map{|c,cl| o[c] }
    }
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name) }
      b.body {
        b.table{
          b.tr{
            columns.each{|c,cl| b.td("#{c} (#{cl})") }
          }
          objs.each{|vals|
            b.tr { vals.each{|v| b.td(v) } }
          }
        }
      }
    end
  end

  def do_create(req,res)
  end
  
  def do_edit(req,res)
    unless req.query.empty?
      DB.transaction do
        edits = req.query.find_all{|k,v|
          column? k and @servlet_target[k].to_s != v
        }
        p edits
        edits.each{|k,v|
          @servlet_target[k] = v
        }
      end
    end
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name) }
      b.body {
        b.h1 {
          b.text!("Editing ")
          b.a(table_name, :href=> "/#{table_name}")
          b.text!("/")
          b.a(@servlet_path, :href => "./")
        }
        b.form(:method => 'POST'){
          columns.each{|c,cl|
            b.h3("#{c} (#{cl})")
            b.p { b.input(:type => 'text', :name => c, :value => @servlet_target[c]) }
          }
          b.p { b.input(:type => 'submit', :value => 'Save changes' )}
        }
      }
    end
  end
  
  def do_view(req,res)
    vals = columns.map{|c,cl| @servlet_target[c] }
    res.body = Builder::XmlMarkup.new.html do |b|
      b.head { b.title(table_name) }
      b.body {
        b.table{
          b.tr{
            columns.each{|c,cl| b.td("#{c} (#{cl})") }
          }
          b.tr { vals.each{|v| b.td(v) } }
        }
      }
    end
  end

  def do_echo(req, res)
    res['Content-type'] = 'text/plain'
    res.body = (my_caller[0,1] + ['', req.inspect.gsub(", ",",\n  ")]).join("\n")
  end

  def my_caller
    caller
  end

  ['create'].each{|m| alias_method("do_#{m}", :do_echo) }

end


class Files
extend FutureServlet

  def self.do_GET(req, res)
    user = authenticate(req)
    item = Items.rfind(user, :path => req.path_info, :columns => [:filetype, :local_path])
    if item
      res['Content-type'] = item.major + "/" + item.minor
      res.body = item.read
    else
      res.status = 404
    end
  end
  
  def self.sub_modes
    ['items']
  end

end


class Items
extend FutureServlet

  def self.sub_modes
    ['files','users','groups','tags','sets']
  end

  def self.servlet_path_key
    :path
  end

end


class Users
extend FutureServlet

  class << self
    def sub_modes
      ['files','items','groups','tags','sets', 'login', 'logout']
    end

    def do_login(req,res)
      if @servlet_user != Users.anonymous
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Already logged in") }
          b.body {
            b.h1("Welcome back, #{@servlet_user.name}!")
            b.a(:href => 'logout') { b.h2("Log out?") }
          }
        end
      elsif req.query['username']
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Failed to log in.") }
          b.body {
            b.h1("Login failed, please try again.")
            b.p { b.a("Register new account", :href=>'create') }
            login_form(b)
          }
        end
      else
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Log in") }
          b.body {
            b.h1("Come on in!")
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
      p [un, pw]
      if un and pw
        @servlet_user.logout if @servlet_user
        if (not find(:name => un)) and @servlet_user = register(un, pw)
          user_auth(req, res)
          res.body = Builder::XmlMarkup.new.html do |b|
            b.head { b.title("Registered new account!") }
            b.body { b.h1( "Welcome aboard, #{un}! We hope you enjoy the ride!" ) }
          end
        else
          res.body = Builder::XmlMarkup.new.html do |b|
            b.head { b.title("Registration failed") }
            b.body {
              b.h1("Failed to register account, someone is already using '#{un}'.")
              b.h2("Please try another name.")
              registration_form(b)
            }
          end
        end
      else
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Registering account.") }
          b.body {
            b.h1('Register')
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

  def self.sub_modes
    ['files','users','groups','tags','sets']
  end

end


class Groups
extend FutureServlet

  def self.sub_modes
    ['files','users','items','tags','sets']
  end

end


end


