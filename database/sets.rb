tables["sets"] = {
  :name => [:text, 'index'],
  :namespace => [:text, 'index'],
  :owner_id => [['users']],
  :deleted => [:boolean, 'not null', 'default false']
}

tables["items_sets"] = {
  :item_id => [['items', :id], 'not null'],
  :set_id => [['sets', :id], 'not null']
}
constraints << ['items_sets', :unique, ['item_id', 'set_id']]