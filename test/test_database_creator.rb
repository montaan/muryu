require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")
require 'future/database/creator'

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
      "CREATE INDEX foo_qux ON foo USING btree (qux);",
      "CREATE INDEX baz_foo ON baz USING btree (foo);"
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
    @creator.tables['foo'] = {"bar" => [['bar']]}
    @creator.tables['bar'] = {"foo" => [['foo']], "i" => ['int']}
    @creator.constraints << ['bar', :unique, ['foo', 'i']]
    foo = "CREATE TABLE foo (\n  bar int ,\n  id serial primary key\n);"
    bar = "CREATE TABLE bar (\n  foo int ,\n  id serial primary key,\n  i int \n);"
    tables = [bar, foo]
    constraints = [
      "ALTER TABLE bar ADD CONSTRAINT bar_fkey_foo_foo_id\n  FOREIGN KEY (foo) REFERENCES foo(id);",
      "CREATE UNIQUE INDEX bar_unique_foo_i\n  ON bar(foo,i);",
      "ALTER TABLE foo ADD CONSTRAINT foo_fkey_bar_bar_id\n  FOREIGN KEY (bar) REFERENCES bar(id);"
    ]
    assert_equal(@creator.to_a, (tables+constraints))
  end

  def test_index
    @creator.tables['foo'] = {:t => [:text, 'index'], :i => [:int, 'index']}
    @creator.indexes << ['foo', 'substr(t, 16)']
    assert_equal(["CREATE TABLE foo (\n  id serial primary key,\n  i int ,\n  t text \n);",
 "CREATE INDEX foo_i ON foo USING btree (i);",
 "CREATE INDEX foo_substr_t__16_ ON foo USING btree (substr(t, 16));",
 "CREATE INDEX foo_t ON foo USING btree (t);"], @creator.to_a)
  end

  def test_geometric_index
    @creator.tables['foo'] = {:p => [:point, 'index']}
    assert_equal(["CREATE TABLE foo (\n  id serial primary key,\n  p point \n);",
 "CREATE INDEX foo_p ON foo USING rtree (p);"], @creator.to_a)
  end

end
