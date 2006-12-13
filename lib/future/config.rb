
require 'yaml'

module Future

module Config
  class << self; attr_reader :host, :port, :options, :database, :login, :password end

  DEFAULT_ENVIRONMENT_FILE = File.expand_path(File.join(File.dirname(__FILE__),
                                                        "..", "..", "environment.yaml"))
  def self.load_environment(filename = DEFAULT_ENVIRONMENT_FILE, environment = ENV["FUTURE_ENV"] || "development")
    if File.exist?(filename)
      data = YAML.load(File.read(filename))
      env_info = data[environment]
      if env_info
        @host, @port, @options, @database, @login, @password =
          env_info.values_at(*%w[host port options database login password])
      else
        raise "No information for the #{environment} environment in #{filename}."
      end
    else
      raise ArgumentError, "#{filename} does not exist"
    end
  end
end

end # Future
