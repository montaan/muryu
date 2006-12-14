tables["sets"] = {
  :name => [:text, 'index'],
  :namespace => [:text, 'index'],
  :deleted => [:boolean, 'not null', 'default false']
}