tables["items"] = {
  :continuous_index => [:serial, 'unique', 'not null'],
  :path => [:text, 'unique', 'not null'],
  :internal_path => [:text, 'not null'],
  :size => [:bigint, 'not null', 'default 0'],
  :sha1_hash => ['character(40)'],
  :deleted => [:boolean, 'not null', 'default false'],
  
  :created_at => [:timestamp, 'not null'],
  :modified_at => [:timestamp, 'default now()'],

  :source   => [:text],
  :referrer => [:text],
  
  :owner_id => [['users',:id], 'not null'],
  :mimetype_id => [['mimetypes', :id], 'not null', 'default 15'],
  :metadata_id => [['metadata', :id], 'not null'],
}

tables["tokens"] = {
  :token => [:text, 'unique', 'index']
}

tables["items_tokens"] = {
  :token_id => [['tokens', :id]],
  :item_id => [['items', :id], 'index']
}
constraints << ['items_tokens', :unique, [:token_id, :item_id]]
