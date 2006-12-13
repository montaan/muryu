require 'test/unit'

$own_path = File.expand_path(File.dirname(__FILE__))

class Milestones < Test::Unit::TestCase

  def check_milestone(milestone)
    args = ["ruby", $own_path + "/milestone_runner.rb", milestone]
    system(*args)
  end

  def test_milestones
    milestone_path = $own_path + "/milestones"
    passed, failed = Dir[milestone_path + "/*.rb"].sort.partition{|ms|
      check_milestone(ms)
    }

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