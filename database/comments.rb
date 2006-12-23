tables["comments"] = {
  :item_id => [['items', :id], 'not null', 'index'],
  :owner_id => [['users', :id], 'not null', 'index'],
  :content => ['text', 'not null', "default ''"],
  :created_at => ['timestamp', 'not null', 'default now()'],
  :modified_at => ['timestamp', 'not null', 'default now()'],
  :deleted => ['boolean', 'not null', 'default false']
}
