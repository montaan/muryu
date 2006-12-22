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
    milestones = Dir[milestone_path + "/*.rb"].sort_by{|ms| File.basename(ms).to_f }
    max_len = milestones.map{|m| File.basename(m).size }.max
    passed, failed = milestones.map{|ms|
                        t = Time.now.to_f
                        res = check_milestone(ms)
                        elapsed = Time.now.to_f - t
                        [ms, res, elapsed]
                      }.partition{|ms,res,t| res}

    puts
    puts "Passed milestones"
    puts "-----------------"
    puts passed.map{|f,r,t| File.basename(f).ljust(max_len) + " (%.1fs)".%([t])}
    puts
    puts "Milestones still ahead"
    puts "----------------------"
    puts failed.map{|f,r,t| File.basename(f).ljust(max_len) + " (%.1fs)".%([t])}
    puts
    puts "Completed: %.1f%" % (100 * passed.size.to_f / (passed+failed).size)
    puts 
  end

end
