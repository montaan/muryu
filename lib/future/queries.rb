
module Future

require 'future/search/search_query'

class QueryGenerator
  DISCRETE_FIELDS = {
    "set"    => "sets.name",
    "tag"    => "tags.name",
    "user"   => "users.name",
    "group"  => "groups.name",
    "type"   => "mimetypes.major",
    "author" => "metadata.author",
  }
  RANGE_FIELDS = {
    "size"    => "size",
    "date"    => "created_at",
    "length"  => "metadata.length",
    "width"   => "metadata.width",
    "pages"   => "metadata.pages",
    "words"   => "metadata.words",
    "bitrate" => "metadata.bitrate",
    "rating"  => "metadata.rating",
  }
  NUMERIC_FIELDS = RANGE_FIELDS.values - %w[created_at]
  def initialize
    @parser = QueryStringParser.new
  end

  def query_hashes(query_string)
    ast = @parser.parse(query_string)
    qhashes = ast_to_query_hash(ast)
  end

  private

  require 'pp'
  def ast_to_query_hash(ast, hash = {})
    pp ast if $DEBUG
    case ast
    when QueryStringParser::Negation
      child = ast_to_query_hash(ast.child)
      child.each_pair do |key, val|
        case val.predicate 
        when "ALL"; raise "cannot handle comple expressions"
        when "ANY"; hash[key] = -val
        when "NOT ANY"; hash[key] = [].concat(val) # get rid of @predicate
        end
      end
    when QueryStringParser::BinaryAnd, QueryStringParser::BinaryOr
      left = ast_to_query_hash(ast.left)
      right = ast_to_query_hash(ast.right)
      intersection = left.keys & right.keys
      (left.keys - intersection).each{|key| hash[key] = left[key]}
      (right.keys - intersection).each{|key| hash[key] = right[key]}
      # handle fields in both parts of the query
      case ast
      when QueryStringParser::BinaryAnd
        ok_predicate = "ALL"
      when QueryStringParser::BinaryOr
        ok_predicate = "ANY"
      end
      intersection.each do |key|
        unless (left[key].predicate == ok_predicate || left[key].size == 1) and 
               (right[key].predicate == ok_predicate || right[key].size == 1)
          raise "cannot handle complex expressions"
        end
        merged = left[key] + right[key]
        merged = +merged if ok_predicate == "ALL" 
        hash[key] = merged
      end
    when QueryStringParser::KeyValExpr
      field = DISCRETE_FIELDS[ast.key] 
      values = linearize_discrete_values(ast.values)
      if hash.has_key?(field)
        raise "cannot handle complex expressions" unless values.predicate == hash[field].predicate
        values = hash[field].dup.concat(values)
      end
      values = values.map{|x| x.to_i} if NUMERIC_FIELDS.include?(field)
      hash.update(field => values)
    when QueryStringParser::RangeKeyValExpr
      field = RANGE_FIELDS[ast.key]
      values = linearize_range_values(ast.values)
      if hash.has_key?(field)
        raise "cannot handle complex expressions" #unless values.predicate == hash[field].predicate
      end
      if NUMERIC_FIELDS.include?(field)
        values = values.map do |x|
          case x
          when Array
            [x[0], x[1].map{|y| y.to_i}]
          else
            x.to_i
          end
        end
      end
      hash.update(field => values.flatten)
    end
    hash
  end

  def linearize_range_values(ast)
    case ast
    when QueryStringParser::BinaryAnd, QueryStringParser::BinaryOr
      linearize_discrete_values(ast)
    when QueryStringParser::Unary
      values = linearize_discrete_values(ast.child)
      [[ast.op, values]]
    else
      linearize_discrete_values(ast)
    end
  end

  def linearize_discrete_values(ast, type = nil)
    case ast
    when QueryStringParser::BinaryAnd
      raise "cannot handle complex expressions" if type && type != :and
      left = linearize_discrete_values(ast.left, :and)
      right = linearize_discrete_values(ast.right, :and)
      +([left, right].flatten)
    when QueryStringParser::BinaryOr
      raise "cannot handle complex expressions" if type && type != :or
      left = linearize_discrete_values(ast.left, :or)
      right = linearize_discrete_values(ast.right, :or)
      [left, right].flatten
    when String
      [ast]
    when QueryStringParser::Negation
      raise "cannot handle complex expressions" unless String === ast.child
      -[ast.child]
    end
  end

end

end # Future
