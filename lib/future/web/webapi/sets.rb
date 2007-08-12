module MuryuDispatch

  module Sets
  include Handler
  extend self

    ### VERBS

    def create(user,req,res)
      set = Future::Sets.rcreate(
        :owner => user,
        :name => req.query['name'].to_s
      )
      if set
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
      res.body = get_sets(user, req).to_json
    end

    def view(user,req,res)
    end

    ### helpers

    def get_sets(user, req)
      sets = Future::Sets.rfind_all(user, :columns => :all, :order_by => [[:name, :asc]])
      sets.map{|s|
        hashify_set(user, s)
      }.compact
    end

    def hashify_set(user, set)
      h = set.to_hash
      h.delete("owner_id")
      h.delete("id")
      h["writable"] = !!set.writable_by(user)
      h["namespace"] = h["namespace"].split(":",2).last
      if h["writable"]
        h["groups"] = set.groups.map{|g| g.namespace+"/"+g.name }
      else
        h["groups"] = []
      end
      h["owner"] = set.owner.name
      h
    end

    class SetHandler < SingleHandler
      self.table = Future::Sets
      self.key_column = 'name'

      def uneditable_columns
        super | ['namespace', 'owner_id', 'deleted']
      end

      def invisible_columns
        super | ['namespace', 'deleted']
      end

      def get_target
        username, name = @key.split("/")
        table.rfind(@user, :name => name, :namespace => "#{username}")
      end

      def json(req,res)
        res.content_type = 'application/json'
        h = MuryuDispatch::Sets.hashify_set(@user, @target)
        res.body = h.to_json
      end

      def edit(req,res)
        @target.write(@user) do
          @target.name = req.query['name'].to_s unless req.query['name'].to_s.empty?
          @target.public = req.query['public'].to_s == 'true' unless req.query['public'].to_s.empty?
          if req.query['groups'] || req.query['groups.new']
            can_modify = req.query['can_modify'].to_s == 'true'
            groups = req.query['groups'] || []
            groups += req.query['groups.new'].join(",").split(",")
            groups.map!{|n| n.strip.split("/",2) }
            groups.delete_if{|n| n.size != 2 }
            group_idx = Hash.new{|h,k| h[k] = {}}
            groups.each{|ns,n| group_idx[ns][n] = true }
            old_groups = @target.groups([:name, :namespace])
            old_groups.delete_if{|og| group_idx[og.namespace][og.name] }
            old_groups.each{|og| 
              next if og.namespace == 'users' and og.name == @target.owner.name
              @target.remove_group(og)
            }
            groups.each{|ns, n|
              next if ns == 'users' and n == @target.owner.name
              group = Future::Groups.find(:namespace => ns.to_s, :name => n.to_s)
              @target.add_group(group, can_modify) if group
            }
          end
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

      def add_group(req,res)
        if req.query['name']
          can_modify = req.query['can_modify'].to_s == 'true'
          @target.write(@user) do
            req.query['name'].each{|u|
              ns, n = u.to_s.strip.split("/")
              if ns and n and not (ns.empty? or n.empty?)
                next if ns == 'users' and n == @target.owner.name
                group = Future::Groups.find(:namespace => ns.to_s, :name => n.to_s)
                @target.add_group(group, can_modify) if group
              end
            }
          end
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

      def remove_group(req,res)
        if req.query['name']
          @target.write(@user) do
            req.query['name'].each{|u|
              ns, n = u.to_s.strip.split("/")
              if ns and n and not (ns.empty? or n.empty?)
                next if ns == 'users' and n == @target.owner.name
                group = Future::Groups.find(:namespace => ns.to_s, :name => n.to_s)
                @target.remove_group(group) if group
              end
            }
          end
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

      def delete(req,res)
        @target.write(@user) do
          Future::Sets.delete(:id => @target)
        end
        res.content_type = "text/plain"
        res.body = "OK"
      end

    end
    self.single_handler = SetHandler

  end

end
