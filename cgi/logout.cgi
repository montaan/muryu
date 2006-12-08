#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
c.logout!
