
require 'future/config'
require 'digest/sha1'
require 'fileutils'
require 'stringio'

module Future

# BasicStore only does three things:
# * save files in such a way that contents are not duplicated (unless you ask
#   it to)
# * tell you whether a given file is stored
# * allow you to read the data
class BasicStore
  class FileSelector
    attr_reader :path, :full_path, :sha1digest, :size
    DEFAULT_OPTIONS = {
      :sha1digest => nil,
      :path       => nil,
      :full_path  => nil,
      :size       => 0,
    }
    def initialize(options = {})
      options = DEFAULT_OPTIONS.merge(options)
      unless options[:sha1digest] || options[:path]
        raise ArgumentError, "Need either file path or sha1digest."
      end
      @path       = options[:path]
      @sha1digest = options[:sha1digest]
      @size       = options[:size]
      @full_path  = options[:full_path]
    end
  end

  DEFAULT_INIT_OPTIONS = {
    :default_name => "data",
    :levels => 2
  }
  def initialize(base_path = Future.items_dir, options = {})
    options = DEFAULT_INIT_OPTIONS.merge(options)
    @base_path    = base_path
    @default_name = options[:default_name]
    @levels       = options[:levels]
    FileUtils.mkdir_p(@base_path)
  end

=begin
maybe something like this?

  def store(io, filename=@default_name)
    fn = create_unique_filename(filename)
    (@base_path + fn).open('wb'){|f| f.write io.read(65536) until io.eof? }
    fn
  end

  def open(fn,*a,&b)
    fn = Pathname.new(fn) unless fn.is_a? Pathname
    full_fn = @base_path + fn
    full_fn.open(*a,&b)
  end

  def create_unique_filename(filename)
    today + (filename + "." + next_id)
  end

  def next_id
    DB.nextval('store_filename_seq')
  end

  def today
    Time.now.strftime("%Y-%m-%d")
  end
=end

  DEFAULT_STORE_OPTIONS = {
    :sha1digest => nil,
    :preserve_name => false,
  }

  # Stores the file, returning a FileSelector that references the data in the
  # store. +data+ is either a String or an IO (responds to #eof?, #read).
  # In order to save data associated to another file, give the sha1digest of
  # the parent and use preserve_name, e.g.
  #   mainselector = store.store("foo.html", html)
  #   gifselector  = store.store("foo.gif", gifdata, 
  #                              :sha1digest => mainselector.sha1digest, 
  #                              :preserve_name => true)
  def store(filename, data, options = {})
    options = DEFAULT_STORE_OPTIONS.merge(options)

    case data
    when String
      io = StringIO.new(data)
    else
      # data is assumed to be an IO (#read)
      io = data
    end

    digest   = options[:sha1digest]
    sha1     = Digest::SHA1.new unless digest
    size     = 0
    tmpname0 = File.join(permanent_dir, "tmp#{Process.pid}-#{Thread.object_id}")
    File.open(tmpname0, "wb") do |f|
      until io.eof?
        dat = io.read(65536)
        f.write(dat)
        sha1 << dat if sha1
        size += dat.size
      end
    end
    digest ||= sha1.hexdigest

    levels, rest = split_sha1(digest)
    relpath = File.join(File.join(*levels), rest)
    path    = File.join(transient_dir, relpath)

    FileUtils.mkdir_p(path)
    basename = options[:preserve_name] ? filename : @default_name
    dest     = File.join(path, basename)

    unless File.exist?(dest)
      tmpname  = File.join(path, "tmp#{Process.pid}-#{Thread.object_id}")
      FileUtils.mv(tmpname0, tmpname)
      File.rename(tmpname, dest)

      FileUtils.mkdir_p(File.join(permanent_dir, *levels))
      link_dst = File.join(permanent_dir, relpath)
      unless File.exist?(link_dst)
        FileUtils.ln_s(path, link_dst)
      end
    end

    FileSelector.new(:path => File.join(relpath, basename), 
                     :full_path => dest,
                     :sha1digest => digest, :size => size)
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
