

require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift "lib"

require 'future/recursive_downloader.rb'

class TestRecursiveDownloader < Test::Unit::TestCase
  include Future
  class DummyURI
    def initialize(path, content_type = "application/octet-stream")
      @path = path
      @content_type = content_type
    end

    def buffer_open(buf, proxy, options)
      File.open(@path, "rb") do |f|
        until f.eof?
          buf << f.read(4096)
        end
      end
      content_type = @content_type
      class << buf.io; self end.module_eval do 
        define_method(:content_type) { content_type }
      end
      buf
    end
  end

  class LoggedRecursiveDownloader < Future::RecursiveDownloader
    attr_reader :calls
    def record_call(meth, *args)
      @calls ||= Hash.new{|h,k| h[k] = [] }
      @calls[meth] << args
    end
    
    def fetch_references_html(*a); record_call(:fetch_references_html, *a) end
    def fetch_references_css(*a); record_call(:fetch_references_css, *a) end
  end

  def test_download
    uri = DummyURI.new(File.join(File.dirname(__FILE__), "data", "recursive-dler.html"))
    fetcher = RecursiveDownloader.new(uri)
    num_files = fetcher.download(:proxy => false)
    assert_equal(1, num_files)
  end

  def test_download_recursive
    uri = DummyURI.new(File.join(File.dirname(__FILE__), "data", "recursive-dler.html"),
                       "text/html")
    fetcher = LoggedRecursiveDownloader.new(uri)
    num_files = fetcher.download(:proxy => false)
    assert_equal(1, num_files)
    assert_equal({:fetch_references_html => [[uri]]}, fetcher.calls)

    uri = DummyURI.new(File.join(File.dirname(__FILE__), "data", "recursive-dler.html"),
                       "text/css")
    fetcher = LoggedRecursiveDownloader.new(uri)
    num_files = fetcher.download(:proxy => false)
    assert_equal(1, num_files)
    assert_equal({:fetch_references_css => [[uri]]}, fetcher.calls)
  end
end

