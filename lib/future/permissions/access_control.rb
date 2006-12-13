require 'future/base'
require 'future/permissions/authentication'


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


class Items < DB::Tables::Items
include AccessControl

end


class Groups < DB::Tables::Groups
include AccessControl

end


class Sets < DB::Tables::Sets
include AccessControl

end


class Landmarks < DB::Tables::Landmarks
include AccessControl

end


end # Future