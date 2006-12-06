Joins << ['items', 'groups', :unique]
Joins << ['sets', 'groups', :unique]
Joins << ['landmarks', 'groups', :unique]

Tables['users_groups'] = {
  :user_id => [['users', :id], 'not null'],
  :group_id => [['groups', :id], 'not null'],
  :can_modify => [:boolean, 'not null', 'default false']
}

Constraints << ['users_groups', :unique, [:user_id, :group_id]]

