
require 'future/paths'
require 'future/utils'
require 'open-uri'
require 'hpricot'
require 'stringio'

module Future

class RecursiveDownloader
  def initialize(uri)
    @uri = uri
    @fetched = {}
    @redirected = {}
    @html_process_pending = {}
    @css_process_pending  = {}
  end

  def download(options = {})
    actual_uri, io = fetch(@uri, options)
    fetch_recursive(actual_uri)
    @fetched.size
  end

  def fetch_references_html(uri)
    raise "No data for #{uri.to_s}." unless io = @fetched[uri]
    uri2 = URI.parse(uri)
    doc = Hpricot(io)
    %w[img script].each do |resource|
      doc.search(resource).each do |res|
        # FIXME: check type = "text/javascript", etc?
        if (src = res.attributes["src"])
          resolved_uri = uri2.merge(src).normalize
          next if @fetched[resolved_uri.to_s] || @redirected[resolved_uri.to_s]
          next if resolved_uri.query.to_s != ''
          actual_uri, = fetch(resolved_uri)
          @redirected[resolved_uri.to_s] = actual_uri
        end
      end
    end
    %w{//link[@type='text/css']}.each do |query|
      doc.search(query).each do |res|
        if (src = res.attributes["href"])
          resolved_uri = uri2.merge(src).normalize
          next if @fetched[resolved_uri.to_s] || @redirected[resolved_uri.to_s]
          next if resolved_uri.query.to_s != ''
          actual_uri, = fetch(resolved_uri)
          @redirected[resolved_uri.to_s] = actual_uri
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

  BASIC_LINK_RESOLVER = lambda do |src, dest| 
    File.basename(dest.path)
  end

  def processed_file(uri, &resolver_block)
    resolver_block ||= BASIC_LINK_RESOLVER
    actual_uri = @redirected[uri.normalize.to_s].to_s
    case
    when @html_process_pending[actual_uri]
      StringIO.new(rewrite_html(actual_uri, &resolver_block))
    when @css_process_pending[actual_uri]
      StringIO.new(rewrite_css(actual_uri, &resolver_block))
    else
      @fetched[actual_uri]
    end
  end


  private
  REWRITE_ATTRIBUTE_DATA = {
    "//img" => "src", "//script" => "src", 
    "//a[@href]" => "href", "//link[@type='text/css']" => "href"
  }
  def rewrite_html(uri, &resolver_block)
    @fetched[uri.to_s].rewind
    doc = Hpricot(@fetched[uri.to_s].read)
    REWRITE_ATTRIBUTE_DATA.each_pair do |resource, attr|
      doc.search(resource).each do |res|
        if (src = res.attributes[attr])
          src = URI.parse(src)
          resolved_uri = URI.parse(uri).merge(src).normalize
          if (actual_uri = @redirected[resolved_uri.to_s])
            new_rel_uri = resolver_block.call(uri, actual_uri)
            res.attributes[attr] = new_rel_uri.to_s
          else
            res.attributes[attr] = resolved_uri.to_s
          end
        end
      end
    end
    doc.to_s
  end

  def fetch(uri, options = {})
    io = OpenURI.open_loop(uri, options)
    @fetched[io.base_uri.to_s] = io
    @redirected[uri.to_s] = io.base_uri
    [io.base_uri, io]
  end

  def fetch_recursive(uri)
    case @fetched[uri.to_s].content_type
    when %{text/html}
      @html_process_pending[uri.to_s] = true
      fetch_references_html(uri.to_s)
    when %{text/css}
      @css_process_pending[uri.to_s] = true
      fetch_references_css(uri.to_s)
    end
  end

end # RecursiveDownloader

end  # Future
