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
    @creator.tables["foo"] = {
      "bar" => ["text", "unique", "not null"],
      "qux" => ["int", "index"],
      "baz" => [["baz", :id], "not null", "unique"],
      "bat" => [["baz", "bat"]]
    }
    @creator.tables["baz"] = {
      "foo" => [["foo", :id], "not null", "index"],
      "bat" => [["bat", "name"]]
    }
    @creator.tables["bat"] = {"name" => ["text","not null","unique"]}
    foo = "CREATE TABLE foo (\n  bar text unique not null,\n  bat text ,\n  baz int not null unique,\n  id serial primary key,\n  qux int \n);"
    baz = "CREATE TABLE baz (\n  bat text ,\n  foo int not null,\n  id serial primary key\n);"
    bat = "CREATE TABLE bat (\n  id serial primary key,\n  name text not null unique\n);"
    tables = [foo,baz,bat].sort
    indexes = [
      "CREATE INDEX foo_qux ON foo(qux);",
      "CREATE INDEX baz_foo ON baz(foo);"
    ].sort
    constraints = [
      "ALTER TABLE foo ADD CONSTRAINT foo_fkey_baz_baz_id\n  FOREIGN KEY (baz) REFERENCES baz(id);",
      "ALTER TABLE foo ADD CONSTRAINT foo_fkey_bat_baz_bat\n  FOREIGN KEY (bat) REFERENCES baz(bat);",
      "ALTER TABLE baz ADD CONSTRAINT baz_fkey_foo_foo_id\n  FOREIGN KEY (foo) REFERENCES foo(id);",
      "ALTER TABLE baz ADD CONSTRAINT baz_fkey_bat_bat_name\n  FOREIGN KEY (bat) REFERENCES bat(name);"
    ].sort
    assert_equal(@creator.to_a, (tables+constraints+indexes))
  end

  def test_constraints
  end

  def test_index
  end

  def test_geometric_index
  end

end
