#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated? || Users.anonymous

if c.has_key? 'complete'
  ts = Tags.completions c['tag']
else
  ts = Tags.list_for(user)
end

c.print c.header('type' => 'application/javascript')
c.print cs.to_json

