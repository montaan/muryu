tables["sessions"] = {
  :user_id => [["users", :id], 'not null'],
  :session_id => [:text, 'not null']
}

constraints << ["sessions", :unique, [:user_id, :session_id]]

