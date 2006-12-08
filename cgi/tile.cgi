#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated? || Users.anonymous

tile_coords = Tile.default_coords
tile_coords = c['t'] if c.has_key? 't'

query = Items.default_query
query = c['q'] if c.has_key? 'q'

format = Tiles.default_format
format = c['format'] if c.has_key? 'format'

c.print c.header("type" => Future.mimetype_for(format))
c.print Tiles.get(query, user, tile_coords)
