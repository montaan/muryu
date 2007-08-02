tables["messages"] = {
  :sender_id => [['users', :id], 'not null', 'index'],
  :receiver_id => [['users', :id], 'not null', 'index'],
  :created_at => [:timestamp, 'not null', 'index', 'default now()'],
  :content => [:text, 'not null']
}
