
require 'future/imaging/image_cache'
require 'future/imaging/tile_drawer'
require 'digest/sha1'
require 'imlib2'
require 'enumerator'

class TileJobRequest < Struct.new(:jobid, :x, :y, :w, :h, :zoom, :draw_ops)
end

class TileJobResult < Struct.new(:jobid, :x, :y, :raw_data)
end

class DTileClient
  TUPLE_EXPIRATION_TIME = 10 # seconds
  def initialize(tuplespace, tile_drawer)
    @tuplespace = tuplespace
    @tile_drawer = tile_drawer
  end

  def draw_tile(indexes, layouter_name, x, y, zoom, w, h, *layouter_args)
    draw_ops = []
    log_debug("Tile layout") do
      @tile_drawer.tile_info(indexes, layouter_name, x, y, zoom, w, h, *layouter_args) do |i, ix, iy, sz|
        draw_ops.concat([ix, iy, i])
      end
    end

    jobid   = "#{Process.pid}#{Thread.current.object_id}-#{x}-#{y}-#{w}-#{h}"
    tilejob = TileJobRequest.new(jobid, x, y, w, h, zoom, draw_ops)
    log_debug("Placing request #{jobid} (#{w}x#{h})") do
      @tuplespace.write([:tilejob_request, jobid, tilejob], TUPLE_EXPIRATION_TIME)
    end
    result = nil
    log_debug("Reading result") do
      result = @tuplespace.read([:tilejob_result, jobid, nil])[2]
    end
    tile   = Imlib2::Image.new(w, h)
    tile.data = result.raw_data
    tile
  end
end

