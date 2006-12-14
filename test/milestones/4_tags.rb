require 'test/unit'
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))+'/../../lib'
require 'future'

class Milestone < Test::Unit::TestCase
include Future

  def test_tags
    item = Items.find
    item.remove_tag "funny"
    assert !item.tags.map{|t|t.name}.include?("funny")
    item.add_tag "funny"
    assert item.tags.map{|t|t.name}.include?("funny")
    item.remove_tag "funny"
    assert !item.tags.map{|t|t.name}.include?("funny")
    item.tags.each{|t| item.remove_tag t.name }
    item.add_tag "funny"
    item.add_tag "funny"
    item.add_tag "funny"
    item.add_tag "sad"
    item.add_tag "bad"
    assert_equal ['bad','funny','sad'], item.tags.map{|t|t.name}.sort
    item.tags.each{|t| item.remove_tag t.name }
    assert_equal [], item.tags.map{|t|t.name}.sort
  end

end