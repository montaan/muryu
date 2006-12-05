require 'future/utils'
require 'pathname'


module Future


class Paths
  ROOT_DIR = Pathname.new(ENV["HOME"]).expand_path + '.future'
  CONFIG_FILE = ROOT_DIR + 'config.rb'
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


  attr_reader :root_dir, :config_file, :cache_dir, :thumbnail_dir, :items_dir
  pathname_writer :root_dir, :config_file, :cache_dir, :thumbnail_dir, :items_dir

  def initialize
    @root_dir = ROOT_DIR
    @config_file = CONFIG_FILE
    @cache_dir = DEFAULT_CACHE_DIR
    @thumbnail_dir = DEFAULT_THUMBNAIL_DIR
    @items_dir = DEFAULT_ITEMS_DIR
  end

end


class << self
  attr_accessor :paths
  delegate_accessor :paths, :root_dir, :config_file, :cache_dir, :thumbnail_dir, :items_dir
end
self.paths = Paths.new

load config_file.to_s if config_file.exist?

end
