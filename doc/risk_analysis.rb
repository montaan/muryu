Risk = Struct.new(:name, :probability, :impact, :avoidance, :recovery)
class Risk

  def importance
    probability * impact
  end

  def to_s
    "#{name}\nP = #{probability}, I = #{impact}, Importance = #{importance}\nAvoidance: #{avoidance}\nRecovery: #{recovery}\n"
  end

end


low = 0.1
medium = 0.3
high = 0.6

Risks = [

  Risk.new(
    "No users",
    medium, 
    high,
    "",
    ""
  ),

  Risk.new(
    "Too fast growth, infra can't keep up",
    medium,
    medium,
    "",
    ""
  ),

  Risk.new(
    "Legal problems from people not following copy restrictions",
    high,
    medium,
    "",
    ""
  ),

  Risk.new(
    "Patent problems with obvious technology",
    low,
    medium,
    "",
    ""
  ),

  Risk.new(
    "We get sick of coding and/or die",
    low,
    high,
    "Work on interesting stuff, take care of health",
    ""
  ),

  Risk.new(
    "People upload big files, hosing cashflow",
    high,
    high,
    "",
    ""
  ),

  Risk.new(
    "Tile drawing requires too much computation, making site slow",
    medium,
    high,
    "",
    ""
  ),

  Risk.new(
    "Recommendations don't work well, hurting ads and income",
    high,
    high,
    "",
    ""
  ),

].sort_by{|r| -(r.importance) }

puts
puts Risks.join("-"*72 + "\n")
puts
