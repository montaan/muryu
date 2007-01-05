class Affiliate

  attr_accessor :average_purchase, :conversion_rate, :commission, :wire_cost

  def initialize(average_purchase=30, commission=0.10, conversion_rate=0.001, wire_cost=0.05)
    @average_purchase = average_purchase
    @conversion_rate = conversion_rate
    @commission = commission
    @wire_cost = wire_cost
  end

  def income_per_view
    @average_purchase * @conversion_rate * @commission * (1.0-@wire_cost)
  end

end


class ImageCache

  attr_accessor :max_image_size, :compression_ratio

  def initialize(max_image_size=128, compression_ratio=1.0)
    @max_image_size = max_image_size
    @compression_ratio = compression_ratio
  end

  def disk_use_per_item
    (0..(Math.log(@max_image_size) / Math.log(2)).round).inject(0) do |s, i|
      s + 2**(i*2)
    end * 4 * compression_ratio
  end

end


class Item

  attr_accessor :average_size, :thumbnail_size, :database_size, :image_cache

  def initialize(image_cache=ImageCache.new,
                 average_size=207338.9,  # <- select avg(size) from items
                 thumbnail_size=25000.0, # <- guesstimate from google image search
                 database_size=4660.3)   # <- `du postgresql` / select count(*) from items
    @image_cache = image_cache
    @average_size = average_size
    @thumbnail_size = thumbnail_size
    @database_size = database_size
  end

  def total_size
    @average_size + @thumbnail_size + @database_size + @image_cache.disk_use_per_item
  end

end


class User

  attr_accessor :average_items, :item, :bandwidth_use

  def initialize(
    item=Item.new,
    average_items=1000.0,     # <- pure guess
    bandwidth_use=736130936.0 # <- kig's one week times four
  )
    @item = item
    @average_items = average_items
    @bandwidth_use = bandwidth_use
  end

  def total_size
    average_items * item.total_size
  end

  def items_viewed
    bandwidth_use / item.total_size
  end

end


class CostAnalysis

  attr_accessor :affiliates, :users, :user, :breakage_rate, :cost_per_byte,
                :bytes_per_admin, :admin_cost, :watts_per_byte, :cost_per_kWh,
                :redundancy, :infrastructure, :bandwidth_cost, :area_per_byte, :rent_per_m2

  def initialize(
    affiliates = [Affiliate.new(30, 0.10), Affiliate.new(15, 0.25), Affiliate.new(10, 0.25)],
    users = 10000,
    cost_per_byte = -0.3 / 1e9,
    bandwidth_cost = -0.01 / 1e9, # who knows
    redundancy = 2,
    infrastructure = 2,
    area_per_byte = 1 / 12.5e12,
    rent_per_m2 = -100.0,
    breakage_rate = 0.05,
    bytes_per_admin = 50e12,
    admin_cost = -5000,
    watts_per_byte = 0.5 / 1e9,
    cost_per_kWh = -0.0013,
    image_cache = ImageCache.new,
    item = Item.new(image_cache),
    user = User.new(item)
  )
    @affiliates = affiliates
    @users = users
    @user = user
    @cost_per_byte = cost_per_byte
    @redundancy = redundancy
    @infrastructure = infrastructure
    @breakage_rate = breakage_rate
    @bytes_per_admin = bytes_per_admin
    @admin_cost = admin_cost
    @watts_per_byte = watts_per_byte
    @cost_per_kWh = cost_per_kWh
    @bandwidth_cost = bandwidth_cost
    @area_per_byte = area_per_byte
    @rent_per_m2 = rent_per_m2
    @cost_fields = [:breakage, :admin_costs, :bandwidth, :electricity, :rent]
    @income_fields = [:affiliate_income]
    @all_fields = @income_fields + @cost_fields
  end

  def initial_costs
    storage_cost * infrastructure
  end

  def monthly_income
    @income_fields.inject(0){|s, f| s + send(f) }
  end

  def monthly_costs
    @cost_fields.inject(0){|s, f| s + send(f) }
  end

  def breakeven_point
    -initial_costs / monthly_profit
  end

  def monthly_profit
    monthly_income + monthly_costs
  end

  def breakdown
    @all_fields.map{|f| [f, send(f)] }
  end

  

  def affiliate_income
    affiliates.inject(0){|s,a| s + a.income_per_view * users * user.items_viewed }
  end

  def storage_cost
    storage_required * cost_per_byte
  end

  def storage_required
    data_stored * redundancy
  end

  def data_stored
    users * user.total_size 
  end

  def breakage
    initial_costs * breakage_rate
  end

  def admin_costs
    admin_cost * storage_required / bytes_per_admin.to_f
  end

  def power_use
    storage_required * watts_per_byte
  end

  def kWh_per_month
    power_use * 0.001 * 24 * 30
  end

  def electricity
    kWh_per_month * cost_per_kWh
  end

  def bandwidth
    bandwidth_use * bandwidth_cost
  end

  def bandwidth_use
    users * user.bandwidth_use
  end

  def rent
    floor_space_use * rent_per_m2
  end

  def floor_space_use
    storage_required * area_per_byte
  end

end

if __FILE__ == $0

  ca = CostAnalysis.new
  puts "#{ca.users} users, each with an average of #{ca.user.average_items} items."
  puts "Item size #{(ca.user.item.total_size / 1e3).to_i}kB, " +
       "of which the item itself is #{(ca.user.item.average_size / 1e3).to_i}kB."
  puts "Each user views #{ca.user.items_viewed.to_i} items per month."
  puts "With a conversion rate of 0.001: #{"%.2f" % [ca.user.items_viewed * 0.001]} purchases per month."
  puts "Bandwidth use: #{(ca.bandwidth_use / 1e9).to_i} GB/month."
  puts "Data stored: #{(ca.data_stored / 1e9).to_i} GB."
  puts "Redundancy factor: #{ca.redundancy}. Infrastructure cost factor: #{ca.infrastructure}"
  puts "Hard disk use: #{(ca.storage_required / 1e9).to_i } GB, breakage #{ca.breakage_rate}."
  puts "Floor space use: #{"%.1f" % [ca.floor_space_use]}m², rent #{ca.rent_per_m2.abs}€/m²"
  puts "Electricity use: #{ca.kWh_per_month.to_i} kWh/month."
  puts
  puts "Initial costs:".ljust(40) + " #{ca.initial_costs.to_i}"
  puts
  puts "Monthly costs:".ljust(40) + " #{ca.monthly_costs.to_i}"
  puts "Monthly income:".ljust(20) + " #{ca.monthly_income.to_i}"
  puts
  puts "Monthly profit:".ljust(20) + " #{ca.monthly_profit.to_i}"
  puts
  puts "Breakeven point: #{ca.breakeven_point.ceil} months"
  puts
  puts "Breakdown:"
  puts(ca.breakdown.map do |f,c|
    "#{f.to_s.split("_").join(" ").ljust((c < 0) ? 40 : 20)} #{c.to_i}"
  end)

end
