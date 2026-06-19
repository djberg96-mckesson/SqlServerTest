#!/usr/bin/env ruby

# Instructions:
# docker compose up -d sqlserver
# bundle install
# bundle exec ruby simple_trigger_repro.rb
require_relative "config/environment"

class ReproRequest < ActiveRecord::Base
  self.table_name = "T_Requests"
  self.primary_key = "Id"
end

class ReproRequestTouch < ActiveRecord::Base
  self.table_name = "T_RequestTouches"
  self.primary_key = "Id"
end

conn = ActiveRecord::Base.connection
schema_sql = File.read(File.join(__dir__, "db", "schema.sql"))

# Execute the schema script so the trigger exists for this one-off repro.
schema_sql.split(/;\s*\n/).map(&:strip).reject(&:empty?).each do |statement|
  conn.execute(statement)
end

puts "Creating request..."
request = ReproRequest.create!

puts "Creating trigger-causing touch (TouchType=2)..."
# On Rails 8 + activerecord-sqlserver-adapter 8.0.10 this line raises:
# NoMethodError: undefined method `to_i' for an instance of Array
ReproRequestTouch.create!(RequestId: request.id, TouchType: 2)

puts "Unexpected: insert succeeded (issue did not reproduce)."
