#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new

mode = ['create','edit','list'].find{|m| c.has_key? m }
user = c.authenticate!

case mode
when 'create'
  user.create_group(c['name'])
  c.print c.header("type" => "text/plain")
  c.print "OK"
when 'edit'
  user.edit_group(c['name'], c['edits'])
  c.print c.header("type" => "text/plain")
  c.print "OK"
when 'list'
  groups = user.list_groups(c['q'])
  c.print c.header('type' => 'application/javascript')
  c.print groups.to_json
end
