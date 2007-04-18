%w(items files sets users groups tile tile_info).each do |f|
  require "future/web/webapi/#{f}.rb"
end