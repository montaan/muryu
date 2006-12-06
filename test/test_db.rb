require 'test/unit'
require File.dirname(__FILE__) + '/../lib/future/database/creator.rb'

class CreatorTest < Test::Unit::TestCase

  def setup
    @creator = DB::Creator.new
  end

  def test_create_table_simple
    @creator.tables["foo"] = {
      "bar" => ["text", "unique", "not null"],
      "qux" => ["int"]
    }
    assert_equal(@creator.to_s, "CREATE TABLE foo (\n  bar text unique not null,\n  id serial primary key,\n  qux int \n);")
  end

  def test_create_table_complex
  end

  def test_constraints
  end

  def test_index
  end

  def test_geometric_index
  end

end
