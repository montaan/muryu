module MuryuDispatch

  module Files
  include Handler
  extend self

    ### PROPERTIES
  
    def view(u,q,res)
      items = MuryuDispatch::Items.get_matching_items(u,q,[:path])
      res.content_type = 'application/json'
      res.body = items.map{|i| '/files/' << i.path }.to_json
    end

    class ItemFile < MuryuDispatch::Items::Item
      self.table = superclass.table
    
      def view(q,res)
        lm = @target.modified_at.httpdate
        if q['If-Modified-Since'] == lm
          res.status = 304
        else
          res['Last-Modified-At'] = lm
          res.body = File.open(@target.internal_path, 'rb')
          res.content_type = @target.mimetype
        end
      end

      def item(q,res)
        res.status = 302
        res['Location'] = '/items/' + @target.path
      end
      
    end
    self.single_handler = ItemFile
  end

end