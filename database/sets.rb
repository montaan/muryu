tables["sets"] = {
  :name => [:'varchar(80)', 'index'],
  :namespace => [:'varchar(80)', 'index'],
  :owner_id => [['users']],
  :deleted => [:boolean, 'not null', 'default false']
}
constraints << ['sets', :unique, [:namespace, :name]]

tables["items_sets"] = {
  :item_id => [['items', :id], 'not null'],
  :set_id => [['sets', :id], 'not null']
}
constraints << ['items_sets', :unique, ['item_id', 'set_id']]