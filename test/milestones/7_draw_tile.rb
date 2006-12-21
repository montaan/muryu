require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'


class Milestone < Test::Unit::TestCase
include Future
  DATADIR = File.expand_path(File.dirname(__FILE__) + "/../data")

  def test_photographs
    Users.delete_all
    user = Users.register('foo', 'bar')
    photos = Dir[File.join(DATADIR, "images/*.JPG")]
    Future.image_cache.batch do
      photos.each do |photo|
        Uploader.upload(:user => user, :io => File.open(photo),
                        :filename => File.basename(photo))
      end
    end
    query = {:order_by => [[:image_index, :asc]]}
    x,y,w,h = 0, 0, 256, 256
    (0..7).each{|zoom|
      (0..9).each{|x|
        Tiles.open(user, query, :rows, x*w, y*h, zoom, w, h){|t|
          t.read(65536) until t.eof?
        }
      }
    }
  end

end

