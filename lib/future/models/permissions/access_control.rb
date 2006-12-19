require 'future/base'
require 'future/models/permissions/authentication'


module Future

class PermissionError < StandardError
end

module AccessControl

  def permissions(user)
    w = writable_by(user)
    r = w || readable_by(user)
    return false unless r
    permissions = [:read]
    permissions << [:write] if w
    permissions
  end

  def readable_by(user)
    (groups & user.groups)
  end

  def writable_by(user)
    grs = (groups & user.groups)
    return false if grs.empty?
    DB::Tables.const_get(self.class.to_s.split(/::/).last+"Groups").find(
      :group_id => grs.map{|g|g.id},
      :can_modify => true
    )
  end

  def write(user)
    if writable_by user
      yield self
    else
      raise PermissionError, "#{user.name} can't modify #{inspect}"
    end
  end

  def rdelete(user)
    write(user) do
      self.deleted = true
    end
  end

  def rundelete(user)
    write(user) do
      self.deleted = false
    end
  end

end


module AccessControlClass

  def find_parse_args(user, h)
    h = h.clone
    h.delete(:public)
    h
  end

  def create_parse_args(h)
    h
  end

  def rfind_all(user, h={})
    h = find_parse_args(user, h)
    h["groups"] = [h["groups"]] if h["groups"] and not h["groups"][0].is_a? Array
    h["groups"] ||= []
    h["groups"] << user.groups
    find_all(h)
  end
  
  def rfind(user, h={})
    rfind_all(user, h.merge(:limit => 1, :columns => :all)).first
  end

  def rfind_or_create(user, h)
    rfind(user, h) or rcreate(h.merge(:owner => user))
  end

  def rcreate(h)
    h = create_parse_args(h).merge(h)
    user = (h[:owner] || Users.find(:id => h[:owner_id]))
    ugroup = user.group
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


class Groups < DB::Tables::Groups
extend AccessControlClass

  def self.public
    find_or_create("owner_id" => Users.find(:order_by => 'id'), "namespace" => "global", "name" => "public")
  end

  def self.rfind_all(user, h={})
    # no OR support in parse_query so need to do this :|
    # same bug applies as in AccessControlClass#find_all
    qs = parse_query(h)
    qs = qs.split(/\n/)
    qs[2].sub!("FROM", "FROM users_groups ug,")
    ws = "WHERE (groups.public OR (ug.user_id = #{user.id}
            AND ug.group_id = groups.id)) "
    set = false
    qs.each do |line|
      if /^WHERE/ =~ line
        line.sub!("WHERE", ws + " AND ")
        set = true
        break
      end
    end
    qs << ws unless set
    q = DB::Conn.exec(qs.join("\n"))
    idx = -1
    q.map{|i| new q, idx+=1 }
  rescue
    log_debug("BAD QUERY")
    log_debug(h.inspect)
    log_debug(qs.join("\n"))
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
      raise PermissionError, "#{user.name} can't modify #{namespace}:#{name}"
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


class Items < DB::Tables::Items
include AccessControl
extend AccessControlClass

  def self.find_parse_args(user, h)
    {:deleted => false}.merge(h)
  end

end


class Sets < DB::Tables::Sets
include AccessControl
extend AccessControlClass

  def self.find_parse_args(user, h)
    h = h.clone
    dh = {:deleted => false}
    dh[:namespace] = []
    dh[:namespace] << "public" if h[:public] != false
    dh[:namespace] << "user:#{user.name}" if h[:public] != true
    h.delete :public
    dh.merge(h)
  end

  def self.create_parse_args(h)
    dh = {:deleted => false}
    dh[:namespace] = h[:public] ? "public" : "user:#{h[:owner].name}"
    dh.merge(h)
  end

end
class SetsGroups < DB::Tables::SetsGroups
end
class ItemsSets < DB::Tables::ItemsSets
end


class Landmarks < DB::Tables::Landmarks
include AccessControl
extend AccessControlClass

end
class LandmarksGroups < DB::Tables::LandmarksGroups
end


end # Future
