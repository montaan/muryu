#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new

mode = ['create','edit','list'].find{|m| c.has_key? m }
user = c.authenticate! if mode != 'create'

case mode
when 'create'
  Users.register!(c['username'], c['password'])
  c.print c.header("type" => "text/plain")
  c.print "OK"
when 'edit'
  user.edit(c['edits'])
  c.print c.header("type" => "text/plain")
  c.print "OK"
when 'list'
  users = Users.list(user, c['q'])
  c.print c.header('type' => 'application/javascript')
  c.print users.to_json
end
