
require 'future/utils'
require 'fileutils'
require 'pathname'
require 'logger'


module Future

class Paths
  if ENV["FUTURE_ROOT"]
    ROOT_DIR = Pathname.new(ENV["FUTURE_ROOT"]).expand_path
  else
    ROOT_DIR = Pathname.new(ENV["HOME"]).expand_path + '.future'
  end
  CONFIG_FILE = ROOT_DIR + 'config.rb'
  LOG_DIR = ROOT_DIR + 'log'
  CACHE_DIR = ROOT_DIR + 'cache'
  THUMBNAIL_DIR = ROOT_DIR + 'thumbnails'
  TILE_CACHE_DIR = ROOT_DIR + 'tile_cache'
  ICON_DIR = ROOT_DIR + 'icons'
  ITEMS_DIR = ROOT_DIR + 'items'

  def self.pathname_writer(*mnames)
    mnames.each do |mn|
      mn = mn.to_s
      ivar = "@#{mn}"
      define_method(mn+"=") do |arg|
        instance_variable_set(ivar, Pathname.new(arg.to_s))
      end
    end
  end

  attr_reader(*constants.map{|c| c.downcase})
  pathname_writer(*constants.map{|c| c.downcase})

  def initialize
    self.class.constants.each do |c|
      instance_variable_set("@"+c.downcase, self.class.const_get(c))
    end
  end

end

class << self
  attr_accessor :salt
  attr_accessor :paths, :domain, :server_name, :secure_server_name, :tile_servers
  attr_accessor :empty_tile, :image_cache
  attr_reader   :environment
  attr_accessor :logger, :log_level, :database_configuration

  delegate_accessor :paths, Paths.constants.map{|c| c.downcase}

  def configuration(&block)
    yield self
  end

  def default_database_configuration 
    {
      :host => nil, :port => nil, :options => nil, :database => nil,
      :login => nil, :password => nil
    }
  end

  def default_logger
    FileUtils.mkdir_p(log_dir)
    logger = Logger.new(log_dir + "#{environment}.log")
    logger.level = log_level
    logger
  end


  def setup_environment(environment)
    @environment = environment
    @log_level   = @environment == "production" ? Logger::INFO : Logger::DEBUG
    self.paths = Paths.new
    self.database_configuration = nil # reset so we can see if they were modified
    self.empty_tile = tile_cache_dir + 'empty.jpg'
    self.logger = nil
    if config_file.exist?
      load config_file
    end

    self.database_configuration  ||= default_database_configuration
    self.logger ||= default_logger
    self.domain ||= '.fhtr.org'
    self.server_name ||= 'http://manifold.fhtr.org:8080'
    self.secure_server_name ||= 'https://manifold.fhtr.org:8081'
    self.tile_servers ||= [
      'http://t0.manifold.fhtr.org:8080/tile/',
      'http://t1.manifold.fhtr.org:8080/tile/',
      'http://t2.manifold.fhtr.org:8080/tile/',
      'http://t3.manifold.fhtr.org:8080/tile/'
    ]
  end
end

setup_environment(ENV["FUTURE_ENV"] || "development")

end # Future
