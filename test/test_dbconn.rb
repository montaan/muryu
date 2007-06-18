require 'test/unit'
require File.join(File.dirname(__FILE__), "set_include_path.rb")

require 'future/config'
require "future/database/creator"
require "future/database/dbconn"

class FinalizeDB
  def self.finish
    lambda{
      DB::Conn.close
      `dropdb #{$database}`
    }
  end
end
=begin
why is this not worksing?
class DBConnTest < Test::Unit::TestCase

  @@setup_done = nil

  def self.setup_db
    if not @@setup_done
      $database = 'future_test_dbconn'
      `dropdb #{$database} 2> /dev/null`
      `createdb #{$database}`
      path = File.dirname __FILE__
      c = DB::Creator.new Dir["#{path}/data/test_dbconn/*.rb"]
      conf = Future.database_configuration
      DB.establish_connection(conf.merge(:database => $database))
      begin
        stderr = STDERR.clone
        STDERR.reopen("/dev/null")
        DB::Conn.exec c.to_sql
      ensure
        STDERR.reopen(stderr)
      end
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

  def test_complex_find
    create_company
    assert_equal(['Bob', 'Alice'].sort,
                 @emp.find_all(:salary => [:<=, 10000]).
                 map{|e| e.first_name}.sort
                 )
    assert_equal(['Lucy', 'Thomas'].sort,
                 @emp.find_all(:salary => [:>, 10000]).
                 map{|e| e.first_name}.sort
                 )
    assert_equal(['Lucy'],
                 @emp.find_all(:starting_date => [:<=, '2003-01-01']).
                 map{|e| e.first_name}.sort
                 )
    assert_equal('Thomas',
                 @dcs.find("department.name" => 'office supplies').employee.first_name
                 )
    assert_equal(
      @emp.find_all("last_name" => /bennett/i, :order_by => [['first_name', :asc]]),
      @emp.find_all("department.name" => "accounting", :order_by => 'first_name')
    )
    assert_equal(
      @emp.find_all(
        "last_name" => /bennett/i,
        :order_by => [['first_name', :asc]],
        :limit => 1, :offset => 0
      ),
      @emp.find_all('first_name' => /bob/i)
    )
    assert_equal(
      @emp.find_all(
        "last_name" => /bennett/i,
        :order_by => [['first_name', :asc]],
        :limit => 1, :offset => 1
      ),
      @emp.find_all('first_name' => /lucy/i)
    )
    assert_equal(
      ['Alice', 'Lucy', 'Bob', 'Thomas'],
      @emp.find_all(:order_by => [['last_name', :asc], ['salary', :desc]]).
      map{|e| e.first_name}
    )
    assert_equal(
      ['Alice', 'Bob', 'Lucy', 'Thomas'],
      @emp.find_all(:order_by => [['last_name', :asc], ['salary', :asc]]).
      map{|e| e.first_name}
    )
  end

  def test_changes
    create_company
    @emp.find_all(:salary => [:<=, 10000]).each{|e|
      e.salary *= 1.2
    }
    assert_equal(12000, @emp.find(:first_name => 'Bob').salary)
  end

  def create_company
    @dcs = DB::Tables::DepartmentChiefs
    @emp = DB::Tables::Employees
    @dep = DB::Tables::Departments
    DB::Tables::DepartmentChiefs.delete_all
    DB::Tables::Employees.delete_all
    DB::Tables::Departments.delete_all
    deps = [
      'accounting', 'r&d', 'office supplies'
    ]
    deps.map!{|d| DB::Tables::Departments.create(:name => d) }
    employees = [
      ['Bob', 'Bennett', 10000, Time.parse('2003-10-08'), deps[0]],
      ['Lucy', 'Bennett', 12000, Time.parse('2002-07-12'), deps[0]],
      ['Alice', 'Ashcroft', 9000, '2005-04-20', deps[1]],
      ['Thomas', 'Thompson', 11000, Time.parse('2004-08-04'), deps[2]]
    ]
    employees.each do |f,l,s,sd,d|
      DB::Tables::Employees.create(:first_name => f,
                                   :last_name => l,
                                   :salary => s,
                                   :starting_date => sd,
                                   :department => d
                                  )
    end
    @dcs.create(:department => deps[0], :employee => @emp.find(:first_name => 'Lucy'))
    @dcs.create(:department => deps[2], :employee => @emp.find(:first_name => 'Thomas'))
  end

  def test_foreign_keys
    create_company
    assert_equal('accounting', @emp.find(:first_name => 'Lucy').department.name)
  end

  def test_reverse_foreign_keys
    create_company
    lucy = @emp.find(:first_name => 'Lucy')
    lucys_department = lucy.departments[0]
    assert_equal(['Bob', 'Lucy'], lucys_department.employees.map{|e| e.first_name}.sort)
  end

  def test_joins
    create_company
    lucy = @emp.find(:first_name => 'Lucy')
    assert_equal(['accounting'], lucy.names)
  end

  def test_transaction
    create_company
    c = PGconn.new(nil,nil,nil,nil,$database)
    orig_salary = @emp.find(:first_name => 'Lucy').salary
    DB.transaction do
      @emp.find(:first_name => 'Lucy').salary = 1000
      assert_equal(
        orig_salary,
        c.query("select salary from employees where first_name = 'Lucy'").to_s.to_i
      )
    end
    assert_equal(1000, @emp.find(:first_name => 'Lucy').salary)
    assert_equal(
      1000,
      c.query("select salary from employees where first_name = 'Lucy'").to_s.to_i
    )
    DB.transaction do
      @emp.find(:first_name => 'Lucy').salary = 12000
      DB.rollback
    end
    assert_equal(1000, @emp.find(:first_name => 'Lucy').salary)
    assert_equal(
      1000,
      c.query("select salary from employees where first_name = 'Lucy'").to_s.to_i
    )
    c.close
  end

  def test_foreign_key_find
    create_company
    lucy = @emp.find(:first_name => 'Lucy')
    assert_equal(lucy, @dcs.find(:employee => lucy).employee)
    assert_equal(lucy, @dcs.find(:employee_id => lucy).employee)
  end


end
=end
