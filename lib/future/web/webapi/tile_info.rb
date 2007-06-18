module MuryuDispatch

  module TileInfo
  include Handler
  extend self

    def view(u,q,r)
    end

    class TileInfoHandler < SingleHandler

      def view(q,r)
      end
    
    end
    self.single_handler = TileInfoHandler

  end

end