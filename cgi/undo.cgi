#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated?

if user
  if c.has_key? 'redo'
    user.redo
  else
    user.undo
  end
end

c.print c.header('type' => 'application/javascript')
c.print '"OK"'

