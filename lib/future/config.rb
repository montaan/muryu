
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
  DEFAULT_LOG_DIR = ROOT_DIR + 'log'
  DEFAULT_CACHE_DIR = ROOT_DIR + 'cache'
  DEFAULT_THUMBNAIL_DIR = ROOT_DIR + 'thumbnails'
  DEFAULT_ITEMS_DIR = ROOT_DIR + 'items'

  def self.pathname_writer(*mnames)
    mnames.each do |mn|
      mn = mn.to_s
      ivar = "@#{mn}"
      define_method(mn+"=") do |arg|
        instance_variable_set(ivar, Pathname.new(arg.to_s))
      end
    end
  end


  attr_reader :root_dir, :config_file, :log_dir, :cache_dir, :thumbnail_dir, :items_dir
  pathname_writer :root_dir, :config_file, :log_dir, :cache_dir, :thumbnail_dir, :items_dir

  def initialize
    @root_dir = ROOT_DIR
    @config_file = CONFIG_FILE
    @log_dir = DEFAULT_LOG_DIR
    @cache_dir = DEFAULT_CACHE_DIR
    @thumbnail_dir = DEFAULT_THUMBNAIL_DIR
    @items_dir = DEFAULT_ITEMS_DIR
  end

end

class << self
  attr_accessor :salt
  attr_accessor :paths
  attr_reader   :environment
  attr_accessor :logger, :log_level, :database_configuration

  delegate_accessor :paths, :root_dir, :log_dir, :config_file, :cache_dir, :thumbnail_dir, :items_dir

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
    self.logger = nil
    if config_file.exist?
      load config_file
    end

    self.database_configuration  ||= default_database_configuration
    self.logger ||= default_logger
  end
end

setup_environment(ENV["FUTURE_ENV"] || "development")

end # Future
