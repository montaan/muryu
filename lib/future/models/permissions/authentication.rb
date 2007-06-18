require 'future/base'


Future.salt ||= "e31568d391a7210a00faff9dc3e2bcac"


module Future


class Sessions < DB::Tables::Sessions

  def self.terminate(session_id)
    delete( :session_id => session_id )
  end

  def self.terminate_all(user_id)
    delete_all( :user_id => user_id )
  end

  def self.[](session_id)
    find( :session_id => session_id )
  end

  def self.start(session_id, user_id)
    find_or_create(
      :session_id => session_id,
      :user_id => user_id
    )
  end

end

class Groups < DB::Tables::Groups
end

class UsersGroups < DB::Tables::UsersGroups
end

class Users < DB::Tables::Users

  def self.anonymous
    @anonymous ||= find_or_create(:name => 'anonymous', :password => '')
  end

  def self.register(username, password_hash)
    u = find_or_create(
      :name => username,
      :password => password_hash
    )
    g = Groups.find_or_create(:namespace => "users", :name => username, :owner_id => u)
    UsersGroups.find_or_create(:user_id => u.id, :group_id => g.id, :can_modify => true)
    UsersGroups.find_or_create(:user_id => u.id, :group_id => Groups.public, :can_modify => false)
    u
  end

  def self.authenticate(username, password_hash)
    find(
      :name => username,
      :password => password_hash
    )
  end

  def self.continue_session(session_id)
    session = Sessions[session_id]
    return false unless session
    u = find( :id => session.user_id )
    u.instance_variable_set("@session", session_id)
    u
  end

  def self.login(username, password_hash, session_id)
    u = authenticate(username, password_hash)
    return false unless u
    u.start_session(session_id)
    u
  end

  def logout
    terminate_all_sessions
  end

  def start_session(session_id)
    Sessions.start(session_id, id)
    @session = session_id
  end

  def terminate_session(session_id)
    Sessions.terminate(session_id)
  end

  def terminate_all_sessions
    Sessions.terminate_all(id)
  end

  def group
    Groups.find(:namespace => 'users', :name => name)
  end

  def groups
    UsersGroups.find_all(:user_id => self, :columns => ['group_id']).map{|ug|
      ug.group_id
    }.uniq.map{|gid| Groups.new gid }
  end

end


end # Future
