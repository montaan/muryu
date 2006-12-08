#!/usr/bin/ruby
require 'future'

include Future

c = CGI.new
user = c.authenticated? || Users.anonymous

config = {
  :tags => c['tags'],
  :sets => c['sets'],
  :groups => c['groups'],
  :user => user
}

Items.add_text(c['text'], config)
Items.add_local_files(c['local_file'], config)
Items.add_local_archives(c['local_archive'], config)
Items.add_urls(c['url'], config)
Items.add_archive_urls(c['archive_url'], config)

c.print c.header("type" => 'text/plain')
c.print 'OK'

