

require 'test/unit'
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
$:.unshift "lib"

require 'future/recursive_downloader.rb'

class TestRecursiveDownloader < Test::Unit::TestCase
  include Future
  class DummyURI
    attr_reader :path
    def initialize(path, content_type = "application/octet-stream")
      @path = File.expand_path(path)
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

    def to_s
      URI.parse("file://" + @path).to_s
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
    uri = DummyURI.new(File.join(File.expand_path(File.dirname(__FILE__)), 
                                 "data", "recursive-dler.html"))
    fetcher = RecursiveDownloader.new(uri)
    num_files = fetcher.download(:proxy => false)
    assert_equal(1, num_files)
  end

  def test_download_recursive
    uri = DummyURI.new(File.join(File.expand_path(File.dirname(__FILE__)), 
                                 "data", "recursive-dler.html"),
                       "text/html")
    fetcher = LoggedRecursiveDownloader.new(uri)
    num_files = fetcher.download(:proxy => false)
    assert_equal(1, num_files)
    assert_equal({:fetch_references_html => [["file:#{uri.path}"]]}, fetcher.calls)

    uri = DummyURI.new(File.join(File.dirname(__FILE__), "data", "recursive-dler.html"),
                       "text/css")
    fetcher = LoggedRecursiveDownloader.new(uri)
    num_files = fetcher.download(:proxy => false)
    assert_equal(1, num_files)
    assert_equal({:fetch_references_css => [["file:#{uri.path}"]]}, fetcher.calls)
  end


  class DummyRecursiveDownloader < Future::RecursiveDownloader
    def set_contents(uri, data, content_type = "application/octect-stream")
      @contents ||= {}
      @contents[uri] = [data, content_type]
    end

    def get_contents(uri)
      (@contents ||= {})[uri] || ["", "application/octect-stream"]
    end

    def fetch(uri, options = {})
      data, content_type = get_contents(uri)
      io = @fetched[uri.to_s] = StringIO.new(data)
      @redirected[uri.to_s] = uri
      class << io; self end.module_eval do 
        define_method(:content_type) { content_type }
      end
      [uri, io]
    end
  end

  def test_recursive_download_basic
    base = File.expand_path(File.dirname(__FILE__))
    uri = URI.parse("file://" + (File.join(base, "data", "recursive-dler.html")))
    fetcher = DummyRecursiveDownloader.new(uri)
    fetcher.set_contents(uri, File.read(uri.path), "text/html")
    num_files = fetcher.download(:proxy => false)
  files = <<EOF
/data/recursive-dler.html
/data/theme/dot-sky2/dot-sky2.css
/data/theme/hiki_base.css
file:/loading.gif
file:/logo.png
http://eigenclass.org/update.png
http://eigenclass.org/xml.png
EOF
    assert_equal(files.split(/\n/), fetcher.downloaded_files.map{|x| x.to_s.gsub(/^file:#{base}/,"")}.sort)
  end

  def test_processed_file
    base = File.expand_path(File.dirname(__FILE__))
    base_uri = URI.parse("file://" + File.join(base, "data/"))
    uri = base_uri + "recursive-downloader2.html"
    fetcher = DummyRecursiveDownloader.new(uri)
    fetcher.set_contents(uri, File.read(uri.path), "text/html")
    fetcher.set_contents(base_uri + "css/test.css", "css/test.css", "text/css")
    fetcher.set_contents(base_uri + "test.css", "test.css", "text/css")
    fetcher.set_contents(base_uri + "pics/foo.gif", "pics/foo.gif", "image/gif")
    fetcher.set_contents(base_uri + "foo/bar/baz.html", "foo/bar/baz.html", "text/html")
    num_files = fetcher.download(:proxy => false)
    assert_equal(4, num_files)
    processed_file = File.join(File.expand_path(File.dirname(__FILE__)), "data", "recursive-downloader2-processed.html")
    assert_equal(File.read(processed_file),
                 fetcher.processed_file(uri).string)
  end

end

