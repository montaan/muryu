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
    items = []
    Future.image_cache.batch do
      items = photos.map do |photo|
        Uploader.upload(:user => user, :io => File.open(photo),
                        :filename => File.basename(photo))
      end
    end
    query = {:order_by => [[:image_index, :asc]]}
    w,h = 256, 256
    all_out_tile = Tiles.info(user, query, :rows, 0, 0, 0, w, h)
    assert_equal(items.map{|i| i.image_index}, all_out_tile.keys.sort)
    all_in_tile = Tiles.info(user, query, :rows, 0, 0, 7, w, h)
    assert_equal([0,1,5,6].map{|i| items[i].image_index}, all_in_tile.keys.sort)
    assert_equal([[0,0,128],[0,128,128],[128,0,128],[128,128,128]], all_in_tile.values.sort)
    
#     Tiles.open(user, query, :rows, 0, 0, 3, w, h, nil, 5, 5) {|f| }
    all_in_tile_512 = Tiles.info(user, query, :rows, 0, 512, 7, w, h, nil, 5, 5)
    assert_equal([4,9,25,30].map{|i| items[i].image_index}, all_in_tile_512.keys.sort)
    assert_equal([[0,0,128],[0,192,128],[128,0,128],[128,192,128]], all_in_tile_512.values.sort)
  end

end

