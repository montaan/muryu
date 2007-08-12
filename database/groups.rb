tables["groups"] = {
  :name => [:'varchar(80)', 'not null'],
  :namespace => [:'varchar(80)', 'not null'],
  :public => [:boolean, 'not null', 'default false'],
  :owner_id => [['users', :id], 'not null', 'index']
}
constraints << ['groups', :unique, [:name, :namespace]]