#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated? || Users.anonymous

query = Items.default_query
query = c['q'] if c.has_key? 'q'

edits = Items.default_fields
edits = c['edits'] if c.has_key? 'edits'

items = Items.search(query, user)
items.apply_edits(edits)

c.print c.header("type" => "text/plain")
c.print "OK"
