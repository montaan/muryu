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
    w = [1, [1024, (ts['w'] || 256).to_i].min].max
    h = [1, [1024, (ts['h'] || 256).to_i].min].max
    [x,y,z,w,h]
  end
    
  class TileHandler < SingleHandler

    def view(req,res)
      search_query = MuryuDispatch::Items.parse_search_query(user, req.query['q'].to_s)
      tile_start = Time.now.to_f
      res.content_type = 'image/jpeg'
      x,y,z,w,h = MuryuDispatch::Tile.parse_tile_geometry(req.key)
      return if z > 15 or z.to_i < 0
      color = (req.query['color'].to_s != 'false')
      bgcolor = (req.query.has_key?('bgcolor') ?
                  req.query['bgcolor'].to_s[0,6] : false)
      bgimage_src = (req.query.has_key?('bgimage') ? URI.unescape(req.query['bgimage'].to_s) : false)
      key = Digest::MD5.hexdigest([user.id, req.key, color, bgcolor, bgimage_src, search_query, req.query['time']].join("::"))
      time_key = 'tiletime::' + key
      tile_key = 'tile::' + key
      puts "#{Thread.current.telapsed} for tile arg parsing" if $PRINT_QUERY_PROFILE
      if $CACHE_TILES #and not $indexes_changed
        time = Future.memcache.get(time_key)
      end
      puts "#{Thread.current.telapsed} for memcache get" if $PRINT_QUERY_PROFILE
      res['ETag'] = time_key
      if time
        if req['If-None-Match'] == time_key || req['If-Modified-Since'] == time
          res.status = 304
          return
        else
          tile = Future.memcache.get(tile_key, true)
          puts "#{Thread.current.telapsed} for reading tile from memcache" if tile and $PRINT_QUERY_PROFILE
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
        layouter = (req.query['layout'] || 'rows').to_s.to_sym
        tile = Future::Tiles.read(user, search_query, req.query['time'], layouter, x, y, z, w, h,
                                  color, bgcolor, bgimage)
        time = Time.now.httpdate
        puts "#{Thread.current.telapsed} for creating tile" if $PRINT_QUERY_PROFILE
        if tile and $CACHE_TILES and user == Future::Users.anonymous
          Thread.new do
            Thread.current.telapsed
            Future.memcache.set(tile_key, tile, 300, true)
            Future.memcache.set(time_key, time, 300)
            puts "#{Thread.current.telapsed} for writing tile to memcache" if $PRINT_QUERY_PROFILE
          end
        end
      end
      if tile
        res.body = tile
      else
        res.status = 302
        res.content_type = 'image/gif'
        res['Location'] = '/transparent.gif'
      end
      res['Expires'] = (Time.now+86400*365).httpdate
      res['Last-Modified'] = time if time
      puts "Tile time: #{"%.3fms" % [1000 * (Time.now.to_f - tile_start)]}" if $PRINT_QUERY_PROFILE
      puts if $PRINT_QUERY_PROFILE
    end
    
  end
  self.single_handler = TileHandler

  end

end