#!/usr/bin/env ruby
require_relative 'config/environment'

if ENV['TRACE_ADAPTER'] == '1'
  module LocalAdapterTrace
    def last_inserted_id(result)
      value = super
      puts "last_inserted_id => #{value.inspect} (#{value.class})"
      value
    end

    def returning_column_values(result)
      values = super
      puts "returning_column_values => #{values.inspect} (#{values.class})"
      values
    end
  end

  ActiveRecord::ConnectionAdapters::SQLServerAdapter.prepend(LocalAdapterTrace)
end

if ENV['LEGACY_UNWRAP'] == '1'
  module LegacyUnwrapSimulation
    def last_inserted_id(result)
      value = super
      value = value.first if value.is_a?(Array) && value.size == 1 && !value.first.is_a?(Array)
      value
    end

    def returning_column_values(result)
      values = super
      values = values.map { |v| v.is_a?(Array) && v.size == 1 ? v.first : v } if values.is_a?(Array)
      values
    end
  end

  ActiveRecord::ConnectionAdapters::SQLServerAdapter.prepend(LegacyUnwrapSimulation)
end

class TestRequest < ActiveRecord::Base
  self.table_name = 'T_Requests'
  self.primary_key = 'Id'
end

def setup_database
  conn = ActiveRecord::Base.connection

  # Create tables and trigger
  schema_sql = File.read(File.join(__dir__, 'db', 'schema.sql'))
  statements = schema_sql.split(/;\s*\n/).map(&:strip).reject(&:empty?)

  statements.each do |statement|
    conn.execute(statement)
  end

  puts "✓ Database schema created"
end

def cleanup_database
  conn = ActiveRecord::Base.connection

  conn.execute("IF OBJECT_ID('trg_RequestTouches_Workflow', 'TR') IS NOT NULL DROP TRIGGER trg_RequestTouches_Workflow")
  conn.execute("IF OBJECT_ID('T_RequestWorkflow', 'U') IS NOT NULL DROP TABLE T_RequestWorkflow")
  conn.execute("IF OBJECT_ID('T_RequestTouches', 'U') IS NOT NULL DROP TABLE T_RequestTouches")
  conn.execute("IF OBJECT_ID('T_Requests', 'U') IS NOT NULL DROP TABLE T_Requests")

  puts "✓ Database cleaned up"
end

def test_touch_type(type)
  begin
    request = TestRequest.create!
    touch = RequestTouch.create!(RequestId: request.id, TouchType: type)
    puts "✓ touch_type=#{type} SUCCESS (id=#{touch.id})"
    true
  rescue => e
    puts "✗ touch_type=#{type} FAILED: #{e.class}: #{e.message}"
    false
  end
end

# Main execution
puts "="*60
puts "SQL Server Trigger Issue Reproduction"
puts "="*60

setup_database

results = {}

puts "\nTesting touch types..."
[0, 2, 3, 8, 12, 101].each do |type|
  results[type] = test_touch_type(type)
  sleep 0.1
end

cleanup_database

puts "\n" + "="*60
puts "Summary"
puts "="*60

success_count = results.count { |_, v| v }
fail_count = results.count { |_, v| !v }

results.each do |type, success|
  status = success ? "✓ PASS" : "✗ FAIL"
  puts "touch_type #{type.to_s.rjust(3)}: #{status}"
end

puts "\nTotal: #{success_count} passed, #{fail_count} failed"

if fail_count > 0
  puts "\nNote: Types 2, 8, 12 trigger the SQL Server Workflow trigger,"
  puts "which generates an extra result set that breaks Rails 8 type casting."
end

exit fail_count > 0 ? 1 : 0
