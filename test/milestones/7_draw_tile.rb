require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'


class Milestone < Test::Unit::TestCase
include Future
  DATADIR = File.expand_path(File.dirname(__FILE__) + "/../data")

  def test_photographs
    user = Users.register('foo', 'bar')
    photos = Dir[File.join(DATADIR, "images/*.JPG")]
    photos.each do |photo|
      Uploader.upload(:user => user, :io => File.open(photo),
                      :filename => File.basename(photo))
    end
    query = {:order_by => [[:created_at, :asc]]}
    x,y,w,h = 0, 0, 256, 256
    (0..7).each{|zoom|
      (0..20).each{|x|
        Tiles.open(user, query, :rows, indexes, x*w, y*h, zoom, w, h){|t|
          t.read(65536) until t.eof?
        }
      }
    }
  end

end

