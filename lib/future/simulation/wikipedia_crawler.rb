
require 'future/utils'
require 'open-uri'
require 'hpricot'
require 'thread'

module Future
module Simulation

module ExponentialDistribution
  def exponential_random_var(lambda = 1.0)
    u = 1.0 - rand()  # [0.0, 1.0)
    - Math.log(u) / lambda
  end
end

class User
  include ExponentialDistribution

  DEFAULT_INITIALIZE_OPTIONS = {
    :homepage   => "http://en.wikipedia.org/wiki/Special:Random",
    :avg_period => 1800, # a couple pages an hour
    :P_public   => 0.7,
    :P_shared   => 0.2,
    :P_private  => 0.1,
  }
  def initialize(username, groups, crawler, options = {})
    options = DEFAULT_INITIALIZE_OPTIONS.merge(options)
    @visited_urls = {}
    @username     = username
    @crawler      = crawler
    @groups       = groups
    @time         = Time.new
    @page         = options[:homepage]
    @avg_period   = options[:avg_period]
    @crawler      = crawler
    total         = options.values_at(:P_shared, :P_public, :P_private).inject(0){|s,x| s+x}
    @P_shared     = options[:P_shared] / total
    @P_public     = options[:P_public] / total
    @P_private    = options[:P_private] / total
  end

  def visit_next_page
    @time = @time + exponential_random_var(@avg_period)
    visit
  end

  private
  def visit
    open(@page) do |text|
      uri = text.base_uri
      doc = Hpricot(text)
      links = doc.search("//a[@href]").map do |link|
        begin
          abs_url = uri.merge(link.attributes["href"]).normalize
          abs_url.fragment = nil # remove  #foo  
          abs_url.to_s
        rescue URI::InvalidURIError
          nil
        end
      end
      links = links.select{|l| l && !@visited_urls[l] && @crawler.may_visit?(l) }
      next_page = links[rand(links.size)]
      next_page ||= @crawler.random_page
      @crawler.store_page(uri.to_s, text, @username, random_access_group, @time)
      @page = next_page
    end
  end

  def random_access_group
    x = rand()
    if x <= @P_public
      :public
    elsif x <= @P_public + @P_shared
      @groups[rand(@groups.size)] || :public
    else
      :private
    end
  end
end

class WikipediaCrawler
  DEFAULT_INITIALIZE_OPTIONS = {
    :users => 1000,
    :concurrent_downloads => 20,
    :groups => {},
  }
  def initialize(options = {})
    options  = DEFAULT_INITIALIZE_OPTIONS.merge(options)
    @users   = (0...options[:users]).map do |i|
      username = "user_#{i}"
      groups = [*((options[:groups] || {})[username])] + [username]
      User.new(username, groups, self, options)
    end
    @queue   = Queue.new
    options[:concurrent_downloads].times{ @queue.push(true) }
  end

  def fetch(num_pages)
    threads = []
    num_pages.times do
      threads << Thread.new do
        dl_token = @queue.pop  # once we get this, we can dl safely
        @users[rand(@users.size)].visit_next_page
        @queue.push(true)
      end
    end
    threads.each{|th| th.join}
  end

  # Turn the upload into an item and insert into the DB
  def store_page(url, contents, username, access_group, timestamp)
    puts "storing #{url} of size #{contents.size} by user #{username}, for #{access_group} at #{timestamp}"
  end

  def random_page
    %q[http://en.wikipedia.org/wiki/Special:Random]
  end

  def may_visit?(url)
    url =~ %r{http://en.wikipedia.org/wiki/[^:]+}
  end
end

end #  Simulation
end #  Future
