

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
      io = @fetched[uri] = StringIO.new(data)
      class << io; self end.module_eval do 
        define_method(:content_type) { content_type }
      end
      [uri, io]
    end
  end

  def test_recursive_download
    base = File.expand_path(File.dirname(__FILE__))
    uri = URI.parse("file://" + (File.join(base, "data", "recursive-dler.html")))
    fetcher = DummyRecursiveDownloader.new(uri)
    fetcher.set_contents(uri, File.read(uri.path), "text/html")
    num_files = fetcher.download(:proxy => false)
  files = <<EOF
/data/hiki.rb?c=plugin;plugin=math_roff_download;p=eigenclass.org+node+classification;file_name=2c1743a391305fbf367df8e4f069f9f9.png
/data/hiki.rb?c=plugin;plugin=math_roff_download;p=eigenclass.org+node+classification;file_name=7a56e6ad28c1050e776a63e85e8fae7c.png
/data/hiki.rb?c=plugin;plugin=math_roff_download;p=eigenclass.org+node+classification;file_name=e1454c34fe0a5719ac9e0164ecf95f6b.png
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

end

