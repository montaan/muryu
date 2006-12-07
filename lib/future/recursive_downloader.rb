
require 'future/paths'
require 'open-uri'

module Future

class RecursiveDownloader
  def initialize(uri)
    @uri = uri
    @fetched = {}
  end

  def download(options = {})
    actual_uri, io = fetch(@uri, options)
    fetch_recursive(actual_uri)
    @fetched.size
  end

  def fetch(uri, options = {})
    io = OpenURI.open_loop(uri, options)
    @fetched[io.base_uri] = io
    [io.base_uri, io]
  end

  def fetch_references_html(uri)
    raise "No data for #{uri.to_s}." unless @fetched[uri]
  end

  def fetch_references_css(uri)
    raise "No data for #{uri.to_s}." unless @fetched[uri]
  end

  private
  def fetch_recursive(uri)
    case @fetched[uri].content_type
    when %{text/html}
      fetch_references_html(uri)
    when %{text/css}
      fetch_references_css(uri)
    end
  end
end
end  # Future
