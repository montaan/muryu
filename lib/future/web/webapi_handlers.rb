module MuryuDispatch

  module Handler
    attr_accessor :single_handler
    
    def [](user, key)
      single_handler.new(user, key)
    end

    def print_navigation_path(req, b)
      b.a("muryu", :href => '/')
      b.text!("/")
      b.a(req.type, :href => '/'+req.type)
    end

    def print_user_info(b)
      b.a(user.name, :href => "/users/#{user.name}")
      b.text!(" (")
      b.a("sign out", :href => "/users/logout")
      b.text!(")")
    end

    class SingleHandler
      class << self
        attr_accessor :key_column, :table
      end
      self.key_column = 'id'

      attr_reader :user, :target, :key

      def initialize(user, key)
        @user = user
        @key = key
        if table
          @target = get_target
          unless @target
            raise(MuryuQuery::NotFound, "Target not found or you (#{@user.name}) have no access permissions to: #{key}")
          end
        end
      end

      def get_target
        table.rfind(@user, key_column => @key)
      end

      def key_column
        self.class.key_column
      end

      def table
        self.class.table
      end

      def column?(k)
        table.column?(k)
      end

      def columns
        table.columns
      end

      def uneditable_columns
        [:id, :owner_id, :created_at, :modified_at] | ((!target or target.writable_by(user)) ? [] : columns.keys)
      end

      def uneditable_column?(c)
        uneditable_columns.find{|ic| ic.to_s.downcase == c.to_s.downcase }
      end

      def invisible_columns
        [:id]
      end

      def invisible_column?(c)
        invisible_columns.find{|ic| ic.to_s.downcase == c.to_s.downcase }
      end

      def edit(req,res)
        target.write(user) do
          DB.transaction do
            edits = req.query.find_all{|k,v|
              column?(k) and target[k].to_s != v and
              not uneditable_column?(k)
            }
            edits.each{|k,v|
              target[k] = v
            }
            target[:modified_at] = Time.now.to_s if column?('modified_at')
          end
        end
        res.body = 'OK'
      end
      
      def view_actions(req)
        if target.writable_by(user)
          if column?('deleted') and target.deleted
            [["Undelete", File.join('/', req.path, "undelete")]]
          else
            [["Delete", File.join('/', req.path, "delete")]]
          end + if column?('deleted') and respond_to?('purge')
            [["Purge", File.join('/', req.path, "purge")]]
          else
            []
          end
        else
          []
        end
      end

      def view_properties(req)
        []
      end

      def print_navigation_path(req, b)
        b.a("muryu", :href => '/')
        b.text!("/")
        b.a(req.type, :href => '/'+req.type)
      end

      def print_user_info(b)
        b.a(user.name, :href => "/users/#{user.name}")
        b.text!(" (")
        b.a("sign out", :href => "/users/logout")
        b.text!(")")
      end

      def view(req,res)
        vals = columns.map{|c,cl| target[c] }
        res.body = Builder::XmlMarkup.new.html do |b|
          b.head { b.title(table.table_name)
            b.style(:type => 'text/css'){
              b.comment!(%Q(
                .edit_input{
                  display: none;
                  font-family: Arial, Helvetica;
                  font-size: 10pt;
                }
                .column_value {
                  font-family: Arial, Helvetica;
                  font-size: 10pt;
                }
                .editable:after {
                  content: "edit";
                  color: blue;
                  text-decoration: underline;
                  margin-left:6px;
                  cursor: pointer;
                }
              ))
            }
            b.script {
              b.comment!(%Q(
                function makeEditable(i,s) {
                  i.style.width = Math.max(parseInt(s.offsetWidth) + 20, 200) + 'px'
                  i.style.marginTop = '-3px'
                  i.style.marginBottom = '-3px'
                  i.style.marginLeft = '-2px'
                  s.style.display = 'none'
                  i.style.display = 'inherit'
                  i.focus()
                }
                function makeNotEditable(i,s) {
                  i.style.marginTop = i.style.marginBottom = i.style.marginLeft = null
                  i.style.display = 'none'
                  s.innerHTML = i.value
                  s.style.display = 'inline'
                }
                function initInput(i) {
                  var s = document.getElementById("div_" + i.id)
                  i.addEventListener("blur", function(){ makeNotEditable(i,s) }, false)
                  s.addEventListener("click", function(){ makeEditable(i,s) }, false)
                }
                window.addEventListener("load", function(){
                  var inputs = document.getElementsByTagName("input")
                  for(var j=0; j<inputs.length; j++) {
                    var i = inputs[j]
                    if (i.className == 'edit_input') {
                      initInput(i)
                    }
                  }
                  document.getElementById('edit_link').style.display = 'none'
                }, false)
              //))
            }
          }
          b.body {
            b.h1 {
              print_navigation_path(req,b)
              b.text!("/")
              b.a(req.key, :href => '/' + req.path)
            }
            b.p { print_user_info(b) }
            actions = view_actions(req)
            unless actions.empty?
              b.h2("Actions")
              b.ul {
                actions.each{|name, href|
                  b.li {
                    b.form(:method=>'POST', :action=>href){
                      b.input(:type=>'submit', :value=>name)
                    }
                  }
                }
              }
            end
            properties = view_properties(req)
            unless properties.empty?
              b.h2("Properties")
              b.ul {
                view_properties(req).each{|name|
                  b.li {
                    b.a(name, :class => 'action_link', :href => File.join('/', req.path, name))
                  }
                }
              }
            end
            b.form(:method => 'POST', :action => File.join('/', req.path, "edit")){
              columns.sort.each{|c,cl|
                next if invisible_column? c
                b.h3("#{c} (#{cl})")
                b.p {
                  if uneditable_column? c
                    b.span(target[c], :class => "column_value", :id => "div_#{c}")
                  else
                    b.span(target[c], :class => "column_value editable", :id => "div_#{c}")
                    b.input(:class => "edit_input", :id => c, :type => 'text', :name => c, :value => target[c])
                  end
                }
              }
              b.p { b.input(:type => 'submit', :value => 'Save changes' )}
            }
            b.p { b.a("Edit", :id => 'edit_link', :href => File.join('/', req.path, "edit")) }
          }
        end
      end

    end


  end
  
  
end


%w(items files sets users groups tile tile_info).each do |f|
  require "future/web/webapi/#{f}.rb"
end