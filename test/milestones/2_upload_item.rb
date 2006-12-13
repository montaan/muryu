require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future
  DATADIR = File.expand_path(File.dirname(__FILE__) + "/../data")

  def test_create_text_post
    user = Users.login('foo', 'bar', 'my_session')
    item = {:user => user, :text => "Hello, World!"}
    i = Uploader.upload item
    assert(Items.find(:id => i))
    assert_equal(i.read, "Hello, World!")
  end

  def test_create_image_post
    user = Users.login('foo', 'bar', 'my_session')
    i = Uploader.upload(:user => user, :io => File.open("#{DATADIR}/guide-2.jpg"),
                        :referrer => "http://poignantguide.net/ruby/chapter-2.html",
                        :source   => "http://poignantguide.net/ruby/i/chapter.poignant.guide-2.jpg",
                        :filename => "chapter.poignant.guide-2.jpg")
    assert(Items.find(:id => i))
    assert_equal(i.read.size, File.size("#{DATADIR}/guide-2.jpg"))
    metadata = Metadata.find(:id => i.metadata_id)
    assert_equal(191, metadata.width)
    assert_equal(174, metadata.height)
  end

end
