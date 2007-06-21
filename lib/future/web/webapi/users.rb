module MuryuDispatch

  module Users
  include Handler
  extend self

    ### VERBS

    def set_preferences(user, req, res)
      if user != Future::Users.anonymous
        ws = user.workspace
        req.query.each{|k,v|
          pr = DB::Tables::Preferences.find_or_create(:workspace => ws, :key => k)
          pr.value = v
        }
      end
      res.body = 'OK'
    end

    def delete_preferences(user, req, res)
      if user != Future::Users.anonymous
        ws = user.workspace
        DB::Tables::Preferences.delete_all(:workspace => ws, :key => req.query.keys)
      end
      res.body = 'OK'
    end
    
    def clear_preferences(user, req, res)
      if user != Future::Users.anonymous
        DB::Tables::Preferences.delete_all(:workspace => user.workspace)
      end
      res.body = 'OK'
    end

    def create_workspace(user,req,res)
      if user != Future::Users.anonymous
        name = req.query['name'].to_s
        DB::Tables::Workspaces.find_or_create(:user=>user, :name=>name)
      end
      res.body = 'OK'
    end

    def set_workspace(user,req,res)
      if user != Future::Users.anonymous
        name = req.query['name'].to_s
        ws = DB::Tables::Workspaces.find(:user=>user, :name=>name)
        user.workspace_id = ws.id if ws
      end
      res.body = 'OK'
    end
    
    def delete_workspace(user,req,res)
      if user != Future::Users.anonymous
        name = req.query['name'].to_s
        if name != 'default'
          if user.workspace.name == name
            user.workspace_id = DB::Tables::Workspaces.find(
              :user=>user, :name=>'default').id
          end
          DB::Tables::Workspaces.delete(:user=>user, :name=>name)
        end
      end
      res.body = 'OK'
    end

    def create(user,req,res)
      un = req.query['username']
      pw = req.query['password']
      if un and pw
        user.logout if user
        if (not Future::Users.find(:name => un)) and user = Future::Users.register(un, pw)
          MuryuDispatch.authenticate(req,res)
          res.body = Builder::XmlMarkup.new.html do |b|
            b.head { b.title("Registered new account!") }
            b.body {
              b.h1 { print_navigation_path(req, b) }
              b.h2( "Welcome aboard, #{un}! We hope you enjoy the ride!" )
            }
          end
        else
          res.body = Builder::XmlMarkup.new.html do |b|
            b.head { b.title("Registration failed") }
            b.body {
              b.h1 { print_navigation_path(req, b) }
              b.h2("Failed to register account, someone is already using '#{un}'.")
              b.h2("Please try another name.")
              registration_form(b)
            }
          end
        end
      else
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Registration failed") }
          b.body {
            b.h1 { print_navigation_path(req, b) }
            b.h2("Failed to register account, both username and password are required.")
            registration_form(b)
          }
        end
      end
    end

    def login(user,req,res)
      if user != Future::Users.anonymous
        res.status = 302
        res['location'] = '/'
      elsif req.query['username']
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Failed to log in.") }
          b.body {
            b.h1 { print_navigation_path(req, b) }
            b.h2("Login failed, please try again.")
            b.p { b.a("Register new account", :href=>'/users/register') }
            login_form(b)
          }
        end
      else
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title("Log in") }
          b.body {
            b.h1 { print_navigation_path(req, b) }
            b.h2("Come on in!")
            b.p { b.a("Register new account", :href=>'/users/register') }
            login_form(b)
          }
        end
      end
    end

    def logout(user,req,res)
      if user != Future::Users.anonymous
        user.logout
        Future.memcache.delete("session-#{req.session_id}")
      end
      res.status = 302
      res['Location'] = '/'
    end

    def delete(user,req,res)
      if user != Future::Users.anonymous
        user.logout
        user.delete
      end
    end

    ### PROPERTIES

    def json(user,req,res)
      if user != Future::Users.anonymous
        res.content_type = 'application/json'
        name = user.name
        workspace = user.workspace.name
        workspaces = user.workspaces.map{|w| w.name }
        preferences = user.workspace.preferences.map{|pr|
          [pr.key, pr.value]
        }.to_hash
        res.body = {
          'name' => name,
          'workspace' => workspace,
          'workspaces' => workspaces,
          'preferences' => preferences
        }.to_json
      else
        res.content_type = 'application/json'
        res.body = "{'name':'anonymous'}"
      end
    end

    def register(user,req,res)
      res.body = Builder::XmlMarkup.new.html do |b|
        b.head { b.title("Registering account.") }
        b.body {
          b.h1 { print_navigation_path(req, b) }
          b.h2('Register')
          registration_form(b)
        }
      end
    end

    def view(user,req,res)
      login(user,req,res)
    end

    ### helpers

    def path_key
      :name
    end

    def invisible_columns
      super | [:password, :workspace_id]
    end

    def registration_form(b)
      b.form(:method => 'POST', :action => '/users/create') {
        b.h3("Username")
        b.input(:type => 'text', :name => 'username')
        b.h3("Password")
        b.input(:type => 'password', :name => 'password')
        b.br
        b.input(:type => 'submit', :value => 'Register')
      }
    end
    
    def login_form(b)
      b.form(:method => 'POST', :action => '/users/login') {
        b.h3("Username")
        b.input(:type => 'text', :name => 'username')
        b.h3("Password")
        b.input(:type => 'password', :name => 'password')
        b.br
        b.input(:type => 'submit', :value => 'Log in')
      }
    end
    
  end

end