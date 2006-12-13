tables["metadata"] = {
  :description => [:text]
}

tables["mimetypes"] = {
  :major => [:text, 'not null'],
  :minor => [:text, 'not null']
}
constraints << ['mimetypes', :unique, [:major, :minor]]