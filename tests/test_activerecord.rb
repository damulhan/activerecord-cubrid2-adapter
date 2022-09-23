require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'activerecord-cubrid2-adapter'

require 'benchmark'
require 'test/unit'

TABLE_NAME = 'cubrid_tests'

class CubridTest < ActiveRecord::Base
  self.table_name = TABLE_NAME
end

class CUBRID_ActiveRecordTest < Test::Unit::TestCase
  def setup
    puts '### setup '
    puts "-- activerecord-cubrid2-adapter version: #{ActiveRecord::ConnectionAdapters::Cubrid2::VERSION}"

    adapter = ActiveRecord::Base.establish_connection(
      adapter: 'cubrid2',
      host: 'localhost',
      username: 'dba',
      password: '',
      database: 'testdb'
    )

    @con = adapter.connection

    puts "-- cubrid server version: #{@con.server_version}"

    ActiveRecord::Base.connection.drop_table TABLE_NAME if ActiveRecord::Base.connection.table_exists?(TABLE_NAME)

    ActiveRecord::Base.connection.create_table TABLE_NAME do |t|
      t.string  :name
      t.text    :body
      t.timestamps
    end

    exists = ActiveRecord::Base.connection.table_exists?(TABLE_NAME)
    assert(exists, 'Table not found')
  end

  def teardown
    puts '### teardown '

    @con.close
  end

  def test_insert
    puts '### test_insert'

    cnt = CubridTest.count

    p = CubridTest.new
    p.name = 'test11'
    p.save!

    test1 = CubridTest.create!(name: 'test1', body: 'test1')
    puts "inserted id: #{test1.id}"

    test2 = CubridTest.create!(name: 'test2', body: 'test2')
    puts "inserted id: #{test2.id}"

    test3 = CubridTest.create!(name: 'test3', body: 'test3')
    puts "inserted id: #{test3.id}"

    assert(CubridTest.count == (cnt + 4), 'Table row count mismatch')

    CubridTest.destroy_all

    assert(CubridTest.count == 0, 'Table row count mismatch')    
  end

  def test_benchmark_insert
    puts '### test_benchmark_insert'

    @max_insert = 100

    count1 = CubridTest.count

    Benchmark.bm do |x|
      x.report do
        (1..@max_insert).each do |i|
          puts "#{i}th test"
          p = CubridTest.new
          p.name = 'test11'
          p.save!
          puts "inserted id: #{p.id}"
        end
      end
    end

    count2 = CubridTest.count
    inserted_count = (count2 - count1)

    puts "### #{inserted_count} rows inserted"
    assert(inserted_count == @max_insert, 'inserted rows mismatch!')
  end
end
