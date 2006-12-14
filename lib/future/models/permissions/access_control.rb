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

  def write(user)
    if writable_by user
      yield self
    else
      raise "#{user.name} can't modify #{namespace}:#{name}"
    end
  end

end


module AccessControlClass

  def rfind_all(user, h={})
    qs = parse_query(h)
    qs = qs.split(/\n/)
    qs[1].sub!("FROM", "FROM groups g, users_groups ug, #{table_name}_groups tg,")
    ws = "WHERE ug.user_id = #{user.id}
        AND ug.group_id = g.id
        AND tg.group_id = g.id"
    wst0 = " AND tg.#{table_name[0..-2]}_id = #{table_name}0.id"
    wst = " AND tg.#{table_name[0..-2]}_id = #{table_name}.id"
    if qs[2] =~ /^WHERE/
      qs[2].sub!("WHERE", ws + wst0 + " AND ")
    else
      qs.insert(2, ws + wst)
    end

    q = DB::Conn.exec(qs.join("\n"))
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
    ugroup = (h[:owner] || Users.find(:id => h[:owner_id])).group
    if h.delete(:public)
      pgroup = Groups.public
    end
    it = create(h)
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
extend AccessControlClass

  def self.public
    find_or_create("owner_id" => 1, "namespace" => "global", "name" => "public")
  end

  def self.rfind_all(user, h={})
    qs = parse_query(h)
    qs = qs.split(/\n/)
    qs[1].sub!("FROM", "FROM users_groups ug,")
    ws = "WHERE (groups.public OR (ug.user_id = #{user.id}
            AND ug.group_id = groups.id)) "
    ws0 = "WHERE (groups0.public OR (ug.user_id = #{user.id}
            AND ug.group_id = groups0.id)) "
    if qs[2] =~ /^WHERE/
      qs[2].sub!("WHERE", ws0 + " AND ")
    else
      qs.insert(2, ws)
    end
    q = DB::Conn.exec(qs.join("\n"))
    idx = -1
    q.map{|i| new q, idx+=1 }
  rescue
    p h
    raise
  end

  def self.rcreate(h)
    h = h.clone.merge(:namespace => 'groups')
    user = (h[:owner] || Users.find(:id => h[:owner_id]))
    if h[:public]
      anon = Users.anonymous
    end
    it = create(h)
    UsersGroups.create(
      :user_id => user, "group_id" => it, :can_modify => true
    )
    UsersGroups.create(
      :user_id => anon, "group_id" => it, :can_modify => false
    ) if anon
    it
  end

  def self.rdelete(user, h={})
    h = h.clone.merge(:namespace => 'groups')
    g = find(h)
    g.delete(user)
    nil
  end

  def permissions(user)
    access_vector = UsersGroups.find(:user => user, :group => self)
    if access_vector
      return [:read] + (access_vector.can_modify ? [:write] : [])
    elsif public
      return [:read]
    end
    return false
  end

  def write(user)
    if writable_by user
      yield self
    else
      raise "#{user.name} can't modify #{namespace}:#{name}"
    end
  end

  def readable_by(user)
    public or UsersGroups.find(:user => user, :group => self)
  end

  def writable_by(user)
    UsersGroups.find(:user => user, :group => self, :can_modify => true)
  end

  def delete(user)
    write(user) do
      ItemsGroups.delete_all(:group_id => id)
      LandmarksGroups.delete_all(:group_id => id)
      SetsGroups.delete_all(:group_id => id)
      UsersGroups.delete_all(:group_id => id)
      self.class.delete(:id => id)
    end
  end

  def add_member(user, new_user, can_modify=false)
    write(user) do
      UsersGroups.find_or_create(:user_id => new_user.id, :group_id => id, :can_modify => can_modify)
    end
  end

  def remove_member(user, removed_user)
    write(user) do
      UsersGroups.delete(:user_id => removed_user.id, :group_id => id)
    end
  end

end


class Sets < DB::Tables::Sets
include AccessControl
extend AccessControlClass

end
class SetsGroups < DB::Tables::SetsGroups
end


class Landmarks < DB::Tables::Landmarks
include AccessControl
extend AccessControlClass

end
class LandmarksGroups < DB::Tables::LandmarksGroups
end


end # Future
