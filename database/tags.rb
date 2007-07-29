tables["tags"] = {
  :name => [:'varchar(80)', 'index'],
  :namespace => [:'varchar(80)', 'index', 'not null', "default 'english'"]
}
constraints << ['tags', :unique, [:name, :namespace]]

tables["items_tags"] = {
  :item_id => [['items'], 'not null', 'index'],
  :tag_id => [['tags'], 'not null', 'index']
}
constraints << ['items_tags', :unique, [:item_id, :tag_id]]