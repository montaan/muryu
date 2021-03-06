#!/usr/bin/ruby

require 'future/config'
require 'json'

server_name = 'http://localhost:8080'
secure_server_name = 'https://localhost:8081'

js_files = File.read('js.bundle').strip.split(/\s+/)
css_files = File.read('css.bundle').strip.split(/\s+/)

js = js_files.map{|f| File.read(f) }.join("\n")
js.gsub!(server_name, Future.server_name)
js.gsub!(secure_server_name, Future.secure_server_name)
js.gsub!("['/tile/']", Future.tile_servers.to_json)

css = css_files.map{|f| File.read(f) }.join("\n")

js_bundle_fn = "/muryu-#{js_files.map{|f| File.stat(f).mtime }.max.strftime("%Y-%m-%d-%H-%M-%S")}.js"
css_bundle_fn = "/muryu-#{css_files.map{|f| File.stat(f).mtime }.max.strftime("%Y-%m-%d-%H-%M-%S")}.css"

html = File.read('html/index.html.in')
html.gsub!(/__JS_BUNDLE__/, js_bundle_fn)
html.gsub!(/__CSS_BUNDLE__/, css_bundle_fn)
File.open('html' + js_bundle_fn,'w') {|f| f.write js }
File.open('html' + css_bundle_fn,'w') {|f| f.write css }
File.open('html/index.html','w') {|f| f.write html }
