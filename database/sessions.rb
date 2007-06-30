tables["sessions"] = {
  :user_id => [["users", :id], 'not null', 'index'],
  :session_id => [:text, 'not null', 'unique'],
  :secret => [:text, 'not null']
}

