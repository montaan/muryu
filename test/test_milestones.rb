require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

$own_path = File.expand_path(File.dirname(__FILE__))

class Milestones < Test::Unit::TestCase

  def check_milestone(milestone)
    args = ["ruby", $own_path + "/milestone_runner.rb", milestone]
    r = system(*args)
    print "."
    r
  end

  def test_milestones
    milestone_path = $own_path + "/milestones"
    passed, failed = Dir[milestone_path + "/*.rb"].
                      sort_by{|ms| File.basename(ms).to_f }.
                      partition{|ms| check_milestone(ms) }

    puts
    puts "Passed milestones"
    puts "-----------------"
    puts passed.map{|f| File.basename f}
    puts
    puts "Milestones still ahead"
    puts "----------------------"
    puts failed.map{|f| File.basename f}
    puts
    puts "Completed: %.1f%" % (100 * passed.size.to_f / (passed+failed).size)
    puts 
  end

end
