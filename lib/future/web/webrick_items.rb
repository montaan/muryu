#!/usr/bin/env ruby
require 'webrick'
require 'future'


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
  
  def do_GET(req,res)
    handle_request(req,res)
  end
  
  def do_POST(req,res)
    handle_request(req,res)
  end
  
  def handle_request(req, res)
    @servlet_user = Users.authenticate(req)
    mode = File.split(req.path_info).last
    mode = 'view' unless servlet_modes.include? mode
    mode = 'list' if req.path_info == "/"
    __send__("do_#{mode}", req, res)
  end
  
  def servlet_modes
    ['create','delete','undelete','edit','list','view']
  end

  def do_create(req,res)
  end
  
  def do_delete(req,res)
  end
  
  def do_edit(req,res)
  end
  
  def do_list(req,res)
  end

  def do_view(req,res)
  end

end


class Files
include FutureServlet

  def do_GET(req, res)
    user = authenticate(req)
    item = Items.rfind(user, :path => req.path_info, :columns => [:filetype, :local_path])
    if item
      res['Content-type'] = item.major + "/" + item.minor
      res.body = item.read
    else
      res.status = 404
    end
  end
  
end


class Items
include FutureServlet
end


class Users
include FutureServlet
end


class Sets
include FutureServlet
end


class Groups
include FutureServlet
end


end


include WEBrick
include Future

s = HTTPServer.new( :Port => 2000 )

s.mount("/files", Files)
s.mount("/items", Items)
s.mount("/users", Users)
s.mount("/sets", Sets)
s.mount("/groups", Groups)


trap("INT"){ s.shutdown }
s.start
