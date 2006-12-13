$:.unshift "lib" if File.directory? "lib"
require 'rake/testtask'

desc "Run the functional and unit tests."
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

require 'rcov/rcovtask'
desc "Run rcov."
Rcov::RcovTask.new do |t|
  t.test_files = FileList['test/test_*.rb'].to_a.reject{|x| /test_functional/ =~ x}
  t.verbose = true
end

desc "Save current coverage state for later comparisons."
Rcov::RcovTask.new(:rcovsave) do |t|
  t.rcov_opts << "--save"
  t.test_files = FileList['test/test_*.rb'].to_a.reject{|x| /test_functional/ =~ x}
  t.verbose = true
end

task :default => :test

require 'future/config'
require 'future/database/creator'
namespace :db do
  namespace :test do
    desc "Create empty test database and load the schema."
    task :prepare do
      ENV["FUTURE_ENV"] = "test"
      Future::Config.load_environment
      conf = Future::Config
      opts = []
      opts << "-h #{conf.host}" if conf.host
      opts << "-h #{conf.port}" if conf.port
      opts << "-U #{conf.login}" if conf.login
      sh "dropdb #{opts.join(" ")} #{conf.database} || true"
      sh "createdb #{opts.join(" ")} #{conf.database}"
      require 'future/database/dbconn'
      DB.establish_connection(conf.host, conf.port, conf.options,
                              conf.database, conf.login, conf.password)
      begin
        stderr = STDERR.clone
        STDERR.reopen("/dev/null")
        DB::Conn.exec DB::Creator.new(Dir[File.join("database", "*.rb")]).to_sql
      ensure
        STDERR.reopen(stderr)
      end
    end
  end
end

task :test => "db:test:prepare"
task :rcov => "db:test:prepare"
task :rcov_save => "db:test:prepare"

# vim: set sw=2 ft=ruby:
