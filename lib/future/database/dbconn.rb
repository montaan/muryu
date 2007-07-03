require 'thread'
require 'future/config'
require 'postgres'
require 'time'
require 'date'

if $DB_USE_POOL == nil
  $DB_USE_POOL = true
end

class Thread
  attr_accessor :conn
end

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

  attr_writer :predicate

  def +@
    @predicate = 'ALL'
    self
  end

  def -@
    @predicate = 'NOT ANY'
    self
  end

  def predicate
    @predicate ||= 'ANY'
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
    strftime "%Y-%m-%d %H:%M:%S %z"
  end
end


module DB

  class DBconn < PGconn

    def exec(query, log_level = Logger::DEBUG, subsystem = "dbconn")
      log("DBconn#exec: "+query, subsystem, log_level) {
        super(query)
      }
    end

    def query(query, log_level = Logger::DEBUG, subsystem = "dbconn")
      log("DBconn#query: "+query, subsystem, log_level) {
        super(query)
      }
    end
  
  end


  class Pool

    attr_accessor :objects, :klass, :args

    def initialize(klass, count=6, *args)
      @klass = klass
      @args = args
      @objects = Queue.new
      count.times{ allocate_new }
    end

    def allocate_new
      @objects.push(@klass.new(*args))
    end

    def reserve
      if Thread.current.conn.is_a? klass
        yield Thread.current.conn
      else
        begin
          obj = @objects.shift
          yield obj
        ensure
          @objects.push(obj)
        end
      end
    end

    def close
      @objects.shift.close until @objects
    end
  
    def method_missing(*a, &b)
      reserve do |obj|
        obj.__send__(*a, &b)
      end
    end

  end


  def self.establish_connection(options)
    remove_const(:Conn) if defined? Conn
    log_info("Establishing DB connection #{options.inspect}", "dbconn")
    if $DB_USE_POOL
      const_set(:Conn, Pool.new(DBconn, 6, options[:host], options[:port],
                                  options[:options], nil, 
                                  options[:database], options[:login],
                                  options[:password]))
    else
      const_set(:Conn, DBconn.new(options[:host], options[:port],
                                  options[:options], nil, 
                                  options[:database], options[:login],
                                  options[:password]))
    end
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

    "timestamp" => lambda{|i| StandardDateTime.parse(i) },

    :default => lambda{|i|i}
  }

  REVERSE_CASTS = {
    "int4" => lambda{|i| i.to_i },
    "int2" => lambda{|i| i.to_i },
    "int8" => lambda{|i| i.to_i },

    "float4" => lambda{|i| i.to_f },
    "float8" => lambda{|i| i.to_f },

    "bool" => lambda{|i| i == true},

    "timestamp" => lambda{|i|
      DB::Table.quote(
        case i
        when Time, StandardDateTime
          i.to_s
        else
          StandardDateTime.parse(i).to_s
        end
      )
    },

    :default => lambda{|i| DB::Table.quote i}
  }

  class SQLString < String
  end

  # Isolation level can be 'READ COMMITTED' or 'SERIALIZABLE'.
  # Access mode can be 'READ WRITE' or 'READ ONLY'.
  def self.transaction(isolation_level='read committed', access_mode='read write')
    new_conn = false
    conn = Thread.current.conn
    unless conn.is_a?(DBconn)
      new_conn = true
      conn = DB::Conn.objects.shift
      Thread.current.conn = conn
    end
    begin
      conn.exec('BEGIN')
      conn.exec('SET TRANSACTION ISOLATION LEVEL '+isolation_level+' '+access_mode)
      rv = yield
      conn.exec('COMMIT')
      rv
    rescue TransactionRollback
      return false
    rescue
      conn.exec('ROLLBACK')
      raise
    ensure
      if new_conn
        Thread.current.conn = nil
        DB::Conn.objects.push(conn)
      end
    end
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
          foreign_column_name => obj[join_table_name].map{|tn| tn[join_foreign_table_column]}
        }.merge(h))
      else
        foreign_table.find_all({foreign_column_name => [obj[column_name]]}.merge(h))
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
    
    def where_comparison(table_lvl="", foreign_lvl="")
      Table.escape(foreign_table_name+foreign_lvl)+"."+Table.escape(foreign_column_name)+
      " = " +
      if join_table_name
        Table.escape(join_table_name+foreign_lvl)+"."+
        Table.escape(join_foreign_table_column) +
        " AND " +
        Table.escape(join_table_name+foreign_lvl)+"."+
        Table.escape(join_table_column) +
        " = "
      else
        ""
      end +
      Table.escape(table_name+table_lvl)+"."+Table.escape(column_name)
    end

  end


  class Table

    DEFAULT_COLS = [
      'cmax', 'xmax', 'ctid', 'cmin', 'xmin', 'tableoid'
    ]

    class << self

      def conn
        Thread.current.conn ||= DB::Conn
      end

      # Escapes +n+ as an SQL name.
      def escape n
        DBconn.escape(n.to_s).dump
      rescue => e
        raise ArgumentError, "Can't escape #{n.inspect}: #{e} #{e.message}"
      end

      # Quotes +n+ as an SQL variable.
      def quote n
        case n
        when DB::Table
          DBconn.quote n.id
        when nil
          "NULL"
        else
          DBconn.quote n.to_s
        end
      rescue => e
        raise ArgumentError, "Can't quote #{n.inspect}: #{e} #{e.message}"
      end

      # Gets all foreign keys for the table.
      # Gathers out foreign keys, joins and reverse foreign keys if they don't
      # exist yet.
      def all_foreign_keys
        @@all_foreign_keys ||= (
          gather_foreign_keys
          @@all_foreign_keys
        )
      end

      def gather_foreign_keys
        @@all_foreign_keys = Hash.new{|h,k| h[k] = Hash.new }
        @@all_joins = Hash.new{|h,k| h[k] = Hash.new{|i,l| i[l] = {}} }
        @@all_reverse_foreign_keys = Hash.new{|h,k| h[k] = Hash.new{|i,l| i[l] = {}} }
        conn.exec(%Q(
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
      end

      def all_columns
        @@all_columns ||= gather_columns
      end

      def gather_columns
        cols = Hash.new{|h,k| h[k] = {} }
        conn.query("
          select relname, attname, typname
          from pg_type t, pg_attribute a, pg_class c
          WHERE c.oid = attrelid
            and t.oid = atttypid
            and attname NOT IN (#{DEFAULT_COLS.map{|c| quote c }.join(",")})
        ").each{|t,c,tp|
          cols[t][c] = tp
        }
        cols
      end

      def add_join(fk1,fk2)
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

      def all_reverse_foreign_keys
        @@all_reverse_foreign_keys ||= (
          gather_foreign_keys
          @@all_reverse_foreign_keys
        )
      end

      def all_joins
        @@all_joins ||= (
          gather_foreign_keys
          @@all_joins
        )
      end

      def foreign_keys
        all_foreign_keys[table_name]
      end

      def reverse_foreign_keys
        all_reverse_foreign_keys[table_name]
      end

      def joins
        all_joins[table_name]
      end

      def columns
        all_columns[table_name]
      end

      def column?(name)
        columns.find{|c,t| c == name.to_s }
      end

      def foreign_key?(k, ignore_direct=false)
        (ignore_direct and foreign_keys[k.to_s]) or
        (columns[k.to_s+"_id"] and foreign_keys[k.to_s+"_id"])
      end

      def reverse_foreign_key? k
        reverse_foreign_keys.has_key? k.to_s
      end

      def join? k
        joins.has_key? k.to_s
      end

      def table_name= tn
        if Tables.table? tn
          @table_name = tn
          @columns = nil
          @foreign_keys = nil
          __init_columns
        end
      end

      def table_name
        @table_name ||= to_s.split('::').last.to_table_name
      end

      def find_or_create(h)
        find(h) or create(h)
      end

      def ground_column_name(column_name)
        return column_name if columns.include? column_name.to_s
        fkey = foreign_key?(column_name.to_s)
        if fkey
          return fkey.column_name
        end
        raise ArgumentError, "Invalid column name #{column_name} for #{table_name}"
      end

      def create(h)
        i = conn.exec(%Q(SELECT nextval(#{quote( table_name + "_id_seq")}) ))[0][0].to_i
        h[:id] = i
        sql = %Q[INSERT INTO #{escape table_name}
          (#{h.keys.map{|k| escape ground_column_name(k)}.join(",")})
          VALUES
          (#{h.values.map{|v| quote(v)}.join(",")})]
        conn.exec(sql)
        #id(i)[0]
        new(i)
      end

      def delete(h={})
        if r = find(h)
          sql = %Q(
            DELETE FROM #{escape table_name}
            WHERE id = #{quote r.id})
          conn.exec(sql)
        end
      end

      def delete_all(h={})
        unless (rs=find_all(h)).empty?
          conn.exec(%Q(
            DELETE FROM #{escape table_name}
            WHERE id in (#{ rs.map{|r| quote r.id}.join(",") })
          ))
        end
      end

      def count
        sql = "SELECT count(*) FROM #{escape table_name}"
        conn.query(sql).to_s.to_i
      end

      def find(h={})
        find_all(h.merge(:limit => 1, :columns => :all)).first
      end

      def find_all(h={})
        arr = h[:as_array]
        q = query(h)
        return q.result if arr
        idx = -1
        q.map{|i| new q, idx+=1 }
      end


      ### FIXME
      # handle foreign keys
      # handle reverse foreign keys
      # handle many to many keys
      # use table name as default table
      def parse_order_by(order_by, desc, asc)
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

      # Parses a query hash of format
      # 
      # { key => values }
      # 
      # into an array of format
      # 
      # [[column_address, [[set_predicate, value_predicate, values], ...]], ...]
      # 
      # column_address ::= [foreign_keys]column_name
      # foreign_keys ::= foreign_key, [foreign_keys]
      # 
      # Expressiveness problems:
      #  - column name should be in values
      #  - procedure calls not handled, value keys?
      #    e.g. lower(sets.owner.name) == substring(sets.namespace, 6)
      #
      # key ::= [table_names]column_name
      # table_names ::= ( foreign_key
      #                  | reverse_foreign_key
      #                  | join
      #                ).[table_names]
      #                | e
      #
      # values ::= [value_set_comparisons]
      # value_set_comparisons ::= value_set_comparison, value_set_comparisons
      #                           | value_set_comparison
      # value_set_comparison ::= set_predicate[value_array]
      # set_predicate ::= + | - | e
      # value_array ::= [value_predicate,] value_array_values
      # value_predicate ::= < | <= | > | >= | = | !=
      # value_array_values ::= value, value_array_values | value
      #
      #
      def parse_query_hash_into_comparison_arrays(h)
        h = h.clone
        bad_cols = []
        comparisons = []
        h.each{|key, vals|
          key = key.to_s
          fk = expand_key(key)
          if fk
            vals = [vals] unless vals.is_a? Array
            vals = [vals] unless vals[0].is_a? Array
            val_comps = []
            vals.each do |val|
              set_predicate = val.predicate
              val_pred = extract_value_predicate(val)
              if set_predicate == "ALL"
                val.each{|v| comparisons << [fk, [["", val_pred, [v]]]] }
              elsif set_predicate == "NOT ANY"
                comparisons << [["id"], [["NOT ANY", :"=", [not_any_sql_string(fk, val_pred, val)]]]]
              else
                val_comps << [set_predicate, val_pred, val]
              end
            end
            comparisons << [fk, val_comps] unless val_comps.empty?
          else
            bad_cols << key
          end
        }
        unless bad_cols.empty?
          raise(
            "Inexisting column#{'s' if bad_cols.size > 1}: #{bad_cols.join(", ")}"
          )
        end
        comparisons
      end

      def not_any_sql_string(fk, val_pred, val)
        q = []
        q << "SELECT #{escape table_name}.id"
        f,w = parse_comparison_arrays_into_from_where([[fk, [["ANY", val_pred, val]]]])
        q.push(*parse_from_where_into_sql(f,w))
        sql q.join("\n")
      end

      def sql(str)
        SQLString.new(str)
      end

      def parse_comparison_arrays_into_from_where(arrays)
        idx = 0
        from = [escape(table_name)]
        where = []
        arrays.each_with_index do |(cols, vals), idx|
          tbl = table_name
          table = self
          cols.each_with_index do |fk, lvl|
            if fk.is_a? ForeignKey
              table, tbl = parse_column_address_segment(fk, idx, lvl, from, where)
            else
              vals.map do |set_predicate, value_predicate, values|
                where << parse_value_comparison(table, tbl, fk,
                                     set_predicate, value_predicate, values)
              end
            end
          end
        end
        [from, where]
      end

      def parse_value_comparison(table, tbl, col, set_predicate, value_predicate, values)
        pre = ""
        set_predicate, pre = pre, set_predicate if set_predicate == "NOT"
        pre, set_predicate = "NOT", "ANY" if set_predicate == "NOT ANY"
        if values.size == 1 and not values[0].is_a? SQLString
          set_predicate = ''
        end
        if values.size == 0 && set_predicate == "ANY" || set_predicate == "ALL"
          case value_predicate
          when :'!='
            return "TRUE"
          else 
            return "FALSE"
          end
        end
        pre << " " unless pre.empty?
        quoted_vals = values.map do |v|
          v = v['id'] if v.is_a? DB::Table # replace id with the referred column...
          cast_quote(v, table.columns[col])
        end.join(",")
        if set_predicate.empty? || values[0].is_a?(SQLString)
          delimiters = ["", ""]
        else
          delimiters = ["ARRAY[", "]"]
        end

        pre + "#{escape tbl}.#{escape col} " + "#{value_predicate} #{set_predicate} " +
        "(" + delimiters.first + quoted_vals + delimiters.last + ")"
      end
      
      def parse_column_address_segment(fk, idx, lvl, from, where)
        f = fk.foreign_table_name
        table = fk.foreign_table
        tbl = "#{f}_#{idx}_#{lvl}"
        from << "#{escape f} #{escape tbl}"
        j = fk.join_table_name
        from << "#{escape j} #{escape "#{j}_#{idx}_#{lvl}"}" if j
        if lvl == 0
          where << fk.where_comparison("", "_#{idx}_#{lvl}")
        else
          where << fk.where_comparison("#{idx}_#{lvl-1}", "_#{idx}_#{lvl}")
        end
        [table, tbl]
      end

      def parse_from_where_into_sql(from, where)
        q = []
        q << "FROM #{from.join(",\n     ")}"
        q << "WHERE (#{where.join(")\n  AND (")})" unless where.empty?
        q
      end

      def parse_query_hash_into_sql_array(hash)
        arrays = parse_query_hash_into_comparison_arrays(hash)
        from, where = parse_comparison_arrays_into_from_where(arrays)
        parse_from_where_into_sql(from, where)
      end
      
      VALUE_PREDICATES = [:<, :>, :'=', :'!=', :>=, :<=, :'~', :'~*']
      def extract_value_predicate(val)
        if VALUE_PREDICATES.include? val[0]
          val.shift
        else
          if val[0].is_a? Regexp
            :"~#{'*' if val[0].casefold?}"
          else
            :'='
          end
        end
      end

      def expand_key(key)
        keys = key.split(".")
        if keys.size == 1 and column? keys[0]
          fk = [key]
        else
          tbl = expand_column_name(keys.shift)
          fk = [tbl] + keys.map{|col|
            next unless tbl
            tbl = (tbl.foreign_table.expand_column_name(col) rescue false)
          }
          return false unless fk.last
        end
        fk << fk.last.foreign_column_name if fk.last.is_a? ForeignKey
        fk
      end
        
      def expand_column_name(name)
        if column?(name)
          name
        else # foreign table reference
          if foreign_key? name
            foreign_keys[name] || foreign_keys[name+"_id"]
          elsif reverse_foreign_key? name
            reverse_foreign_keys[name].to_a[0]
          elsif join? name
            joins[name]["#{table_name}_#{name}"]
          else # invalid key
            false
          end
        end
      end

      def parse_query_into_sql_array(h)
        h = h.clone
        order_by = h.delete:order_by
        desc = h.delete:desc
        asc = h.delete:asc
        limit = h.delete:limit
        offset = h.delete:offset
        cols = h.delete:columns
        arr = h.delete:as_array
        pre = (arr ? nil : :id)
        case cols
        when Array
          cols = ([pre] + cols).uniq.compact
        when :all
          cols = columns.keys
        else
          cols = [pre, cols].uniq.compact
        end
        tn = escape(table_name)
        q = []
        q << %Q[SELECT #{cols.map{|c|tn+"."+escape(c)}.join(", ")} FROM #{tn} WHERE id IN (]
        q << %Q(SELECT DISTINCT #{tn+".id"})
        q.push(*parse_query_hash_into_sql_array(h))
        q << %Q[ORDER BY #{tn+".id"} )]
        q << %Q(ORDER BY #{parse_order_by order_by, desc, asc}) if order_by
        q << %Q(LIMIT #{limit.to_i}) if limit
        q << %Q(OFFSET #{offset.to_i}) if offset
        q
      end

      def parse_query(h)
        parse_query_into_sql_array(h).join("\n")
      end

      def query(h={})
        q = parse_query h
        conn.exec(q)
      end

      def cast_quote(value, type)
        case value
        when nil
          return "NULL"
        when SQLString
          return value
        when Regexp
          value = (value.inspect+" ").split("/")[1..-2].join("/")
        end
        (REVERSE_CASTS[type] || REVERSE_CASTS[:default])[value]
      end

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
             :conn, :quote, :escape,
             :columns, :column?,
             :foreign_keys, :foreign_key?,
             :reverse_foreign_keys, :reverse_foreign_key?,
             :joins, :join?,
             :table_name, :cast_quote
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
      conn.exec(q)
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
        instance_variable_set( "@#{k}", v.cast(cols[k]) )
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
            conn.query(%Q(
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
            conn.query(q).flatten.map{|i| new i }
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
