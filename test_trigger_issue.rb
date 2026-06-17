#!/usr/bin/env ruby
require_relative 'config/environment'
require 'factory_bot'

# Setup FactoryBot
FactoryBot.define do
  factory :request do
    class RequestRecord < ApplicationRecord
      self.table_name = 'T_Requests'
    end
    
    sequence(:id) { |n| n }
  end

  factory :request_touch do
    association :request
    touch_type { 0 }

    class RequestTouch < ApplicationRecord
      self.table_name = 'T_RequestTouches'
      belongs_to :request, foreign_key: 'RequestId', class_name: '::RequestRecord'
    end
  end
end

# Patch FactoryBot to use correct associations
class RequestRecord < ApplicationRecord
  self.table_name = 'T_Requests'
  has_many :touches, foreign_key: 'RequestId', class_name: 'RequestTouch'
end

FactoryBot.define do
  factory :request_touch do
    touch_type { 0 }
    
    before(:create) do |touch|
      touch.request_id = create(:request_record).id
    end
  end

  factory :request_record do
  end
end

def setup_database
  conn = ActiveRecord::Base.connection
  
  # Create tables and trigger
  schema_sql = File.read(File.join(__dir__, 'db', 'schema.sql'))
  schema_sql.split(/;[\n]/).each do |statement|
    conn.execute(statement) unless statement.strip.empty?
  end
  
  puts "✓ Database schema created"
end

def cleanup_database
  conn = ActiveRecord::Base.connection
  
  ['trg_RequestTouches_Workflow', 'T_RequestWorkflow', 'T_RequestTouches', 'T_Requests'].each do |obj|
    conn.execute("DROP TABLE #{obj}") if conn.tables.include?(obj) || obj.start_with?('trg')
  rescue => e
    # Ignore if doesn't exist
  end
  
  puts "✓ Database cleaned up"
end

def test_touch_type(type)
  begin
    request = RequestRecord.create!
    touch = RequestTouch.create!(request_id: request.id, touch_type: type)
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
