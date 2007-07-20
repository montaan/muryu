tables["groups"] = {
  :name => [:text, 'not null', 'unique'],
  :namespace => [:text, 'not null', "default 'groups'"],
  :public => [:boolean, 'not null', 'default false'],
  :owner_id => [['users', :id], 'not null', 'index']
}
constraints << ['groups', :unique, [:namespace, :name]]
