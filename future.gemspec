require './lib/future.rb'
require 'rake'

version = Future::VERSION
date = Time.now.strftime("%Y-%m-%d")

Gem::Specification.new do |s|
  s.name = 'future'
  s.version = version
  s.date = date
  s.files = FileList[
    'lib/**/*.rb'
  ].to_a
  s.executables << 'future-image-cache-regenerate'
  s.required_ruby_version = '>= 1.8.1'
end
