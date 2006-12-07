['items', 'sets', 'landmarks', 'users'].each do |tbl|
  tables[tbl+'_groups'] = {
    tbl+'_id' => [[tbl, :id], 'not null'],
    :group_id => [['groups', :id], 'not null'],
    :can_modify => [:boolean, 'not null', 'default false']
  }
  constraints << [tbl+'_groups', :unique, [tbl+'_id', :group_id]]
end

