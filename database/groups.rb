Tables["groups"] = {
  :name => [:text, 'not null', 'unique'],
  :owner_id => [['users', :id], 'not null', 'index']
}