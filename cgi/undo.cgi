#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated?

changeset = []

if user
  if c.has_key? 'redo'
    changeset = user.redo
  else
    changeset = user.undo
  end
end

c.print c.header('type' => 'application/javascript')
c.print changeset.to_json

