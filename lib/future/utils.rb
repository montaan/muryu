
begin
  require 'rubygems'
rescue LoadError
end

require 'cgi'
require 'uri'
require 'pathname'
require 'fileutils'
require 'ostruct'

require 'logger'
module Kernel
  def log(message, subsystem = "", level = Logger::INFO)
    if block_given?
      begin
        t0 = Time.new
        ret = yield message
        dt = Time.new - t0
      ensure
        Future.logger.log(level, "#{subsystem} (#{dt})   #{message.strip}")
        Future.logger.log(Logger::DEBUG, caller.join("\n")) if $DEBUG
      end
      ret
    else
      Future.logger.log(level, "#{subsystem}   #{message.strip}")
      Future.logger.log(Logger::DEBUG, caller.join("\n")) if $DEBUG
    end
  end

  def log_info(message, subsystem = nil, &block)
    subsystem ||= File.basename(caller(1).first[/([^:]+)\.rb:/, 1] || caller(1).first)
    log(message, subsystem, Logger::INFO, &block) 
  end

  def log_debug(message, subsystem = nil, &block)
    subsystem ||= File.basename(caller(1).first[/([^:]+)\.rb:/, 1] || caller(1).first)
    log(message, subsystem, Logger::DEBUG, &block)
  end

  def pn(str, *args)
    str.to_s.to_pn(*args)
  end
  
end


class Symbol

  def to_proc
    lambda{|a| a.__send__(self) }
  end

end


class Array

  def to_proc
    lambda{|a| inject(a){|o,msg| o.__send__(*msg) } }
  end
  
end


class String

  def to_proc
    lambda{|a| eval(sprintf(self, a)) } # ha ha ha </robot voice>
  end

  def to_pn(*rest)
    pn = Pathname.new(self)
    pn = pn.join(*rest) unless rest.empty?
    pn
  end

end


class Range

  def [](i)
    self.begin + i
  end

end


class Pathname

  def to_pn(*rest)
    pn = self
    pn = pn.join(*rest) unless rest.empty?
    pn
  end

  def mkdir_p
    FileUtils.mkdir_p(to_s)
  end

  def glob(subpath, *args)
    self.class.glob((self+subpath).to_s, *args)
  end

end


class Module

  def attr_accessor_delegate(*method_names, &delegate)
    method_names.each{|mn|
      setter = "#{mn}=".to_sym
      block_delegate mn, setter, &delegate
    }
  end

  def ivar_delegate(ivar_name, *method_names)
    method_names.each{|mn|
      define_method(mn){|*args|
        instance_variable_get(ivar_name).__send__(mn, *args)
      }
    }
  end

  def ivar_accessor_delegate(ivar_name, *method_names)
    method_names.each{|mn|
      define_method(mn){|*args| instance_variable_get(ivar_name).__send__(mn,*args) }
      setter = "#{mn}=".to_sym
      define_method(setter){|*args|
        instance_variable_get(ivar_name).__send__(setter,*args)
      }
    }
  end

  def delegate(target, *mnames)
    mnames.each{|mn|
      args = "*a, &b"
      args = "a" if mn.to_s[-1,1] == "="
      class_eval <<-EOF
        def #{mn}(#{args})
          #{target}.#{mn}(#{args})
        end
      EOF
    }
  end
      
  def delegate_accessor(target, *mnames)
    delegate(target, *mnames.map{|mn| [mn, "#{mn}="]  }.flatten)
  end

  def block_delegate(*method_names, &delegate)
    method_names.each{|mn|
      define_method(mn){|*args|
        instance_eval(&delegate).__send__(mn,*args)
      }
    }
  end

end


class Array

  def cjoin(*a)
    compact.join(*a)
  end

end


class String

  def js_utf8
    gsub(/(%u\w{4})/){|u|"&##{u[2..-1].hex};"}
  end

  def split_lines(line_size=24)
    CGI.escapeHTML(js_utf8).gsub(/(?:(?:&[#0-9a-z]+;|\S){#{line_size}})\S+/i){|s|
      s.scan(/(?:(?:&[#0-9a-z]+;|\S){1,#{line_size}})/i).join("<wbr/>")
    }
  end

  def rgba
    components = scan(/[0-9a-z][0-9a-z]/i).map{|i|i.hex}
    components << 255 until components.size > 3
    Imlib2::Color::RgbaColor.new components[0,4]
  end

  def unmag(magnitudes = Numeric::MAGNITUDES)
    s = strip
    factor = 1
    if ind = (s =~ /[a-z]+$/i)
      mag = s.slice!(ind..-1)[0,1]
      factor = 1000**magnitudes.map{|m|m.downcase}.index(mag.downcase).to_i
    end
    (s.to_f * factor).to_i
  end

end


class Numeric

  MAGNITUDES = %w(k M G T P E Z Y)

  def mag(last="B", acc=1, magnitudes = MAGNITUDES)
    i = to_f
    if i < 1000
      return i.to_i.to_s+last
    end
    mag_index = (Math.log(i) / Math.log(1000)).to_i
    ("%.#{acc}f" % [i / 1000.0**mag_index]) + magnitudes[mag_index-1]
  end

end

# done at the end, since future/config depends on stuff defined here
require 'future/config'
