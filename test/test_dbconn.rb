require 'test/unit'

class FinalizeDB
  def self.finish
    lambda{
      DB::Conn.close
      `dropdb #{$database}`
    }
  end
end

class DBConnTest < Test::Unit::TestCase

  @@setup_done = nil

  def self.setup_db
    if not @@setup_done
      $database = 'future_test_dbconn'
      `dropdb #{$database} 2> /dev/null`
      `createdb #{$database}`
      path = File.dirname __FILE__
      `ruby #{path}/../bin/future_database_generate #{path}/data/test_dbconn | psql #{$database} 2> /dev/null`
      require "#{path}/../lib/future/database/dbconn"
      ObjectSpace.define_finalizer( self, FinalizeDB.finish )
      @@setup_done = true
    end
  end

  def setup
    self.class.setup_db
  end

  def test_create
    names = %w(anselm hameln kiefer judy)
    names.each{|name|
      assert_equal(nil, DB::Tables::A.find(:name => name))
      DB::Tables::A.create(:name => name)
      assert_equal(name, DB::Tables::A.find(:name => name).name)
    }
  end

  def test_delete
    names = %w(anselm hameln kiefer judy)
    names.each{|name|
      assert_equal(name, DB::Tables::A.find_or_create(:name => name).name)
      DB::Tables::A.delete(:name => name)
      assert_equal(nil, DB::Tables::A.find(:name => name))
    }
  end

  def test_simple_find
  end

  def test_complex_find
  end

  def test_foreign_keys
  end

  def test_reverse_foreign_keys
  end

  def test_joins
  end


end
