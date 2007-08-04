
database_conf = 
{
  "test" => {
    :host => nil, :port => nil, :options => nil, :database => "future_test",
    :login => nil, :password => nil
  },
  "development" => {
    :host => nil, :port => nil, :options => nil, :database => "future_development",
    :login => nil, :password => nil
  },
  "production" => {
    :host => nil, :port => nil, :options => nil, :database => "future_production",
    :login => nil, :password => nil
  },
}


Future.configuration do |c|
  # c.database_configuration = database_conf[c.environment]
  # c.logger = Logger.new(c.log_dir + "#{c.environment}.log")

  c.domain = "manifold.fhtr.org"
  c.server_name        =  "http://manifold.fhtr.org:8080"
  c.secure_server_name = "https://manifold.fhtr.org:8081"
  if $tile_subdomains
    c.tile_servers = $tile_subdomains.map{|ts| 
      c.server_name.sub(/^http:\/\//, "http://#{ts}.") + "/tile/" 
    }
  else
    c.tile_servers = [ c.server_name + "/tile/" ]
  end
end
