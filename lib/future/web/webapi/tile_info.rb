module MuryuDispatch

  module TileInfo
  include Handler
  extend self

    def view(user,req,res)
      search_query = MuryuDispatch::Items.parse_search_query(user, req.query['q'].to_s)
      sq = search_query.clone
      res.content_type = 'application/json'
      time = req.query['time'].to_s
      if req.query.has_key?('tiles')
        tiles = JSON.parse(req.query['tiles'][0])
        tile_array = '[' + tiles.map{|x,y,z| get_tile_info(user, sq, x, y, z, 256, 256, time) }.join(",") + ']'
        res.body = tile_array
      else
        res.body = {
          "dimensions" => Future::Tiles.dimensions(user, sq, time, :rows),
          "itemCount" => Future::Tiles.item_count(user, sq, time),
          "maxZoom" => 15,
          "title" => req.query['q'].to_s
        }.to_json
      end
    end

    ### helpers

    def get_tile_info(user,sq,x,y,z,w,h,time)
      if z < 5
        return '[]'
      end
      key = Digest::MD5.hexdigest([user.id, "x#{x}y#{y}z#{z}w#{w}h#{h}", sq, time].join("::"))
      zjinfo = Future.memcache.get(key, true) if $CACHE_INFO
      unless zjinfo
        if z >= 4
          sq[:columns] ||= []
          sq[:columns] << 'path'
          sq[:columns] << 'deleted'
        end
        jinfo = "["
        puts "#{Thread.current.telapsed} for tile_info init" if $PRINT_QUERY_PROFILE
        info = Future::Tiles.info(
          user, sq, time,
          :rows, x, y, z, w, h
        ).each do |image_index, query_index, deleted, x, y, sz, path|
          jinfo << "{index:#{query_index},x:#{x},y:#{y},sz:#{sz},path:#{path.dump},deleted:#{deleted}},"
        end
        jinfo.chop! if jinfo.size > 1
        jinfo << "]"
        puts "#{Thread.current.telapsed} for fetching tile info" if $PRINT_QUERY_PROFILE
#         zjinfo = Zlib::Deflate.deflate(jinfo, 9)
#         puts "#{Thread.current.telapsed} for tile info jsonification" if $PRINT_QUERY_PROFILE
#         Future.memcache.set(key, zjinfo, 300, true) if $CACHE_INFO
      else
        jinfo = Zlib::Inflate.inflate(zjinfo)
      end
      jinfo
    end

    class TileInfoHandler < SingleHandler

      def view(req,res)
        sq = MuryuDispatch::Items.parse_search_query(user, req.query['q'].to_s)
        res.content_type = 'application/json'
        x,y,z,w,h = MuryuDispatch::Tile.parse_tile_geometry(req.key)
        res.body = TileInfo.get_tile_info(user, sq, x,y,z,256,256,req.query['time'].to_s)
      end

    end
    self.single_handler = TileInfoHandler

  end

end