module MuryuDispatch

  module Tile
  extend self

    def [](key)
      self
    end

    def view(q,r)
      r.body = Process.pid.to_s
    end

  end

end