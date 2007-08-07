def estimate(
users = 50_000,
items_per_user = 100,
items_uploaded_per_month_per_user = 10,

items_viewed_per_month_per_user = 1000,
browsing_bw_use_per_month_per_user = 30 * 0.01, # GB

item_avg_size = (20 / 50000.0), # GB
avg_tile_time = 0.020,
memory_use_per_item = 240.0 / 50000, # MB
memory_per_cache_node = 1500 # MB
)
upstream_ratio_of_bw_use = 0.1
img_cache_avg_size = (14 / 50000.0) # GB
avg_tile_size = 0.00001
tiles_per_user_per_month = browsing_bw_use_per_month_per_user / avg_tile_size

avg_thumbnailing_time = 1.6
tile_redundancy_multiplier = 2

seconds_in_month = 86400 * 30

images_per_cache_node = memory_per_cache_node / memory_use_per_item

thumbnailing_nodes = ((users * items_uploaded_per_month_per_user * avg_thumbnailing_time) / seconds_in_month).ceil
tile_nodes = ((tile_redundancy_multiplier * tiles_per_user_per_month * users * avg_tile_time) / seconds_in_month).round
cache_nodes = ((users * items_per_user) / images_per_cache_node).round
all_nodes = thumbnailing_nodes + tile_nodes + [0,(cache_nodes - tile_nodes)].max

storage = users * items_per_user * (item_avg_size + img_cache_avg_size)

uploads = users * items_uploaded_per_month_per_user
transfer_in = uploads * item_avg_size +
              users * browsing_bw_use_per_month_per_user * upstream_ratio_of_bw_use

downloads = users * items_viewed_per_month_per_user
transfer_out = users * browsing_bw_use_per_month_per_user + 
               downloads * item_avg_size

storage_cost = storage * 0.15
transfer_in_cost  = transfer_in * 0.10
transfer_out_cost = transfer_out * 0.15
node_cost = all_nodes.ceil * 720 * 0.1

total_cost = storage_cost + transfer_in_cost + transfer_out_cost + node_cost

puts
puts "#{users} users, #{items_per_user} items per user, #{item_avg_size*1000}MB per item, #{items_per_user*users} items"
puts "#{items_uploaded_per_month_per_user} uploads per user a month, #{browsing_bw_use_per_month_per_user*1000}MB browsing per user a month, #{items_viewed_per_month_per_user} item views per user a month (#{items_viewed_per_month_per_user*item_avg_size}GB)"
puts "#{memory_per_cache_node}MB memory per cache node, #{memory_use_per_item}MB mem use per item, #{avg_tile_time * 1000}ms avg tile time"
puts
puts "Storage:      #{storage}GB"
puts "Transfer-in:  #{transfer_in}GB"
puts "Transfer-out: #{transfer_out}GB"
puts "Uploads:      #{uploads}"
puts "Downloads:    #{downloads}"
puts "Nodes: #{all_nodes} (thumb: #{thumbnailing_nodes}, tile: #{tile_nodes}, cache: #{cache_nodes})"
puts 
puts "Storage cost:      #{(storage_cost / 1.35).round}e"
puts "Transfer-in cost:  #{(transfer_in_cost / 1.35).round}e"
puts "Transfer-out cost: #{(transfer_out_cost / 1.35).round}e"
puts "Node cost:         #{(node_cost / 1.35).round}e"
puts "Total:             #{(total_cost / 1.35).round}e"
end

[100, 1000].each{|items|
 [0.001, 0.010].each{|item_size|
  [0.025].each{|tile_time|
   [440 / 50000.0].each{|memory_use_per_item|
    [0.6].each{|browsing|
     estimate(50_000, items, items / 10, 1000, browsing, item_size, tile_time, memory_use_per_item, 1500)
     puts
     puts "="*72
    }
   }
  }
 }
}
