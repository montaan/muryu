require 'memcache'
require 'thread'

module Future

  MEMCACHE_SERVERS = ['127.0.0.1:11211']

  class MemCachePool
    attr_reader :local_cache
    
    def initialize(servers, size=2)
      @queue = Queue.new
      size.times{ @queue.push(MemCache.new(servers)) }
    end

    def get(*a)
      reserve do |s|
        s.get(*a) rescue false
      end
    end

    def set(*a)
      reserve do |s|
        s.set(*a)
      end
    end

    def delete(*a)
      reserve do |s|
        s.delete(*a)
      end
    end

    def reserve
      s = @queue.shift
      begin
        yield s
      rescue => e
        puts e
      ensure
        @queue.push(s)
      end
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