class DTileServer
  MAX_THUMBS_PER_JOB    = 16
  TUPLE_EXPIRATION_TIME = 10 # seconds

  def initialize(tuplespace, image_cache = Future.image_cache, 
                 max_thumbs_per_job = MAX_THUMBS_PER_JOB, branching_factor = 4)
    @tuplespace         = tuplespace
    @image_cache        = image_cache
    @max_thumbs_per_job = max_thumbs_per_job
    @branching_factor   = branching_factor
  end

  Thread.abort_on_exception = true
  def thread
    Thread.new do
      while true
        tuple = @tuplespace.take([:tilejob_request, nil, nil])
        log_debug("Got tilejob request #{tuple[2].jobid}")
        process_tilejob(tuple[2])
      end
    end
  end

  def process_tilejob(tilejob)
    if tilejob.draw_ops.size/3 > @max_thumbs_per_job
      split_tilejob(tilejob)
    else
      sz = 2 ** tilejob.zoom
      log_debug("Drawing tile (#{tilejob.x},#{tilejob.y}) #{tilejob.w}x#{tilejob.h}")

      tile = Imlib2::Image.new(tilejob.w, tilejob.h)
      tile.clear
      @image_cache.batch do
        tilejob.draw_ops.each_slice(3) do |ix, iy, index|
          @image_cache.draw_image_at(index, tilejob.zoom, tile, ix, iy)
        end
      end
      # FIXME: rescue exception
      tilejob_result = TileJobResult.new(tilejob.jobid, tilejob.x, tilejob.y, 
                                         tile ? tile.data! : nil)
      log_debug("Placing result for #{tilejob.jobid}")
      @tuplespace.write([:tilejob_result, tilejob.jobid, tilejob_result], 
                        TUPLE_EXPIRATION_TIME)
    end
  end

  def split_tilejob(tilejob)
    w    = tilejob.w
    h    = tilejob.h
    jobs = []
    thsz = 2 ** tilejob.zoom

    log_debug("Splitting tilejob #{tilejob.jobid} (#{w}x#{h}) #{tilejob.draw_ops.size/3} drawops @ zoom #{tilejob.zoom}")
    subtile_matrix = (0...@branching_factor).map{ (0...@branching_factor).map{[]} }
    subw = tilejob.w / @branching_factor
    subh = tilejob.h / @branching_factor
    tilejob.draw_ops.each_slice(3) do |ix, iy, index|
      subtile_matrix[(ix - tilejob.x) / subw][(iy - tilejob.y) / subh] << [ix, iy, index]
    end
    log_debug("Subtile matrix':\n" + 
              subtile_matrix.map{|col| col.map{|x| "%4d" % x.size}.join(" ") }.join("\n"))

    empty_img = Imlib2::Image.new(subw, subh)
    empty_img.clear
    empty_subtile_data = empty_img.data!

    results = []

    subtile_matrix.each_with_index do |column, i|
      column.each_with_index do |subtile_ops, j|
        draw_ops = subtile_ops.flatten
        subtile_jobid = tilejob.jobid + "-#{i},#{j}"
        if draw_ops.size > 0
          jobs << TileJobRequest.new(subtile_jobid,
                                     tilejob.x + i*subw, tilejob.y + j*subh, 
                                     subw, subh, tilejob.zoom, draw_ops)
        else
          log_debug("Subtile #{i} #{j} is empty, skipping tilejob.")
          results << TileJobResult.new(subtile_jobid, 
                                       tilejob.x + i * subw, tilejob.y + j * subh, empty_subtile_data)
        end
      end
    end
    log_debug("Placing tilejobs #{jobs.map{|x| x.jobid}.join(', ')}")
    jobs.each{|job| @tuplespace.write([:tilejob_request, job.jobid, job], TUPLE_EXPIRATION_TIME)}
    # FIXME: timeout & request
    jobs.each do |job|
      results << @tuplespace.read([:tilejob_result, job.jobid, nil])[2]
      log_debug("Received #{results.last.jobid}")
    end
    tile = Imlib2::Image.new(tilejob.w, tilejob.h)
    tile.clear
    img = Imlib2::Image.new(subw, subh)
    results.each do |tilejob_result|
      data = tilejob_result.raw_data || empty_subtile_data
      img.data = data
      tile.blend!(img, 0, 0, subw, subh, 
                  tilejob_result.x - tilejob.x, tilejob_result.y - tilejob.y, subw, subh)
    end
    tilejob_result = TileJobResult.new(tilejob.jobid, tilejob.x, tilejob.y, tile.data!)
    log_debug("Placing composed result for #{tilejob.jobid}")
    @tuplespace.write([:tilejob_result, tilejob.jobid, tilejob_result], TUPLE_EXPIRATION_TIME)
  end

  private
  # rename to enable/disable logging
  def log_debug(*x)
    yield if block_given?
  end
end

if __FILE__ == $0
  require 'rinda/tuplespace'
  case ARGV[0] 
  when "tuplespace"
    DRb.start_service(nil, Rinda::TupleSpace.new)
    puts DRb.uri
    DRb.thread.join
  when "client"
    unless ARGV[1]
      puts "Need the TupleSpace URI!"
      exit(-1)
    end
    DRb.start_service
    tuplespace = DRbObject.new(nil, ARGV[1])
    dtile_client = DTileClient.new(tuplespace, Future::TileDrawer.new)
    t = Time.new
    tile = dtile_client.draw_tile((0..10000).to_a, "rows", 0, 0, 2, 256, 256)
    puts "#{Time.new - t}"
    tile.save("testtile.png")
  when "inspect"
    DRb.start_service

    tuplespace = DRbObject.new(nil, ARGV[1])
    tuples = tuplespace.read_all([nil, nil, nil])
    tuples.each do |t|
      puts t.inspect
    end
  else
    unless ARGV[1]
      puts "Need the TupleSpace URI!"
      exit(-1)
    end
    tuplespace = DRbObject.new(nil, ARGV[1])
    threads = (0..20).map do
      dtile_server = DTileServer.new(tuplespace)
      dtile_server.thread
    end
    puts "Looping"
    threads.each{|x| x.join}
  end
end
