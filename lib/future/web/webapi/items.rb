module MuryuDispatch

  module Items
  extend self
    def [](key)
      self
    end

    ### VERBS
    
    def upload(q,r)
    end

    def edit(q,r)
    end

    def delete(q,r)
    end

    def undelete(q,r)
    end

    def purge(q,r)
    end

    ### PROPERTIES

    def json(q,r)
    end

    def view(q,r)
    end

    def thumbnail(q,r)
    end

    def file(q,r)
    end
  end

end