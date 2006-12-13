require 'future/base'
require 'future/models/permissions/authentication'


module Future


module AccessControl

  def permissions(user)
    access_vectors = (groups & user.groups)
    return false if access_vectors.empty?
    permissions = [:read]
    permissions << [:write] if access_vectors.find{|g| g.can_modify }
    permissions
  end

  def readable_by(user)
    find("groups" => user.groups)
  end

  def writable_by(user)
    find("groups" => user.groups, "groups.can_modify" => true)
  end

end


module AccessControlClass

  def rfind_all(user, h={})
    qs = parse_query(h)
    qs = qs.sub("FROM", "FROM groups g, users_groups ug, #{table_name}_groups tg,").
            sub("WHERE", "WHERE ug.user_id = #{user.id}
            AND ug.group_id = g.id
            AND tg.group_id = g.id
            AND tg.#{table_name[0..-2]}_id = #{table_name}0.id
            AND")
    puts qs
    q = DB::Conn.exec(qs)
    idx = -1
    q.map{|i| new q, idx+=1 }
  rescue
    p h
    raise
  end
  
  def rfind(user, h={})
    rfind_all(user, h.merge(:limit => 1, :columns => :all)).first
  end

  def rcreate(h)
    h = h.clone
    ugroup = (h[:owner] || Users.find(:user_id => h[:owner_id])).group
    if h.delete(:public)
      pgroup = Groups.public
    end
    it = super(h)
    DB::Tables.const_get(to_s.split(/::/).last+"Groups").create(
      :group_id => ugroup, "#{table_name[0..-2]}_id" => it, :can_modify => true
    )
    DB::Tables.const_get(to_s.split(/::/).last+"Groups").create(
      :group_id => pgroup, "#{table_name[0..-2]}_id" => it, :can_modify => false
    ) if pgroup
    it
  end

end


class Items < DB::Tables::Items
include AccessControl
extend AccessControlClass

end


class Groups < DB::Tables::Groups
include AccessControl
extend AccessControlClass

  def self.public
    find_or_create("namespace" => "global", "name" => "public")
  end

  def self.rfind_all(user, h={})
    qs = parse_query(h)
    qs = qs.sub("FROM", "FROM groups g, users_groups ug,").
            sub("WHERE", "WHERE ug.user_id = #{user.id}
            AND ug.group_id = groups0.id
            AND")
    puts qs
    q = DB::Conn.exec(qs)
    idx = -1
    q.map{|i| new q, idx+=1 }
  rescue
    p h
    raise
  end

end


class Sets < DB::Tables::Sets
include AccessControl
extend AccessControlClass

end


class Landmarks < DB::Tables::Landmarks
include AccessControl
extend AccessControlClass

end


end # Future
