Tables["items"] = {
  :continuous_index => [:serial, 'unique', 'not null'],
  :filename => [:text, 'unique', 'not null'],
  :size => [:bigint, 'not null', 'default 0'],
  :sha1_hash => ['character(40)'],
  :deleted => [:boolean, 'not null', 'default false'],
  
  :created_at => [:timestamp, 'not null'],
  :modified_at => [:timestamp, 'default now()'],
  
  :owner_id => [['users',:id], 'not null'],
  :mimetype_id => [['mimetypes', :id], 'not null', 'default 15'],
  :metadata_id => [['metadata', :id], 'not null'],
}

Indexes << ['items', 'filename']
