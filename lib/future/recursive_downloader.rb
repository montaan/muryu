
require 'future/config'
require 'future/utils'
require 'open-uri'
require 'hpricot'
require 'stringio'

module Future

class RecursiveDownloader
  attr_accessor :toplevel
  def initialize(uri)
    @uri = uri
    @fetched = {}
    @redirected = {}
    @html_process_pending = {}
    @css_process_pending  = {}
    @toplevel = nil
  end

  def download(options = {})
    actual_uri, io = fetch(@uri, options)
    @toplevel = actual_uri.to_s
    fetch_recursive(actual_uri)
    @fetched.size
  end

  def downloaded_files
    @fetched.keys
  end

  BASIC_LINK_RESOLVER = lambda do |src, dest, io| 
    File.basename(dest.path)
  end

  def processed_file(uri, &resolver_block)
    uri = URI.parse(uri.to_s).normalize.to_s
    resolver_block ||= BASIC_LINK_RESOLVER
    actual_uri = @redirected[uri]
    case
    when @html_process_pending[actual_uri.to_s]
      StringIO.new(rewrite_html(actual_uri, &resolver_block))
    when @css_process_pending[actual_uri.to_s]
      StringIO.new(rewrite_css(actual_uri, &resolver_block))
    else
      io = @fetched[actual_uri.to_s].clone
      io.rewind
      io
    end
  end


  private
  def fetch_references_html(uri)
    log_debug("Fetching references from HTML: #{uri}", "recursive_downloader")
    uri = URI.parse(uri.to_s).normalize.to_s
    raise "No data for #{uri}." unless io = @fetched[uri]
    uri2 = URI.parse(uri)
    doc = Hpricot(io)
    fetch_references_html_src(uri2, doc)
    fetch_references_html_href(uri2, doc)
    fetch_embedded_style_imports(uri2, doc)
  end

  def fetch_embedded_style_imports(uri, doc)
    doc.search("//style[@type='text/css']") do |res|
      fetch_references_from_css_code(uri, res.inner_html)
    end
  end

  def fetch_references_html_src(uri, doc)
    %w[img script].each do |resource|
      doc.search(resource).each do |res|
        # FIXME: check type = "text/javascript", etc?
        if (src = res.attributes["src"])
          resolved_uri = uri.merge(src).normalize
          next if @fetched[resolved_uri.to_s] || @redirected[resolved_uri.to_s]
          next if resolved_uri.query.to_s != ''
          actual_uri, = fetch(resolved_uri)
          @redirected[resolved_uri.to_s] = actual_uri
        end
      end
    end
  end

  def fetch_references_html_href(uri, doc)
    %w{//link[@type='text/css']}.each do |query|
      doc.search(query).each do |res|
        if (src = res.attributes["href"])
          resolved_uri = uri.merge(src).normalize
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
    log_debug("Fetching references from CSS: #{uri}", "recursive_downloader")
    uri2  = URI.parse(uri.to_s).normalize
    uri   = uri2.to_s
    raise "No data for #{uri}." unless io = @fetched[uri]
    io.rewind
    fetch_references_from_css_code(uri2, io.read)
    io.rewind
  end

  def fetch_references_from_css_code(uri, csscode)
    child_uris = csscode.scan(/@import\s+url\(([^)]+)\)/).flatten
    child_uris.concat(csscode.scan(/@import\s+"([^"]+)"/).flatten)
    # ugh
    child_uris.concat(csscode.scan(/@import\s+'([^"]+)'/).flatten)
    child_uris.each do |child_uri|
      resolved_uri = uri.merge(child_uri).normalize
      next if @fetched[resolved_uri.to_s] || @redirected[resolved_uri.to_s]
      next if resolved_uri.query.to_s != ''
      actual_uri, = fetch(resolved_uri)
      @redirected[resolved_uri.to_s] = actual_uri
      fetch_recursive(actual_uri)
    end
  end

  REWRITE_ATTRIBUTE_DATA = {
    "//img" => "src", "//script" => "src", 
    "//a[@href]" => "href", "//link[@type='text/css']" => "href"
  }
  def rewrite_html(uri, &resolver_block)
    log_debug("Rewriting HTML #{uri}", "recursive_downloader")
    uri = URI.parse(uri.to_s).normalize.to_s
    @fetched[uri].rewind
    doc = Hpricot(@fetched[uri].read)
    REWRITE_ATTRIBUTE_DATA.each_pair do |resource, attr|
      doc.search(resource).each do |res|
        if (src = res.attributes[attr])
          src = URI.parse(src)
          resolved_uri = URI.parse(uri).merge(src).normalize
          if (actual_uri = @redirected[resolved_uri.to_s])
            io = @fetched[uri].clone
            io.rewind
            new_rel_uri = resolver_block.call(uri, actual_uri, io)
            res.attributes[attr] = new_rel_uri.to_s
          else
            res.attributes[attr] = resolved_uri.to_s
          end
        end
      end
    end
    doc.to_s
  end

  def rewrite_css(uri, &resolver_block)
    log_debug("Rewriting CSS #{uri}", "recursive_downloader")
    uri2 = URI.parse(uri.to_s).normalize
    uri  = uri2.to_s
    io   = @fetched[uri].clone
    io.rewind
    data = io.read

    data.gsub(/@import\s+(url\([^)]+\)|"[^"]+"|'[^']+')/) do |import_txt|
      rel_uri = /@import\s+(?:url\(([^)]+)\)|"([^"]+)"|'([^']+)')/.match(import_txt).captures.compact[0]
      resolved_uri = uri2.merge(rel_uri).normalize
      if (actual_uri = @redirected[resolved_uri.to_s])
        io.rewind
        new_rel_uri = resolver_block.call(uri, actual_uri, io)
        %{@import "#{new_rel_uri.to_s}"}
      else
        "@import url(#{resolved_uri.to_s})"
      end
    end
  end

  def fetch(uri, options = {})
    log_debug("Fetching #{uri.inspect}", "recursive_downloader")
    io = OpenURI.open_loop(uri, options)
    @fetched[io.base_uri.normalize.to_s] = io
    @redirected[uri.normalize.to_s] = io.base_uri.normalize
    log_debug("Redirection #{uri} -> #{io.base_uri.to_s}", "recursive_downloader")
    [io.base_uri.normalize, io]
  end

  def fetch_recursive(uri)
    uri = @redirected[URI.parse(uri.to_s).normalize.to_s].to_s
    case @fetched[uri].content_type
    when %{text/html}
      @html_process_pending[uri] = true
      fetch_references_html(uri)
    when %{text/css}
      @css_process_pending[uri] = true
      fetch_references_css(uri)
    end
  end

end # RecursiveDownloader

end  # Future
