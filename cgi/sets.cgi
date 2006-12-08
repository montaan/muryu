#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new

mode = ['create','edit','list'].find{|m| c.has_key? m }
user = c.authenticate!

case mode
when 'create'
  user.create_set(c['name'], c['groups'])
  c.print c.header("type" => "text/plain")
  c.print "OK"
when 'edit'
  user.edit_set(c['name'], c['edits'])
  c.print c.header("type" => "text/plain")
  c.print "OK"
when 'list'
  sets = user.list_sets(c['q'])
  c.print c.header('type' => 'application/javascript')
  c.print sets.to_json
end
