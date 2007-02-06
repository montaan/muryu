
require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/queries'
require 'future/database/dbconn'

class TestQueryGenerator < Test::Unit::TestCase
  def setup
    @q_generator = Future::QueryGenerator.new
  end

  def test_query_hashes_basic_and
    qhash = @q_generator.query_hashes("set:foo")
    assert_equal({"sets.name" => +["foo"]}, qhash)
    assert_equal("ANY", qhash["sets.name"].predicate)

    qhash = @q_generator.query_hashes("set:foo & bar")
    assert_equal({"sets.name" => +%w[foo bar]}, qhash)
    qhash = @q_generator.query_hashes("set:foo & bar & baz")
    assert_equal({"sets.name" => +%w[foo bar baz]}, qhash)
    assert_equal("ALL", qhash["sets.name"].predicate)
  end

  def test_query_hashes_basic_negation
    qhash = @q_generator.query_hashes("!set:foo")
    assert_equal({"sets.name" => -["foo"]}, qhash)
    assert_equal("NOT ANY", qhash["sets.name"].predicate)

    qhash = @q_generator.query_hashes("set:!foo")
    assert_equal({"sets.name" => -["foo"]}, qhash)
    assert_equal("NOT ANY", qhash["sets.name"].predicate)
  end

  def xtest_query_hashes_coalesce_negation
    qhash = @q_generator.query_hashes("(!set:foo) & (!set:bar) ")
    assert_equal({"sets.name" => -%w[foo bar]}, qhash)
    assert_equal("NOT ANY", qhash["sets.name"].predicate)
  end

  def test_query_hashes_basic_or
    qhash = @q_generator.query_hashes("tag:foo")
    assert_equal({"tags.name" => ["foo"]}, qhash)
    assert_equal("ANY", qhash["tags.name"].predicate)

    qhash = @q_generator.query_hashes("tag:foo | bar")
    assert_equal({"tags.name" => %w[foo bar]}, qhash)
    assert_equal("ANY", qhash["tags.name"].predicate)

    qhash = @q_generator.query_hashes("tag:foo | bar | baz")
    assert_equal({"tags.name" => %w[foo bar baz]}, qhash)
    assert_equal("ANY", qhash["tags.name"].predicate)
  end

  def test_query_hashes_coalescing_and
    qhash = @q_generator.query_hashes("(tag:foo) & tag:bar")
    assert_equal({"tags.name" => +%w[foo bar]}, qhash)
    assert_equal("ALL", qhash["tags.name"].predicate)
  end

  def test_query_hashes_coalescing_or
    qhash = @q_generator.query_hashes("(tag:foo) | tag:bar")
    assert_equal({"tags.name" => %w[foo bar]}, qhash)
    assert_equal("ANY", qhash["tags.name"].predicate)
  end

  def test_query_hashes_coalescing_complex_and
    qhash = @q_generator.query_hashes("(tag:foo & baz) & tag:bar")
    assert_equal({"tags.name" => +%w[foo baz bar]}, qhash)
    assert_equal("ALL", qhash["tags.name"].predicate)
  end

  def test_query_hashes_coalescing_complex_or
    qhash = @q_generator.query_hashes("(tag:foo | baz)  | tag:bar")
    assert_equal({"tags.name" => %w[foo baz bar]}, qhash)
    assert_equal("ANY", qhash["tags.name"].predicate)
  end

  def test_query_hashes_complex_coalescing_disallowed
    assert_raise(RuntimeError){ @q_generator.query_hashes("(tag:foo | bar) & tag:baz") }
    assert_raise(RuntimeError){ @q_generator.query_hashes("(tag:foo & bar) | tag:baz") }
  end

  def test_query_hashes_coalescing_multiple_fields_and
    qhash = @q_generator.query_hashes("(tag:foo) & (set:foo) & (tag:bar) & set:bar ")
    assert_equal({"tags.name" => %w[foo bar], "sets.name" => %w[foo bar]}, qhash)
    assert_equal("ALL", qhash["tags.name"].predicate)
    assert_equal("ALL", qhash["sets.name"].predicate)
  end

  def test_query_hashes_coalescing_multiple_fields_or
    qhash = @q_generator.query_hashes("(tag:foo) | (set:foo) | (tag:bar) | set:bar ")
    assert_equal({"tags.name" => %w[foo bar], "sets.name" => %w[foo bar]}, qhash)
    assert_equal("ANY", qhash["tags.name"].predicate)
    assert_equal("ANY", qhash["sets.name"].predicate)
  end

  def test_query_hashes_multiple_discrete_fields
    assert_equal({"sets.name" => +["foo"], "tags.name" => ["bar"]}, 
                 @q_generator.query_hashes("(set:foo) & tag:bar"))
  end

  def test_query_hashes_range_field_simple
    qhash = @q_generator.query_hashes("size:1000")
    assert_equal({"size" => [1000]}, qhash)
  end

  def test_query_hashes_range_field_range_op
    qhash = @q_generator.query_hashes("size:>1000")
    assert_equal({"size" => [">", 1000]}, qhash)
    qhash = @q_generator.query_hashes("size:<1000")
    assert_equal({"size" => ["<", 1000]}, qhash)
  end

  def test_query_hashes_range_field_multiple
    qhash = @q_generator.query_hashes("(size:>1000) & pages:>100")
    assert_equal({"size" => [">", 1000], "metadata.pages" => [">", 100]}, qhash)
  end

  def xtest_query_hashes_range_coalescing
    qhash = @q_generator.query_hashes("(size:>1000) & size:>10000")
    assert_equal({"size" => [">", 1000, 10000]}, qhash)
  end
end
