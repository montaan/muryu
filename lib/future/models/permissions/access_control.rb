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
    (groups & user.groups).size > 0
  end

  def writable_by(user)
    return true if columns['owner_id'] and user.id == owner_id
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
    # no 'or' support in parse_query so need to do this :|
    # same bug applies as in AccessControlClass#find_all
    qs = parse_query(h)
    qs = qs.split(/\n/)
    qs[2].sub!("FROM", "FROM users_groups ug,")
    ws = "WHERE (groups.owner_id = #{user.id} OR groups.public OR (ug.user_id = #{user.id}
            AND ug.group_id = groups.id)) "
    set = false
    qs.each do |line|
      if /^WHERE/ =~ line
        line.sub!("WHERE", ws + " AND ")
        set = true
        break
      end
    end
    qs.insert(3, ws) unless set
    q = DB::Conn.exec(qs.join("\n"))
    idx = -1
    q.map{|i| new q, idx+=1 }
  rescue
    log_debug("BAD QUERY")
    log_debug(h.inspect)
    log_debug(qs.join("\n")) if qs
    raise
  end

  def self.rcreate(h)
    h = h.clone
    h.delete('namespace')
    user = (h[:owner] || Users.find(:id => h[:owner_id]))
    h = h.merge(:namespace => user.name)
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
    h = h.clone.merge(:namespace => user.name)
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
    public or owner_id == user.id or UsersGroups.find(:user => user, :group => self)
  end

  def writable_by(user)
    (user != Users.anonymous and owner_id == user.id) or
    UsersGroups.find(:user => user, :group => self, :can_modify => true)
  end

  def rdelete(user)
    write(user) do
      self.class.delete(:id => id)
    end
  end

  def add_member(new_user, can_modify=false)
    UsersGroups.find_or_create(:user_id => new_user.id, :group_id => id, :can_modify => can_modify)
  end

  def remove_member(removed_user)
    UsersGroups.delete(:user_id => removed_user.id, :group_id => id)
  end

  def add_item(item)
    ItemsGroups.find_or_create(:item_id => item, :group_id => id)
  end

  def remove_item(item)
    ItemsGroups.delete(:item_id => item, :group_id => id)
  end

end


class Items < DB::Tables::Items
include AccessControl
extend AccessControlClass

  def rdelete(user)
    write(user) do
      self.deleted = true
    end
  end

  def rpurge(user)
    write(user) do
      purge
      update_image_cache
    end
  end

  def rundelete(user)
    write(user) do
      if File.exist?(internal_path)
        self.deleted = false
      end
    end
  end

end


class Sets < DB::Tables::Sets
include AccessControl
extend AccessControlClass

  def self.find_parse_args(user, h)
    h = h.clone
    dh = {:deleted => false}
    dh.delete(:deleted) if h[:limit] == 1
    dh.merge(h)
  end

  def self.create_parse_args(h)
    dh = {:deleted => false}
    dh[:namespace] = h[:public] ? "public" : "#{h[:owner].name}"
    dh.merge(h)
  end

  def add_group(group, can_modify=false)
    DB.transaction do
      SetsGroups.find_or_create(:group_id => group, :set_id => id, :can_modify => can_modify)
      items([]).each{|it|
        ItemsGroups.find_or_create(
          'item_id' => it.id,
          'group_id' => group.id,
          :columns => []
        )
      }
    end
  end

  def remove_group(group)
    SetsGroups.delete(:group_id => group, :set_id => id)
  end

  def add_item(item)
    DB.transaction do
      ItemsSets.find_or_create(:item_id => item, :set_id => id)
      sets_groups(['group_id']).each{|sg|
        ItemsGroups.find_or_create(
          'item_id' => item,
          'group_id' => sg.group_id,
          :columns => []
        )
      }
    end
  end

  def remove_item(item)
    ItemsSets.delete(:item_id => item, :set_id => id)
  end

end
class SetsGroups < DB::Tables::SetsGroups
end
class ItemsSets < DB::Tables::ItemsSets
end


class Users < DB::Tables::Users
include AccessControl
extend AccessControlClass

  def readable_by(user)
    self == user
  end

  def writable_by(user)
    self == user and self != self.class.anonymous
  end

  def self.rfind_all(user, query)
    find_all(query)
  end

  def self.rdelete(user, h={})
    g = find(h)
    g.delete(user)
    nil
  end

  def rdelete(user)
    write(user) do
      self.class.delete(:id => id)
    end
  end

end


class Landmarks < DB::Tables::Landmarks
include AccessControl
extend AccessControlClass

end
class LandmarksGroups < DB::Tables::LandmarksGroups
end


end # Future
