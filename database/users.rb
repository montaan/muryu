tables["users"] = {
  :name => [:'varchar(40)', 'unique not null', 'index'],
  :password => [:'varchar(40)', 'not null'],
  :workspace_id => [['workspaces',:id]]
}

tables["workspaces"] = {
  :name => [:'varchar(80)', 'not null'],
  :user_id => [['users', :id], 'not null', 'index']
}
constraints << ['workspaces', :unique, [:name, :user_id]]

tables["preferences"] = {
  :key => [:'varchar(80)', 'not null'],
  :value => [:text],
  :workspace_id => [['workspaces', :id], 'not null', 'index']
}
constraints << ['preferences', :unique, [:key, :workspace_id]]

tables["selections"] = {
  :name => [:'varchar(80)', 'not null'],
  :user_id => [['users', :id], 'not null', 'index']
}

tables["selections_items"] = {
  :selection_id => [['selections', :id], 'not null', 'index'],
  :item_id => [['items', :id], 'not null', 'index']
}
constraints << ['selections_items', :unique, [:selection_id, :item_id]]
