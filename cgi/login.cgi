#!/usr/bin/ruby
require 'future'

include Future

cgi = CGI.new
cgi.login!
