module MuryuDispatch

  module TileInfo
  include Handler
  extend self

    def view(user,req,res)
      search_query = MuryuDispatch::Items.parse_search_query(user, req.query['q'].to_s)
      sq = search_query.clone
      res.content_type = 'application/json'
      if req.query.has_key?('tiles')
        tiles = JSON.parse(req.query['tiles'][0])
        time = req.query['time'].to_s
        tile_array = '[' + tiles.map{|x,y,z| get_tile_info(user, sq, x, y, z, 256, 256, time) }.join(",") + ']'
        res.body = tile_array
      else
        res.body = {
          "dimensions" => Future::Tiles.dimensions(user, sq, :rows),
          "itemCount" => Future::Tiles.item_count(user, sq),
          "maxZoom" => 10,
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
      jinfo = Future.memcache.get(key) if $CACHE_INFO and not $info_changed
      unless jinfo
        if z >= 4
          sq[:columns] ||= []
          sq[:columns] << 'path'
          sq[:columns] << 'deleted'
        end
        puts "#{telapsed} for tile_info init" if $PRINT_QUERY_PROFILE
        info = Future::Tiles.info(
          user, sq,
          :rows, x, y, z, w, h
        ).to_a.map do |iind,((x,y,sz), info)|
          {:index => info[:index], :x => x, :y => y, :sz => sz, :path => info[:path], :deleted => info[:deleted]}
        end
        puts "#{telapsed} for fetching tile info" if $PRINT_QUERY_PROFILE
        jinfo = info.to_json
        puts "#{telapsed} for tile info jsonification" if $PRINT_QUERY_PROFILE
        Future.memcache.set(key, jinfo, 300) if $CACHE_INFO
      end
      jinfo
    end

    class TileInfoHandler < SingleHandler

      def view(req,res)
        sq = MuryuDispatch::Items.parse_search_query(user, req.query['q'].to_s)
        res.content_type = 'application/json'
        x,y,z,w,h = MuryuDispatch::Tile.parse_tile_geometry(req.key)
        res.body = TileInfo.get_tile_info(user, sq, x,y,z,256,256,req.query['time'])
        puts "Total tile_info time: #{"%.3fms" % [1000 * (Time.now.to_f - request_time)]}" if $PRINT_QUERY_PROFILE
      end

    end
    self.single_handler = TileInfoHandler

  end

end