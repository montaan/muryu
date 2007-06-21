module MuryuDispatch

  module Tile
  include Handler
  extend self

  ### helpers

  def parse_tile_geometry(str)
    ts = str.scan(/[a-z][-+]?[0-9]+/i).map{|t| [t[0,1], t[1..-1]] }.to_hash
    x = ts['x'].to_i
    y = ts['y'].to_i
    z = ts['z'].to_i
    w = (ts['w'] || 256).to_i
    h = (ts['h'] || 256).to_i
    [x,y,z,w,h]
  end
    
  class TileHandler < SingleHandler

    def view(req,res)
      search_query = MuryuDispatch::Items.parse_search_query(user, req.query['q'].to_s)
      tile_start = Time.now.to_f
      res.content_type = 'image/jpeg'
      x,y,z,w,h = MuryuDispatch::Tile.parse_tile_geometry(req.key)
      return if z.to_i > 15 || z.to_i < 0
      color = (req.query['color'].to_s != 'false')
      bgcolor = (req.query.has_key?('bgcolor') ?
                  req.query['bgcolor'].to_s[0,6] : false)
      bgimage_src = (req.query.has_key?('bgimage') ? URI.unescape(req.query['bgimage'].to_s) : false)
      key = Digest::MD5.hexdigest([user.id, req.key, color, bgcolor, bgimage_src, search_query, req.query['time']].join("::"))
      time_key = 'tiletime::' + key
      tile_key = 'tile::' + key
      puts "#{Thread.current.telapsed} for tile arg parsing" if $PRINT_QUERY_PROFILE
      if $CACHE_TILES and not $indexes_changed
        time = Future.memcache.get(time_key)
      end
      puts "#{Thread.current.telapsed} for memcache get" if $PRINT_QUERY_PROFILE
      tile = nil
      res['ETag'] = time_key
      if false #time
        if req['If-None-Match'] == time_key || req['If-Modified-Since'] == time
          res.status = 304
          return
        else
          tile = Future.memcache.get(tile_key)
        end
      end
      unless tile
        if bgimage_src and bgitem = Future::Items.rfind(user, :path => bgimage_src)
          image = Imlib2::Image.load(bgitem.thumbnail)
          image.crop!(0,0,256,256)
          bgimage = image.data
          image.delete!
        else
          bgimage = nil
        end
        tile = Future::Tiles.read(user, search_query, :rows, x, y, z, w, h,
                          color, bgcolor, bgimage)
        time = Time.now.httpdate
        puts "#{Thread.current.telapsed} for creating a JPEG" if $PRINT_QUERY_PROFILE
        if tile and $CACHE_TILES
          Thread.new {
            Future.memcache.set(tile_key, tile, 300)
            Future.memcache.set(time_key, time, 300)
          }
        end
      end
      if tile
        res.body = tile
      else
        res.status = 302
        res.content_type = 'image/gif'
        res['Location'] = '/transparent.gif'
      end
      res['Last-Modified'] = time if time
      if time
        res['Expires'] = (Time.parse(time) + 300).httpdate
      end
      puts "Tile time: #{"%.3fms" % [1000 * (Time.now.to_f - tile_start)]}" if $PRINT_QUERY_PROFILE
      puts "Total time: #{"%.3fms" % [1000 * (Time.now.to_f - request_time)]}" if $PRINT_QUERY_PROFILE
      puts if $PRINT_QUERY_PROFILE
    end
    
  end
  self.single_handler = TileHandler

  end

end