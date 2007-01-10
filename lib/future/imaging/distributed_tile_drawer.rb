
require 'future/imaging/image_cache'
require 'future/imaging/tile_drawer'
require 'digest/sha1'
require 'imlib2'

class TileJobRequest < Struct.new(:jobid, :x, :y, :w, :h, :zoom, :indexes, :layouter_name, :layouter_args)
end

class TileJobResult < Struct.new(:jobid, :raw_data)
end

class DTileClient
  TUPLE_EXPIRATION_TIME = 10 # seconds
  def initialize(tuplespace)
    @tuplespace = tuplespace
  end

  def draw_tile(indexes, layouter_name, x, y, zoom, w, h, *layouter_args)
    jobid   = "#{Process.pid}#{Thread.current.object_id}-#{x}-#{y}-#{w}-#{h}"
    tilejob = TileJobRequest.new(jobid, x, y, w, h, zoom, indexes, layouter_name, layouter_args)
    puts "Placing request #{jobid} (#{w}x#{h})"
    @tuplespace.write([:tilejob_request, jobid, tilejob], TUPLE_EXPIRATION_TIME)
    result = @tuplespace.read([:tilejob_result, jobid, nil])[2]
    tile   = Imlib2::Image.new(w, h)
    tile.data = result.raw_data
    tile
  end
end

class DTileServer
  MAX_THUMBS_PER_JOB    = 16
  TUPLE_EXPIRATION_TIME = 10 # seconds

  def initialize(tuplespace, tile_drawer, max_thumbs_per_job = MAX_THUMBS_PER_JOB, branching_factor = 4)
    @tile_drawer        = tile_drawer
    @tuplespace         = tuplespace
    @max_thumbs_per_job = max_thumbs_per_job
    @branching_factor   = branching_factor
  end

  Thread.abort_on_exception = true
  def thread
    Thread.new do
      while true
        tuple = @tuplespace.take([:tilejob_request, nil, nil])
        puts "Got tilejob request #{tuple[2].jobid}"
        process_tilejob(tuple[2])
      end
    end
  end

  def process_tilejob(tilejob)
    if tilejob.w * tilejob.h / (2**tilejob.zoom) ** 2 > @max_thumbs_per_job
      split_tilejob(tilejob)
    else
      sz = 2 ** tilejob.zoom
      puts "Drawing tile (#{tilejob.x},#{tilejob.y}) #{tilejob.w}x#{tilejob.h}"
      tile = @tile_drawer.draw_tile(tilejob.indexes, tilejob.layouter_name,
                                    tilejob.x, tilejob.y, tilejob.zoom, tilejob.w,
                                    tilejob.h, *tilejob.layouter_args)
      # FIXME: rescue exception
      tilejob_result = TileJobResult.new(tilejob.jobid, tile ? tile.data! : nil)
      puts "Placing result for #{tilejob.jobid}"
      @tuplespace.write([:tilejob_result, tilejob.jobid, tilejob_result], 
                        TUPLE_EXPIRATION_TIME)
    end
  end

  def split_tilejob(tilejob)
    w    = tilejob.w
    h    = tilejob.h
    jobs = []
    thsz = 2 ** tilejob.zoom

    puts "Splitting tilejob #{tilejob.jobid} (#{w}x#{h}) #{tilejob.indexes.size} indexes @ zoom #{tilejob.zoom}"
    subtiles = []
    @branching_factor.times do |i|
      @branching_factor.times do |j|
        subtiles << [i * w/@branching_factor/thsz, j * w/@branching_factor/thsz]
      end
    end
    puts "Subtiles: #{subtiles.inspect}"

    subtiles.each_with_index do |(x1, y1), idx|
      indexes = (y1..y1+h/@branching_factor/thsz-1).inject([]) do |s,i|
        s.concat(tilejob.indexes[i * w/thsz + x1, w/@branching_factor/thsz])
      end
      jobs << TileJobRequest.new(tilejob.jobid + "-sub#{idx}", tilejob.x+x1*thsz, tilejob.y+y1*thsz, 
                                 tilejob.w/@branching_factor, tilejob.h/@branching_factor, tilejob.zoom,
                                 indexes, tilejob.layouter_name, tilejob.layouter_args)
    end
    puts "Placing tilejobs #{jobs.map{|x| x.jobid}.join(', ')}"
    jobs.each{|job| @tuplespace.write([:tilejob_request, job.jobid, job], TUPLE_EXPIRATION_TIME)}
    # FIXME: timeout & request
    results = []
    jobs.each do |job|
      results << @tuplespace.read([:tilejob_result, job.jobid, nil])[2]
      puts "Received #{results.last.jobid}"
    end
    tile = Imlib2::Image.new(tilejob.w, tilejob.h)
    tile.clear
    img = Imlib2::Image.new(tilejob.w / @branching_factor, tilejob.h / @branching_factor)
    empty_data = nil
    subtiles.each_with_index do |(x1, y1), i|
      data = results[i].raw_data
      unless data
        unless empty_data
          empty_img = Imlib2::Image.new(tilejob.w/@branching_factor, tilejob.h/@branching_factor)
          empty_img.clear
          empty_data = empty_img.data!
        end
        data = empty_data
      end
      img.data = data
      tile.blend!(img, 0, 0, w/@branching_factor, h/@branching_factor, x1, y1, 
                  w/@branching_factor, h/@branching_factor)
    end
    tilejob_result = TileJobResult.new(tilejob.jobid, tile.data!)
    puts "Placing composed result for #{tilejob.jobid}"
    @tuplespace.write([:tilejob_result, tilejob.jobid, tilejob_result], TUPLE_EXPIRATION_TIME)
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
    dtile_client = DTileClient.new(tuplespace)
    tile = dtile_client.draw_tile((0..256**2 / 16**2).to_a, "rows", 0, 0, 4, 256, 256)
    p tile
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
      dtile_server = DTileServer.new(tuplespace, Future::TileDrawer.new)
      dtile_server.thread
    end
    puts "Looping"
    threads.each{|x| x.join}
  end
end
