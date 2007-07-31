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
          if @target.mimetype == 'text/html'
            res.status = 302
            res['Location'] = "/subfiles/#{@target.path}/data"
          elsif q.key =~ /\A[0-9]+\Z/
            res.status = 302
            res['Location'] = "/files/#{@target.path}"
          else
            res['Expires'] = (Time.now+86400*365).httpdate
            res.body = File.open(@target.internal_path, 'rb')
            res.content_type = @target.mimetype
          end
        end
      end

      def page(req, res)
        pg = req.query['number'][0].to_i
        sz = (req.query['size'] || [1024])[0].to_i
        thumbdir = @target.thumbnail.dirname
        pagefile = thumbdir + "#{pg}_#{sz}.png"
        lm = @target.modified_at.httpdate
        if req['If-Modified-Since'] == lm
          res.status = 304
        else
          res['Last-Modified-At'] = lm
          res['Expires'] = (Time.now + 86400*30).httpdate
          unless pagefile.exist?
            if @target.pages and @target.pages > pg
              Mimetype[@target.mimetype].thumbnail(@target.internal_path, pagefile, sz, pg)
            else
              raise(MuryuQuery::NotFound, "Tried to get page #{pg}, but document has only #{@target.pages} pages")
            end
          end
          res.body = pagefile.open('rb')
          res.content_type = 'image/png'
        end
      end

      def item(q,res)
        res.status = 302
        res['Location'] = '/items/' + @target.path
      end
      
    end
    self.single_handler = ItemFile
  end


  module Subfiles
  include Handler
  extend self

    class SubfilesHandler < SingleHandler
  
      def view(req, res)
        spl = req.key.split("/")
        path = spl[0,4].join("/")
        rest = spl[4..-1].join("/")
        item = Future::Items.rfind(user, :path => path)
        if item
          ip = File.split(item.internal_path).first
          sp = rest.gsub(/\A\.*\/|(\/\.\.\/)|(\/\.\.\Z)/, '')
          fn = File.join(ip, sp)
          if fn.index(File.dirname(ip)) == 0 and File.exist?(fn)
            if sp.empty?
              res.status = 302
              res['Location'] = "/subfiles/#{req.key}/data"
            elsif fn == File.join(ip, 'data')
              if req['If-None-Match'] == item.sha1_hash
                res.status = 304
              else
                res.content_type = item.mimetype + "; charset=" + item.charset.to_s
                res['ETag'] = item.sha1_hash
                res['Expires'] = (Time.now+86400*365).httpdate
                res.body = File.open(fn)
              end
            elsif File.directory?(fn)
              res.status = 403
              res.body = "<html><body> No directory listings </body></html>"
            else
              mtime = File.mtime(fn).httpdate
              if req['If-Modified-Since'] == mtime
                res.status = 304
              else
                res['Last-Modified'] = mtime
                res['Expires'] = (Time.now+86400*365).httpdate
                res.content_type = MimeInfo.get(sp).to_s
                res.body = File.open(fn)
              end
            end
          else
            res.status = 404
            res.body = "<html><body> File not found </body></html>"
          end
        else
          res.status = 404
          res.body = "<html><body> File not found </body></html>"
        end
      end

    end
    self.single_handler = SubfilesHandler
  
  end

end