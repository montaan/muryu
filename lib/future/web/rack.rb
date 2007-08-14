require 'rubygems'
if $SWIFTIPLY
  require 'swiftcore/swiftiplied_mongrel'
elsif $EVENTED_MONGREL
  require 'swiftcore/evented_mongrel'
end
require 'rack/request'
require 'rack/response'
require 'rack/handler/mongrel'
require 'rack'

class Rack::Request

  def headers
    @headers ||= (
      h = {}
      re = /\AHTTP_/
      @env.find_all{|k,v| k =~ re }.map{|k,v|
        header_name = k.split("_")[1..-1].map{|s|s.capitalize}.join("-")
        h[header_name] = v
      }
      h
    )
  end
  
end

module Rack
  module Handler
    class Mongrel < ::Mongrel::HttpHandler

      def process(request, response)
        env = {}.replace(request.params)
        env.delete "HTTP_CONTENT_TYPE"
        env.delete "HTTP_CONTENT_LENGTH"

        env["SCRIPT_NAME"] = ""  if env["SCRIPT_NAME"] == "/"

        env.update({"rack.version" => [0,1],
                     "rack.input" => request.body || StringIO.new(""),
                     "rack.errors" => STDERR,

                     "rack.multithread" => false,
                     "rack.multiprocess" => false, # ???
                     "rack.run_once" => false,

                     "rack.url_scheme" => "http",
                   })
        env["QUERY_STRING"] ||= ""
        env.delete "PATH_INFO"  if env["PATH_INFO"] == ""

        status, headers, body = @app.call(env)

        begin
          response.status = status.to_i
          headers.each { |k, vs|
            vs.each { |v|
              response.header[k] = v
            }
          }
          if body.respond_to? :size
            sz = body.size
          elsif body.respond_to? :stat
            st = body.stat
            sz = st.size unless st.pipe?
          end
          response.send_status(headers["Content-Length"] || sz)
          response.send_header
          body.each { |part|
            response.socket.write(part)
          }
          response.send_body
        rescue => e
          puts e.class, e.message, e.backtrace
          raise e
        ensure
          body.close  if body.respond_to? :close
        end
      end

    end
  end
end


class File

  def each
    until eof?
      yield read(65536)
    end
    self
  end

end

class MuryuRequest

  attr_reader :relative_path, :get, :post, :cookies, :request_method, :headers
  def initialize(req)
    @relative_path = req.path_info.gsub(/\A\/+/, '')
    @request_method = req.request_method
    @headers = req.headers
    @post = req.POST
    @post.each{|k,v| @post[k] = [v] unless v.is_a?(Array) }
    @get = req.GET
    @get.each{|k,v| @get[k] = [v] unless v.is_a?(Array) }
    @cookies = req.cookies
  end

  def [](k)
    @headers[k]
  end
  
end


class MuryuRack

  def time(t0, msg)
    if t0 == 0
      Thread.current.telapsed
    end
    puts "#{Thread.current.telapsed} #{msg}" if $PRINT_QUERY_PROFILE
    1
  end
  
  def call(env)
    t = Time.now.to_f
    t0 = time(0, "got rack request")
    req = Rack::Request.new(env)
    t0 = time(t0, "parsed rack request")
    mr = MuryuRequest.new(req)
    t0 = time(t0, "created muryu request")
    r = MuryuDispatch.dispatch(mr)
    t0 = time(t0, "dispatch done")
    a = [r.status, {"Content-Type" => r.content_type}.merge(r.headers), r.body]
    t0 = time(t0, "request done")
    puts "Total time: #{Time.now.to_f - t}s" if $PRINT_QUERY_PROFILE
    a
  end
  
end
