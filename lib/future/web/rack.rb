require 'rubygems'
if $SWIFTIPLY
  require 'swiftcore/swiftiplied_mongrel'
elsif $EVENTED_MONGREL
  require 'swiftcore/evented_mongrel'
end
require 'rack/request'
require 'rack/response'
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


class File

  def each
    each_data ||= ""
    until eof?
      each_data.replace(read(262144))
      yield each_data
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
    res = Rack::Response.new(r.body, r.status, {"Content-Type" => r.content_type}.merge(r.headers))
    t0 = time(t0, "response created")
    a = res.finish
    t0 = time(t0, "request done")
    puts "Total time: #{Time.now.to_f - t}s" if $PRINT_QUERY_PROFILE
    a
  end
  
end
