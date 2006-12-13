require 'uri'

Dir[File.join(File.dirname(__FILE__), "**", "*.rb")].each do |file|
  file = File.expand_path(file)
  dest = URI.parse("file://" + file)
  base = URI.parse("file://" + File.expand_path(File.dirname(__FILE__)) + "/")
  require("future/" + base.route_to(dest).to_s)
end

