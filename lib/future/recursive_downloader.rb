
require 'future/paths'
require 'future/utils'
require 'open-uri'
require 'hpricot'

module Future

class RecursiveDownloader
  def initialize(uri)
    @uri = uri
    @fetched = {}
    @redirected = {}
  end

  def download(options = {})
    actual_uri, io = fetch(@uri, options)
    fetch_recursive(actual_uri)
    @fetched.size
  end

  def fetch_references_html(uri)
    raise "No data for #{uri.to_s}." unless io = @fetched[uri]
    doc = Hpricot(io)
    %w[img script].each do |resource|
      doc.search(resource).each do |res|
        # FIXME: check type = "text/javascript", etc?
        if (src = res.attributes["src"])
          resolved_uri = uri.merge(src).normalize
          fetch(resolved_uri)
        end
      end
    end
    %w{//link[@type='text/css']}.each do |query|
      doc.search(query).each do |res|
        if (src = res.attributes["href"])
          resolved_uri = uri.merge(src).normalize
          next if @fetched[resolved_uri] || @redirected[resolved_uri]
          actual_uri, = fetch(resolved_uri)
          @redirected[resolved_uri] = actual_uri
          fetch_recursive(actual_uri)
        end
      end
    end
  end

  def fetch_references_css(uri)
    raise "No data for #{uri.to_s}." unless io = @fetched[uri]
  end

  def downloaded_files
    @fetched.keys
  end

  private
  def fetch(uri, options = {})
    io = OpenURI.open_loop(uri, options)
    @fetched[io.base_uri] = io
    [io.base_uri, io]
  end

  def fetch_recursive(uri)
    case @fetched[uri].content_type
    when %{text/html}
      fetch_references_html(uri)
    when %{text/css}
      fetch_references_css(uri)
    end
  end

end # RecursiveDownloader

end  # Future
