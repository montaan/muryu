require 'memcache'
require 'thread'

module Future

  MEMCACHE_SERVERS = ['127.0.0.1:11211']

  class MemCachePool
    attr_reader :local_cache
    
    def initialize(servers, size=16)
      @queue = Queue.new
      size.times{ @queue.push(MemCache.new(servers)) }
      @local_cache = {}
      @timeouts = {}
      start_timeout_monitor
    end

    def get(a, raw=false)
      lc = @local_cache[a]
      return lc if lc
      s = @queue.shift
      r = s.get(a,raw) rescue false
      if r
        local_cache_set(a,r,300)
      end
      @queue.push(s)
      r
    end

    def set(k,v,timeout,raw=false)
      local_cache_set(k,v,timeout)
      s = @queue.shift
      r = s.set(k,v,timeout,raw)
      @queue.push(s)
      r
    end

    def delete(a)
      @local_cache.delete(a)
      s = @queue.shift
      r = s.delete(a)
      @queue.push(s)
      r
    end

    private
    def local_cache_set(k, v, timeout=300)
      @timeouts[k] = timeout
      @local_cache[k] = v
    end

    def start_timeout_monitor
      @timeout_monitor = Thread.new{
        loop do
          sleep(1)
          @timeouts.each{|k,v|
            @timeouts[k] = v-1
          }
          @local_cache.delete_if{|k,v| @timeouts[k] < 0 }
        end
      } 
    end
  end


  class MemCacheLocal
    def initialize(servers, size=16)
      @server = MemCache.new(servers)
      @mutex = Mutex.new
    end

    def get(*a)
      @mutex.synchronize do
        r = @server.get(*a) rescue false
        r
      end
    end

    def get_multi(*a)
      @mutex.synchronize do
        r = @server.get_multi(*a) rescue false
        r
      end
    end

    def set(*a)
      @mutex.synchronize do
        r = @server.set(*a) rescue false
        r
      end
    end

    def delete(a)
      @mutex.synchronize do
        r = @server.delete(a) rescue false
        r
      end
    end
  end


  def self.memcache(pool=$MEMCACHE_USE_POOL)
    if pool
      @memcache_pool ||= MemCachePool.new(MEMCACHE_SERVERS)
    else
      @memcache ||= MemCacheLocal.new(MEMCACHE_SERVERS)
    end
  end

end


