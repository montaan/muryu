require 'future/config'
require 'postgres'
require 'time'
require 'date'


class String

  def to_table_name
    gsub(/[A-Z]/){|i| "_#{i}"}[1..-1].to_s.downcase
  end

  def to_class_name
    gsub(/_./){|i| i[1,1].upcase}.capitalize
  end

  def rsplit(*a)
    reverse.split(*a).map{|k| k.reverse }.reverse
  end

  def cast(type)
    (DB::TYPECASTS[type] || DB::TYPECASTS[:default])[self]
  end

end


class NilClass

  def cast(type)
    nil
  end

end


class Array

  def to_hash
    h = {}
    each{|k,v| h[k] = v}
    h
  end

end


class Object

  def eigenclass
    class<<self
      self
    end
  end

end


class StandardDateTime < DateTime
  def to_s
    strftime "%Y-%m-%d %H:%M:%S"
  end
end


module DB

  class DBconn < PGconn

    def exec(query, log_level = Logger::DEBUG, subsystem = "dbconn")
      log("DBconn#exec: "+query, subsystem, log_level) { super(query) }
    end

    def query(query, log_level = Logger::DEBUG, subsystem = "dbconn")
      log("DBconn#query: "+query, subsystem, log_level) { super(query) }
    end
  
  end

  def self.establish_connection(options)
    remove_const(:Conn) if defined? Conn
    log_info("Establishing DB connection #{options.inspect}", "dbconn")
    const_set(:Conn, DBconn.new(options[:host], options[:port],
                                options[:options], nil, 
                                options[:database], options[:login],
                                options[:password]))
  end

  def self.const_missing(const_name)
    if const_name == :Conn
      establish_connection(Future.database_configuration)
    else
      super
    end
  end

  TYPECASTS = {
    "int4" => lambda{|i| i.to_i },
    "int2" => lambda{|i| i.to_i },
    "int8" => lambda{|i| i.to_i },

    "float4" => lambda{|i| i.to_f },
    "float8" => lambda{|i| i.to_f },

    "bool" => lambda{|i| i == 't'},

    "timestamp" => lambda{|i| StandardDateTime.parse i},

    :default => lambda{|i|i}
  }

  REVERSE_CASTS = {
    "int4" => lambda{|i| i.to_i },
    "int2" => lambda{|i| i.to_i },
    "int8" => lambda{|i| i.to_i },

    "float4" => lambda{|i| i.to_f },
    "float8" => lambda{|i| i.to_f },

    "bool" => lambda{|i| i == true},

    "timestamp" => lambda{|i| DB::Table.quote StandardDateTime.parse(i).to_s},

    :default => lambda{|i| DB::Table.quote i}
  }

  # Isolation level can be 'READ COMMITTED' or 'SERIALIZABLE'.
  # Access mode can be 'READ WRITE' or 'READ ONLY'.
  def self.transaction(isolation_level='read committed', access_mode='read write')
    DB::Conn.exec('BEGIN')
    DB::Conn.exec('SET TRANSACTION ISOLATION LEVEL '+isolation_level+' '+access_mode)
    rv = yield
    DB::Conn.exec('COMMIT')
    rv
  rescue TransactionRollback
    return false
  rescue
    DB::Conn.exec('ROLLBACK')
    raise
  end

  def self.rollback
    DB::Conn.exec('ROLLBACK')
    raise TransactionRollback
  end

  class TransactionRollback < StandardError
  end

  def self.nextval(sequence_name)
    DB::Conn.query("SELECT nextval(#{DB::Table.quote sequence_name})").to_s.to_i
  end
  

  class ForeignKey

    attr_accessor :foreign_table_name, :foreign_column_name,
                  :table_name, :column_name,
                  :join_table_name,
                  :join_table_column, :join_foreign_table_column

    def initialize( table_name, column_name,
                    foreign_table_name, foreign_column_name,
                    join_table_name=nil,
                    join_table_column=nil, join_foreign_table_column=nil
                    )
      @table_name = table_name
      @column_name = column_name
      @foreign_table_name = foreign_table_name
      @foreign_column_name = foreign_column_name
      @join_table_name = join_table_name
      @join_table_column = join_table_column
      @join_foreign_table_column = join_foreign_table_column
    end

    def join_table
      Tables[join_table_name]
    end

    def foreign_table
      Tables[foreign_table_name]
    end

    def get(obj, h={})
      get_all(obj, {:limit => 1}.merge(h)).first
    end

    def get_all(obj, h={})
      if join_table_name
        foreign_table.find_all({
          foreign_column_name =>
             (join_table_name+"."+join_foreign_table_column).to_sym,
          (join_table_name+"."+join_table_column) => obj[column_name]
        }.merge(h))
      else
        foreign_table.find_all({foreign_column_name => obj[column_name]}.merge(h))
      end
    end

    def cast(val, obj)
      foreign_table.find({foreign_column_name => val})
    end

    def __comparison(lvl="")
      Table.escape(foreign_table_name+lvl.succ)+"."+Table.escape(foreign_column_name)+
      " = " +
      if join_table_name
        Table.escape(join_table_name+lvl.succ)+"."+
        Table.escape(join_foreign_table_column) +
        " AND " +
        Table.escape(join_table_name+lvl.succ)+"."+
        Table.escape(join_table_column) +
        " = "
      else
        ""
      end +
      Table.escape(table_name+lvl)+"."+Table.escape(column_name)
    end

  end


  class Table

    def self.escape n
      PGconn.escape(n.to_s).dump
    rescue => e
      raise ArgumentError, "Can't escape #{n.inspect}."
    end

    def self.quote n
      case n
      when DB::Table
        PGconn.quote n.id
      else
        PGconn.quote n.to_s
      end
    rescue => e
      raise ArgumentError, "Can't quote #{n.inspect}."
    end

    def self.all_foreign_keys
      @@all_foreign_keys ||= (
        @@all_foreign_keys = Hash.new{|h,k| h[k] = Hash.new }
        @@all_joins = Hash.new{|h,k| h[k] = Hash.new{|i,l| i[l] = {}} }
        @@all_reverse_foreign_keys = Hash.new{|h,k| h[k] = Hash.new{|i,l| i[l] = {}} }
        DB::Conn.exec(%Q(
          SELECT a.relname, i.attname, b.relname,j.attname
          FROM pg_class a, pg_class b,pg_attribute i, pg_attribute j, pg_constraint
          WHERE conrelid = a.oid
            AND i.attrelid = a.oid
            AND conkey[1] = i.attnum
            AND confrelid = b.oid
            AND j.attrelid = b.oid
            AND confkey[1] = j.attnum
            AND contype = 'f'
        )).each do |tn,cn, ftn,fcn|
          @@all_foreign_keys[tn][cn] = ForeignKey.new(tn,cn, ftn,fcn)
          @@all_reverse_foreign_keys[ftn][tn][cn] = ForeignKey.new(ftn,fcn, tn,cn)
        end
        @@all_foreign_keys.each do |tn,cnfks|
          if cnfks.size > 1
            cnfks.each_with_index{|a,i|
              cnfks.each_with_index{|b,j|
                next if j <= i
                add_join(a[1],b[1])
              }
            }
          end
        end
        @@all_foreign_keys
      )
    end

    def self.add_join(fk1,fk2)
      ftn1 = fk1.foreign_table_name
      fcn1 = fk1.foreign_column_name
      tn = fk1.table_name
      cn1 = fk1.column_name
      ftn2 = fk2.foreign_table_name
      fcn2 = fk2.foreign_column_name
      cn2 = fk2.column_name
      @@all_joins[ftn1][ftn2][tn] = ForeignKey.new(ftn1,fcn1,ftn2,fcn2, tn,cn1,cn2)
      @@all_joins[ftn2][ftn1][tn] = ForeignKey.new(ftn2,fcn2,ftn1,fcn1, tn,cn2,cn1)
    end

    def self.all_reverse_foreign_keys
      @@all_reverse_foreign_keys ||= (all_foreign_keys and @@all_reverse_foreign_keys)
    end

    def self.all_joins
      @@all_joins ||= (all_foreign_keys and @@all_joins)
    end

    def self.foreign_keys
      all_foreign_keys[table_name]
    end

    def self.reverse_foreign_keys
      all_reverse_foreign_keys[table_name]
    end

    def self.joins
      all_joins[table_name]
    end

    DEFAULT_COLS = [
      'cmax', 'xmax', 'ctid', 'cmin', 'xmin', 'tableoid'
    ].map{|c| quote c }

    def self.columns
      @columns ||= DB::Conn.query("
        select attname, typname
        from pg_type t, pg_attribute a, pg_class c
        WHERE relname = #{quote table_name}
          and c.oid = attrelid
          and t.oid = atttypid
          and attname NOT IN (#{DEFAULT_COLS.join(",")})
      ").to_hash
    end

    def self.column?(name)
      columns.find{|c,t| c == name.to_s }
    end

    def self.foreign_key? k, ignore_direct=false
      (ignore_direct and foreign_keys[k.to_s]) or
      (columns[k.to_s+"_id"] and foreign_keys[k.to_s+"_id"])
    end

    def self.reverse_foreign_key? k
      reverse_foreign_keys.has_key? k.to_s
    end

    def self.join? k
      joins.has_key? k.to_s
    end

    def self.table_name= tn
      if Tables.table? tn
        @table_name = tn
        @columns = nil
        @foreign_keys = nil
        __init_columns
      end
    end

    def self.table_name
      @table_name ||= to_s.split('::').last.to_table_name
    end

    def self.find_or_create(h)
      find(h) or create(h)
    end

    def self.ground_column_name(column_name)
      return column_name if columns.include? column_name.to_s
      fkey = foreign_key?(column_name.to_s)
      if fkey
        return fkey.column_name
      end
      raise ArgumentError, "Invalid column name #{column_name} for #{table_name}"
    end

    def self.create(h)
      i = DB::Conn.exec(%Q(SELECT nextval(#{quote( table_name + "_id_seq")}) ))[0][0].to_i
      h[:id] = i
      sql = %Q[INSERT INTO #{escape table_name}
        (#{h.keys.map{|k| escape ground_column_name(k)}.join(",")})
        VALUES
        (#{h.values.map{|v| quote v}.join(",")})]
      DB::Conn.exec(sql)
      id(i)[0]
    end

    def self.delete(h={})
      if r = find(h)
        sql = %Q(
          DELETE FROM #{escape table_name}
          WHERE id = #{quote r.id})
        DB::Conn.exec(sql)
      end
    end

    def self.delete_all(h={})
      unless (rs=find_all(h)).empty?
        DB::Conn.exec(%Q(
          DELETE FROM #{escape table_name}
          WHERE id in (#{ rs.map{|r| quote r.id}.join(",") })
        ))
      end
    end

    def self.count
      sql = "SELECT count(*) FROM #{escape table_name}"
      DB::Conn.query(sql).to_s.to_i
    end

    def self.find(h={})
      find_all(h.merge(:limit => 1, :columns => :all)).first
    end

    def self.find_all(h={})
      q = query(h)
      idx = -1
      q.map{|i| new q, idx+=1 }
    rescue
      p h
      raise
    end

    def self.__comparison(k,v,lvl="0")
      k = k.to_s
      table = k.split(".").first
      if fk = foreign_key?(table.to_s)
        comp = case v
        when Table
          return __comparison(fk.column_name, v[fk.foreign_column_name], lvl)
        else
          k = k.sub(table+".","")
          ft = fk.foreign_table
          jt = fk.join_table_name
          t, pr = ft.__comparison(k,v,lvl.succ)
          t << [table_name, table_name+lvl]
          t << [jt, jt+lvl.succ] if jt
          t << [ft.table_name, ft.table_name+lvl.succ]
          pr << fk.__comparison(lvl)
          return [t,pr]
        end
      elsif table.size < k.size
        k = k.sub(table+".","")
        ft = Tables[table]
        return ft.__comparison(k,v,lvl)
      end
      k = "#{escape(table_name+lvl)}.#{escape k}"
      comp = get_comparison(k,v,lvl)
      cmp_table = []
      if v.is_a? Symbol
        vs = v.to_s.split(".")
        if vs.length > 1
          cmp_table << vs[0] << vs[0]+lvl
        end
      end
      [[table_name, table_name+lvl, *cmp_table], [comp]]
    end

    COMPARISON_OPS = ['<','>','in','not in','=','>=','<=']
    def self.get_comparison(k, v, lvl=nil)
      if v.is_a? Array and COMPARISON_OPS.include?(v[0].to_s.downcase)
        cmp, v = v
      else
        cmp = nil
      end
      case v
      when Regexp
        "#{k} ~#{'*' if v.casefold?} #{
          quote((v.inspect+" ").split("/")[1..-2].join("/"))
        }"
      when Range
        min,max = v.to_a.sort
        "#{k} >= #{quote min} AND #{k} <= #{quote max}"
      when Symbol
        vs = v.to_s.split(".")
        vs[0] << lvl if vs.length > 1
        k + " #{cmp || "="} " + vs.map{|i|escape i }.join(".")
      when Array
        if v[0].to_s[-2,2] == "()"
          f = v[0].to_s[0...-2]
          v = v[1..-1]
        end
        # problematic f(1,2,3,4) vs. (f(1),f(2),f(3),f(4)) ?
        "#{k} #{cmp || (f ? "=" : "IN")} #{f}(#{v.map{|i| quote i}.join(",")})"
      when nil
        "#{k} #{cmp || "="} FALSE"
      end or "#{k} #{cmp || "="} #{quote v}"
    end

    ### FIXME
    # handle foreign keys
    # handle reverse foreign keys
    # handle many to many keys
    # handle table references (damn it)
    # use table name as default table
    def self.parse_order_by(order_by, desc, asc)
      case order_by
      when Array
        order_by.map{|ob,d|
          escape(ob.to_s) + " #{d}"
        }.join(", ")
      else
        dir = ""
        dir = " DESC" if desc
        dir = " ASC" if asc
        escape(order_by) + dir
      end
    end

    def self.parse_query(h)
      h = h.clone
      order_by = h.delete:order_by
      desc = h.delete:desc
      asc = h.delete:asc
      limit = h.delete:limit
      offset = h.delete:offset
      cols = h.delete:columns
      case cols
      when Array
        cols = ([:id] + cols).uniq.compact
      when :all
        cols = columns.keys
      else
        cols = [:id, cols].uniq.compact
      end
      foreign_key_cols = h.keys.find_all{|k|
        f = k.to_s.split(".",2).first
        foreign_key?(f) or (k.to_s.size > f.size and Tables.table? f)
      }
      bad_cols = h.keys.find_all{|k| not columns[k.to_s]} - foreign_key_cols
      unless bad_cols.empty?
        raise(
          "Inexisting column#{'s' if bad_cols.size > 1}: #{bad_cols.join(", ")}"
        )
      end
      tables = []
      predicates = []
      h.map{|k,v| t, p = __comparison(k,v)
        tables << t
        predicates << p
      }
      tables = Hash[*tables.flatten.reverse]
      predicates.flatten!
      tn = table_name
      tn = escape(tables.find_all{|n,t| t == table_name}.min[0]) unless tables.empty?
      q =  %Q(SELECT #{cols.map{|c|tn+"."+escape(c)}.join(", ")})
      q << if tables.empty?
        %Q(\nFROM #{escape table_name})
      else
        %Q(\nFROM #{tables.map{|n,t| escape(t)+" "+escape(n) }.join(", ")})
      end
      q << %Q(\nWHERE #{predicates.uniq.join(" AND ")}) unless predicates.empty?
      q << %Q(\n#{%Q(ORDER BY #{parse_order_by order_by, desc, asc}) if order_by}
        #{"LIMIT #{limit.to_i}" if limit}
        #{"OFFSET #{offset.to_i}" if offset}
      )
      q
    end

    def self.query(h={})
      q = parse_query h
      DB::Conn.exec(q)
    rescue => e
      raise ArgumentError,
            "Failed to execute query (#{e.message}): #{q}"
    end


    def initialize(id,idx=0)
      case id
      when PGresult
        __assign_vars id, idx
      when Hash
        __assign_vars self.class.query(id), idx
      when Fixnum
        @id = id
      else
        __assign_vars self.class.query("id" => id)
      end
    end

    def <=>(other)
      id <=> other.id
    end

    def ==(other)
      (other.is_a? Table) and 
      (self.table_name == other.table_name) and
      (id == other.id)
    end
    alias_method :eql?, :==

    def hash
      @id
    end

    def to_hash
      columns.map{|c,cl|
        [c, __send__(c)]
      }.to_hash
    end
    
    def [](x)
      method_missing(x)
    end

    def []=(x,v)
      method_missing(x.to_s+"=", v)
    end

    delegate('self.class',
             :quote, :escape,
             :columns, :column?,
             :foreign_keys, :foreign_key?,
             :reverse_foreign_keys, :reverse_foreign_key?,
             :joins, :join?,
             :table_name
             )

    def pin!(*cols)
      __assign_vars self.class.query("id" => id, :columns => :all)
    end

    def pin_foreign_key!(fk, ivar_name)
      instance_variable_set("@#{ivar_name}", fk.get(self, :columns => :all))
    end

    def pin_reverse_foreign_key!(fkeys, ivar_name)
      v = fetch_reverse_foreign_keys fkeys
      instance_variable_set("@#{ivar_name}", v)
    end

    def fetch_reverse_foreign_keys(fkeys)
      fkeys.inject([]){|s,(n,f)| s += f.get_all(self, :columns => :all) }
    end

    def cast_quote(value, type)
      return "NULL" if value.nil?
      (REVERSE_CASTS[type] || REVERSE_CASTS[:default])[value]
    end

    def get_column(c)
      pin!(c) unless instance_variables.include?("@#{c}")
      instance_variable_get("@#{c}")
    end

    def set_column(c, v)
      q = %Q(
        UPDATE #{escape table_name}
        SET #{escape c} = #{cast_quote(v, columns[c])}
        WHERE id = #{quote @id}
      )
      DB::Conn.exec(q)
      instance_variable_set("@#{c}",v)
    end

    def get_foreign_key(c)
      fk = foreign_keys[c+"_id"]
      pin_foreign_key!(fk,c) unless instance_variables.include?("@#{c}")
      instance_variable_get("@#{c}")
    end

    def get_reverse_foreign_key(c)
      fkeys = reverse_foreign_keys[c]
      pin_reverse_foreign_key!(fkeys,c) unless instance_variables.include?("@#{c}")
      instance_variable_get("@#{c}")
    end

    def get_join(c)
      fkeys = joins[c]
      pin_reverse_foreign_key!(fkeys,c) unless instance_variables.include?("@#{c}")
      instance_variable_get("@#{c}")
    end

    def method_missing(c, *a)
      c = c.to_s
      if c[-1,1] == "="
        c = c[0..-2]
        super if a.empty? or not column?(c)
        set_column(c, a[0])
      elsif column?(c)
        get_column(c)
      elsif foreign_key?(c, true)
        get_foreign_key(c)
      elsif reverse_foreign_key?(c)
        get_reverse_foreign_key(c)
      elsif join?(c)
        get_join(c)
      elsif fk = foreign_keys.find{|a,k| a != table_name and
                                         k.foreign_table.columns[c]}
        pin_foreign_key!(fk[1],c) unless instance_variables.include?("@#{c}")
        instance_variable_get("@#{c}").__send__(c)
      elsif fk = reverse_foreign_keys.find{|a,k| a != table_name and
                                                 Tables[a].columns[c[0..-2]]}
        cs = c[0..-2]
        a = fk[0]
        pin_reverse_foreign_key!(fk[1],a) unless instance_variables.include?("@#{a}")
        instance_variable_get("@#{a}").inject([]){|t,r| t << r.__send__(cs) }
      elsif fk = joins.find{|a,k| a != table_name and
                                  Tables[a].columns[c[0..-2]]}
        cs = c[0..-2]
        a = fk[0]
        pin_reverse_foreign_key!(fk[1],a) unless instance_variables.include?("@#{a}")
        instance_variable_get("@#{a}").inject([]){|t,r| t << r.__send__(cs) }
      else
        raise NameError, "Unknown column `#{c}'"
      end
    end

  private

    def __assign_vars(res,idx=0)
      cols = columns
      res.fields.zip(res[idx]){|k,v|
        instance_variable_set( "@"+k, v.cast(cols[k.to_s]) )
      }
    end

    def self.inherited(klass)
      klass.table_name = klass.to_s.to_table_name
    end

    def self.__init_columns
      columns.each{ |c,t|
        define_method(c){|*a| method_missing(c,*a) }
        define_method(c+"="){|*a| method_missing(c+"=",*a) }
        eigenclass.__send__(:define_method,c) do |*a|
          if a.empty?
            data_type = columns[c]
            DB::Conn.query(%Q(
              SELECT #{escape c}
              FROM #{escape table_name}
            )).flatten.map{|c| c.cast data_type }
          else
            q = %Q(
              SELECT id
              FROM #{escape table_name}
              WHERE #{
                a.map{|i|
                  %Q(#{escape c} = #{quote a})
                }.join(" OR ")
              }
            )
            DB::Conn.query(q).flatten.map{|i| new i }
          end
        end
      }
    end


  end


  module Tables

    @@tables = {}

    def self.tables
      @@tables
    end

    def self.[](name)
      if @@tables.has_key? name
        @@tables[name]
      else
        c = Class.new(Table)
        c.table_name = name
        @@tables[name] = c
      end
    end

    def self.const_missing(c)
      if table? c.to_s.to_table_name
        t = self[c.to_s.to_table_name]
        const_set(c, t)
      else
        super
      end
    end

    def self.table? tn
      q = "SELECT oid FROM pg_class WHERE relname = #{Table.quote tn}"
      DB::Conn.query(q).size > 0
    end

  end


end
