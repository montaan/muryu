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
      groups = Future::Groups.rfind_all(user, :columns => :all)
      groups.map{|g|
        next if (g.namespace == 'users')
        hashify_group(user, g)
      }.compact
    end

    def hashify_group(user, g)
      h = g.to_hash
      h.delete("owner_id")
      h.delete("id")
      h.delete("namespace")
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
        h["members"] = @target.users.map{|u| u.name }
        res.body = h.to_json
      end

      def edit(req,res)
        @target.write(@user) {
          @target.name = req.query['name'].to_s unless req.query['name'].to_s.empty?
          @target.public = req.query['public'].to_s == 'true' unless req.query['public'].to_s.empty?
        }
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