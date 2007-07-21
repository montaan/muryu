require 'memcache'
require 'thread'

module Future

  MEMCACHE_SERVERS = ['127.0.0.1:11211']

  class MemCachePool
    attr_reader :local_cache
    
    def initialize(servers, size=4)
      @queue = Queue.new
      @level = 0
      size.times{ @queue.push(MemCache.new(servers)) }
    end

    def get(*a)
      if @local_cache
        @local_cache[a] ||= (reserve do |s|
          s.get(*a) rescue false
        end)
      else
        reserve do |s|
          s.get(*a) rescue false
        end
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

    def with_local_cache
      @level += 1
      @local_cache ||= {}
      yield
    ensure
      @level -= 1
      @local_cache = nil if @level == 0
    end

  end


  class MemCacheLocal
    def initialize(servers, size=16)
      @server = MemCache.new(servers)
      @mutex = Mutex.new
      @level = 0
    end

    def get(*a)
      @mutex.synchronize do
        if @local_cache
          @local_cache[a] ||= (@server.get(*a) rescue false)
        else
          @server.get(*a) rescue false
        end
      end
    end

    def get_multi(*a)
      @mutex.synchronize do
        @server.get_multi(*a) rescue false
      end
    end

    def set(*a)
      @mutex.synchronize do
        @server.set(*a) rescue false
      end
    end

    def delete(a)
      @mutex.synchronize do
        @server.delete(a) rescue false
      end
    end
    
    def with_local_cache
      @level += 1
      @local_cache ||= {}
      yield
    ensure
      @level -= 1
      @local_cache = nil if @level == 0
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


