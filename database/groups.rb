tables["groups"] = {
  :name => [:text, 'not null', 'unique'],
  :namespace => [:text, 'not null', "default 'groups'"]
  :owner_id => [['users', :id], 'not null', 'index']
}