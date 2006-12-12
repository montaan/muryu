require 'postgres'


module DB


class Creator
include Enumerable

  attr_accessor :tables, :joins, :indexes, :constraints, :sequences, :descriptions

  GEOMETRIC_TYPES = [
    'point', 'line', 'lseg', 'box', 'path', 'polygon', 'circle'
  ]

  def initialize(filenames = [])
    @tables = {}
    @joins = []
    @indexes = []
    @constraints = []
    @sequences = []
    @descriptions = []
    load *filenames
  end

  def clear_db
    @tables.clear
    @joins.clear
    @indexes.clear
    @constraints.clear
    @sequences.clear
  end

  def clear_descriptions
    @descriptions = []
  end

  def clear
    clear_db
    clear_descriptions
  end

  def each(&b)
    to_a.each(&b)
  end

  def join(*a)
    to_a.join(*a)
  end

  def to_s
    join("\n")
  end

  def load(*filenames)
    @descriptions += filenames.map{|fn| File.read(fn.to_s) }
    @descriptions.uniq!
  end

  def to_a
    @descriptions.each{|d| instance_eval d }
    create_join_tables
    create_tables + create_constraints + create_indexes + create_sequences
  end
  
  def create_join_tables
    joins.each do |from, to|
      tables["join_#{from}_#{to}"] = {
        "#{from}_id" => [[from, :id]],
        "#{to}_id" => [[to, :id]]
      }
    end
  end

  def create_tables
    tables.each do |table,columns|
      columns.each do |colname, sig|
        type = sig[0]
        options = sig[1..-1]
        index = sig.delete('index')
        if type.is_a? Array # foreign key
          type << :id if type.size < 2
          constraints << [table, :foreign_key, colname, type]
        end
        if index and not options.include? 'unique'
          indexes << [table, colname]
        end
      end
      columns[:id] = [:serial, 'primary key']
    end

    tables.sort_by{|c| c.to_s }.map do |table, columns|
      table_sql = "CREATE TABLE #{PGconn.escape table.to_s} (\n  "
      columns_sql = []
      columns.sort_by{|c| c.to_s }.each do |colname, sig|
        type = get_type sig
        options = sig[1..-1]
        columns_sql << "#{PGconn.escape colname.to_s} #{type} #{options.join(" ")}"
      end
      table_sql << columns_sql.join(",\n  ")
      table_sql << "\n);"
      table_sql
    end
  end

  def get_type sig
    type = sig[0]
    while type.is_a? Array # foreign key, collapse type
      tbl, col = type
      type = tables[tbl][col][0]
      type = :int if type.to_s == 'serial'
    end
    type.to_s
  end

  def create_constraints
    constraints.sort_by{|c| c.to_s }.map do |table, *args|
      case args[0]
      when :foreign_key
        "ALTER TABLE #{PGconn.escape table.to_s} ADD CONSTRAINT #{PGconn.escape "#{table}_fkey_#{args[1..-1].join("_")}"}\n" +
        "  FOREIGN KEY (#{PGconn.escape args[1].to_s})"+
        " REFERENCES #{PGconn.escape args[2][0].to_s}(#{PGconn.escape args[2][1].to_s});"
      when :unique
        "CREATE UNIQUE INDEX #{PGconn.escape "#{table}_unique_#{args[1].join("_")}"}\n" +
        "  ON #{PGconn.escape table.to_s}(#{args[1].map{|a| PGconn.escape a.to_s}.join(",") });"
      when String
        args[0]
      end
    end
  end

  def geometric? sig
    return false if sig.nil?
    GEOMETRIC_TYPES.include? get_type(sig)
  end

  def create_indexes
    indexes.sort_by{|c| c.to_s }.map do |table, cols, index_type|
      cols = [cols] unless cols.is_a? Array
      index_type ||= if cols.find{|col| geometric? tables[table][col] }
        "rtree"
      else
        "btree"
      end
      "CREATE INDEX #{PGconn.escape "#{table}_#{cols.join("_").gsub(/[^0-9a-z_]/i,'_')}"} ON " +
      "#{PGconn.escape table.to_s} USING #{index_type} (#{cols.map{|c| PGconn.escape c.to_s}.join(",")});"
    end
  end

  def create_sequences
    sequences.sort_by{|c| c.to_s }.map do |seqname, *args|
      "CREATE SEQUENCE #{PGconn.escape seqname.to_s} #{args.join(' ')};"
    end
  end

end # Creator


end # DB