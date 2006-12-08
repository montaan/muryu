#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated? || Users.anonymous

query = Items.default_query
query = c['q'] if c.has_key? 'q'

fields = Items.default_fields
fields = c['fields'] if c.has_key? 'fields'

format = Items.default_format
format = c['format'] if c.has_key? 'format'

items = Items.search(query, user)

CGI.print CGI.header("type" => Future.mimetype_for(format))
CGI.print items.to(format, fields)

