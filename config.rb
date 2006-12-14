
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
  c.database_configuration = database_conf[c.environment]
  # c.logger = Logger.new(c.log_dir + "#{c.environment}.log")
end
