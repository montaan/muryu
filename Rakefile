$:.unshift "lib" if File.directory? "lib"
require 'rake/testtask'

ENV["FUTURE_ROOT"] = "."
ENV["FUTURE_ENV"]  = "test"

def create_new_db(environment)
  Future.setup_environment(environment)
  conf = Future.database_configuration
  opts = []
  opts << "-h #{conf[:host]}" if conf[:host]
  opts << "-h #{conf[:port]}" if conf[:port]
  opts << "-U #{conf[:login]}" if conf[:login]
  sh "dropdb #{opts.join(" ")} #{conf[:database]} || true"
  sh "createdb #{opts.join(" ")} #{conf[:database]}"
  require 'future/database/dbconn'
  begin
    stderr = STDERR.clone
    STDERR.reopen("/dev/null")
    DB::Conn.exec DB::Creator.new(Dir[File.join("database", "*.rb")]).to_sql
  ensure
    STDERR.reopen(stderr)
  end
end

file "lib/future/query_grammar.rb" => "lib/future/query_grammar.racc" do |t|
  sh "racc -o #{t.name} #{t.prerequisites[0]}"
end

require 'future/config'
require 'future/database/creator'
namespace :db do
  namespace :test do
    desc "Create empty test database and load the schema."
    task(:prepare){ create_new_db("test") }
  end

  desc "Creates an empty development database."
  task(:clear){ create_new_db("development") }

  desc "Dump users, groups, items, etc. from development DB."
  task "dump" do
    rm_f "development.dump"

    %w[comments groups items items_groups items_sets items_tags itemtexts
       landmarks landmarks_groups metadata mimetypes sets sets_groups tags
       users users_groups].each do |table, i|
      sh "pg_dump -a -t #{table} future_development >> future_development.dump"
    end
  end

  desc "Drop indexes in development DB."
  task "drop_index" do
    sh "pg_dump -s future_development | grep INDEX | grep CREATE > index.schema"
    indexes = []
    File.foreach("index.schema") do |line|
      case line
      when /(?:CREATE UNIQUE|CREATE) INDEX (\S+)/
        indexes << $1
      else
        # ignore
      end
    end
    File.open(".drop-indexes.sql", "w") do |f|
      indexes.each{|name| f.puts "DROP INDEX #{name};"}
    end
    sh "psql future_development < .drop-indexes.sql"
  end

  desc "Create indexes in development DB."
  task "create_index" do
    sh "psql future_development < index.schema"
  end
end

desc "Run the functional and unit tests."
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end
task :test => "db:test:prepare"

namespace :test do
  Rake::TestTask.new(:unit) do |t|
    t.test_files = FileList['test/test*.rb'].to_a - ["test/test_milestones.rb"]
    t.verbose = true
  end
  task :unit => "db:test:prepare"

  Rake::TestTask.new(:milestones => "db:test:prepare") do |t|
    t.test_files = ["test/test_milestones.rb"]
    t.verbose = true
  end
  task :milestones => "db:test:prepare"
end

require 'rcov/rcovtask'
desc "Run rcov."
Rcov::RcovTask.new do |t|
  t.test_files = FileList['test/test_*.rb'].to_a.reject{|x| /test_functional/ =~ x}
  t.verbose = true
end
task :rcov => "db:test:prepare"

desc "Save current coverage state for later comparisons."
Rcov::RcovTask.new(:rcovsave) do |t|
  t.rcov_opts << "--save"
  t.test_files = FileList['test/test_*.rb'].to_a.reject{|x| /test_functional/ =~ x}
  t.verbose = true
end
task :rcovsave => "db:test:prepare"

task :default => :test
task :test => "lib/future/query_grammar.rb"

# vim: set sw=2 ft=ruby:
