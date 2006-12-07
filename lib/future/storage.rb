
require 'future/paths'
require 'digest/sha1'
require 'fileutils'

module Future

class BasicStore
  class FileSelector
    attr_reader :path, :sha1digest
    DEFAULT_OPTIONS = {
      :sha1digest => nil,
      :path       => nil,
    }
    def initialize(options = {})
      options = DEFAULT_OPTIONS.merge(options)
      unless options[:sha1digest] || options[:path]
        raise ArgumentError, "Need either file path or sha1digest."
      end
      @path       = options[:path]
      @sha1digest = options[:sha1digest]
    end
  end

  DEFAULT_INIT_OPTIONS = {
    :default_name => "data",
    :levels => 2
  }
  def initialize(base_path = Paths.items_dir, options = {})
    options = DEFAULT_INIT_OPTIONS.merge(options)
    @base_path    = base_path
    @default_name = options[:default_name]
    @levels       = options[:levels]
    FileUtils.mkdir_p(@base_path)
  end

  DEFAULT_STORE_OPTIONS = {
    :sha1digest => nil,
    :preserve_name => false,
  }
  def store(filename, data, options = {})
    options = DEFAULT_STORE_OPTIONS.merge(options)
    digest  = options[:sha1digest] || Digest::SHA1.hexdigest(data)

    levels, rest = split_sha1(digest)
    relpath = File.join(File.join(*levels), rest)
    path    = File.join(transient_dir, relpath)

    FileUtils.mkdir_p(path)
    basename = options[:preserve_name] ? filename : @default_name
    dest     = File.join(path, basename)

    return nil if File.exist?(dest)

    tmpname  = File.join(path, "#{Process.pid}-#{Thread.object_id}")
    File.open(tmpname, "wb"){|f| f.write data}
    File.rename(tmpname, dest)

    FileUtils.mkdir_p(File.join(permanent_dir, *levels))
    link_dst = File.join(permanent_dir, relpath)
    unless File.exist?(link_dst)
      FileUtils.ln_s(path, link_dst)
    end

    FileSelector.new(:path => File.join(relpath, basename), 
                     :sha1digest => digest)
  end

  def read(fileselector)
    fh = open(fileselector)
    fh.read
  ensure
    fh.close if fh
  end

  def open(fileselector)
    if (sha1 = fileselector.sha1digest)
      levels, rest = split_sha1(sha1)
      basename = File.basename(fileselector.path || @default_name)
      File.open(File.join(File.join(@base_path, *levels), rest, basename), "rb")
    else
      File.open(File.join(@base_path, fileselector.path), "rb")
    end
  end

  def include?(fileselector)
    if (sha1 = fileselector.sha1digest)
      levels, rest = split_sha1(sha1)
      File.exist?(File.join(@base_path, File.join(*levels), rest))
    else
      File.exist?(File.join(@base_path, fileselector.path))
    end
  end

  private
  def transient_dir
    File.join(@base_path, Time.now.strftime("%Y-%m-%d"))
  end

  def permanent_dir
    @base_path
  end

  def split_sha1(hexdigest)
    re_pref = "(..)" * @levels
    captures = /#{re_pref}(.*)$/.match(hexdigest).captures
    [captures[0..-2], captures[-1]]
  end
end

end #  Future
