#!/usr/bin/env ruby
#
# MozSnapshooter
# Web site thumbnailer
#
# Copyright (C) 2005 Mirko Maischberger
# Released in the Public Domain
#
# From an idea by Andrew McCall - <andrew@textux.com>
# http://www.hackdiary.com/archives/000055.html

ENV["DISPLAY"] = ":15"

require 'gtk2'
require 'gtkmozembed'

class MozSnapshooter < Gtk::Window
  
  def initialize(location, target)
    super()
    self.title="MozSnapshooter"
    self.border_width = 1
    Gtk::MozEmbed.set_profile_path(ENV['HOME'] + '.mozilla', 'RubyGecko')
    self << Gtk::MozEmbed.new
    self.child.chrome_mask = Gtk::MozEmbed::ALLCHROME
    self.child.set_size_request(1280,1024)
    self.child.signal_connect("net_stop") { on_net_stop }
    self.child.location = location
    @target = target
    @countdown = 5

    # The user is bored, let's quit.
    self.signal_connect("destroy") do
      $stderr.print "closing...\n"
      Gtk.main_quit
    end

    self.show_all
  end
  
  def on_net_stop
    Gtk::timeout_add(1000) do
      @countdown -= 1
      if(@countdown > 0)
        puts @countdown
        true
      else
        screenshot(@target)
        false
      end
    end
  end
  
  def screenshot(target)
    gdkw = self.child.parent_window
    x, y, width, height, depth = gdkw.geometry
    width -= 16
    pixbuf = Gdk::Pixbuf.from_drawable(nil, gdkw, 0, 0, width, height)
    pixbuf.save(target,"png")
    puts "Wrote #{target}"
    Gtk.main_quit
  end
  
end

File.open('/tmp/.moz-snapshooter.lock','w') {|f|
  f.flock(File::LOCK_EX)
  MozSnapshooter.new ARGV[0], ARGV[1]
  Gtk.main
  f.flock(File::LOCK_UN)
}