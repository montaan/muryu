tables['a'] = {
  :name => [:text, 'index'],
  :small => [:int],
  :size => [:bitint],
  :bytes => [:bytea]
}

tables['employees'] = {
  :first_name => [:text], 
  :last_name => [:text],
  :salary => [:int],
  :starting_date => [:timestamp],
  :department_id => [['departments']]
}
tables['departments'] = {
  :name => [:text, 'not null']
}

tables['department_chiefs'] = {
  :department_id => [['departments'], 'unique', 'not null'],
  :employee_id => [['employees'], 'not null']
}

