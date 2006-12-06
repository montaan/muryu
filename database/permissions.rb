joins << ['items', 'groups', :unique]
joins << ['sets', 'groups', :unique]
joins << ['landmarks', 'groups', :unique]

tables['users_groups'] = {
  :user_id => [['users', :id], 'not null'],
  :group_id => [['groups', :id], 'not null'],
  :can_modify => [:boolean, 'not null', 'default false']
}

constraints << ['users_groups', :unique, [:user_id, :group_id]]

