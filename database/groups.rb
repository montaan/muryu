tables["groups"] = {
  :name => [:'varchar(80)', 'not null', 'unique'],
  :namespace => [:'varchar(80)', 'not null', "default 'groups'"],
  :public => [:boolean, 'not null', 'default false'],
  :owner_id => [['users', :id], 'not null', 'index']
}
