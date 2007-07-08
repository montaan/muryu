module MuryuDispatch

  module Groups
  include Handler
  extend self

    ### VERBS

    def create(user,req,res)
      group = Future::Groups.rcreate(
        :owner => user,
        :name => req.query['name'].to_s
      )
      if group
        res.content_type = "text/plain"
        res.body = "OK"
      end
    rescue => e
      raise(MuryuQuery::BadPost, "Failed to create group: there already is a group with that name.")
    end

    def edit(user,req,res)
    end

    def delete(user,req,res)
    end

    def undelete(user,req,res)
    end

    ### PROPERTIES

    def json(user,req,res)
      res.content_type = 'application/json'
      res.body = get_groups(user, req).to_json
    end

    def view(user,req,res)
    end

    ### helpers

    def get_groups(user, req)
      groups = Future::Groups.rfind_all(user, :columns => :all, :order_by => [[:name, :asc]])
      groups.map{|g|
        next if g.namespace == 'users'
        hashify_group(user, g)
      }.compact
    end

    def hashify_group(user, g)
      h = g.to_hash
      h.delete("owner_id")
      h.delete("id")
      if g.namespace == 'global' and g.name == 'public'
        h["members"] = []
      else
        h["members"] = g.users.map{|u| u.name }
      end
      h["writable"] = !!g.writable_by(user)
      h["owner"] = g.owner.name
      h
    end

    class GroupHandler < SingleHandler
      self.table = Future::Groups
      self.key_column = 'name'

      def uneditable_columns
        super | ['namespace', 'owner_id']
      end

      def get_target
        table.rfind(@user, key_column => @key, :namespace => 'groups')
      end

      def json(req,res)
        res.content_type = 'application/json'
        h = MuryuDispatch::Groups.hashify_group(@user, @target)
        res.body = h.to_json
      end

      def edit(req,res)
        @target.write(@user) do
          @target.name = req.query['name'].to_s unless req.query['name'].to_s.empty?
          @target.public = req.query['public'].to_s == 'true' unless req.query['public'].to_s.empty?
          users = req.query['users'] || []
          users += req.query['users.new'].to_s.split(",")
          users.map!{|u| u.to_s.strip }
          users.delete_if{|u| u.empty? }
          users.uniq!
          unless users.empty?
            removed = @target.users.find_all{|m| !users.include?( m.name ) }
            removed.each{|m| @target.remove_member(m) if m.id != @target.owner_id }
            removed_names = removed.map{|m|m.name}
            new_members = users.map{|u| 
              if removed_names.include?(u) 
                nil
              else
                Future::Users.find(:name => u)
              end
            }
            new_members.each{|u| @target.add_member(u) }
          end
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

      def add_member(req,res)
        if req.query['name']
          admin = !!req.query['admin']
          @target.write(@user) do
            req.query['name'].each{|u|
              member = Future::Users.find(:name => u.to_s)
              @target.add_member(member, admin) if member
            }
          end
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

      def remove_member(req,res)
        if req.query['name']
          # can remove self from group
          if req.query['name'].size == 1 and req.query['name'][0] == @user.name and @target.owner_id != @user.id
            @target.remove_member(@user)
          else
            @target.write(@user) do
              req.query['name'].each{|u|
                member = Future::Users.find(:name => u.to_s)
                @target.remove_member(member) if member and @target.owner_id != member.id
              }
            end
          end
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

      def delete(req,res)
        @target.rdelete(@user)
      end

    end
    self.single_handler = GroupHandler

  end

end
