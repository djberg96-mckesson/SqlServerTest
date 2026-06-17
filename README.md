# SQL Server Trigger Issue - Standalone Test

This is a minimal standalone Rails 8 project to reproduce the SQL Server adapter bug with triggers.

## Setup

1. Start SQL Server:
```bash
docker compose up -d sqlserver
```

On Apple Silicon (M1/M2/M3), this stack intentionally runs SQL Server under amd64 emulation.

Wait for the container to be healthy (check `docker compose logs sqlserver`).

2. Install dependencies:
```bash
bundle install
```

3. Run the test:
```bash
bundle exec ruby test_trigger_issue.rb
```

## What it tests

The test creates `RequestTouch` records with different `touch_type` values:
- **Type 0** (view): No trigger fires → **Should succeed**
- **Type 2** (shared): Workflow trigger fires → **Will fail with Rails 8**
- **Type 8** (workflow_triggered): Workflow trigger fires → **Will fail with Rails 8**
- **Type 12**: Workflow trigger fires → **Will fail with Rails 8**
- **Type 3, 101**: No trigger fires → **Should succeed**

## Expected output (with bug)

```
touch_type   0: ✓ PASS
touch_type   2: ✗ FAIL: NoMethodError: undefined method `to_i' for an instance of Array
touch_type   3: ✓ PASS
touch_type   8: ✗ FAIL: NoMethodError: undefined method `to_i' for an instance of Array
touch_type  12: ✗ FAIL: NoMethodError: undefined method `to_i' for an instance of Array
touch_type 101: ✓ PASS

Total: 3 passed, 3 failed
```

## Why it happens

When a SQL Server trigger fires on INSERT, it generates an extra result set. The activerecord-sqlserver-adapter's `last_inserted_id` method reads from the first row of results, which is the trigger's rows-affected count instead of SCOPE_IDENTITY().

Rails 8 has stricter type casting that calls `.to_i()` on the value. When the adapter returns an array `[1]` instead of an integer, this fails.

## Workaround

Add to `config/initializers/sql_server_adapter.rb`:

```ruby
module SQLServerAdapterPatch
  def last_inserted_id(result)
    value = super
    # Unwrap array-wrapped values from trigger result sets
    value = value.first if value.is_a?(Array) && value.size == 1 && !value.first.is_a?(Array)
    value
  end

  def returning_column_values(result)
    values = super
    # Unwrap array-wrapped rows from trigger result sets
    values = values.map { |v| v.is_a?(Array) && v.size == 1 ? v.first : v } if values.is_a?(Array)
    values
  end
end

ActiveRecord::ConnectionAdapters::SQLServerAdapter.prepend(SQLServerAdapterPatch)
```

## GitHub Issue

This is a real bug in activerecord-sqlserver-adapter 8.0.10. See:
https://github.com/rails-sqlserver/activerecord-sqlserver-adapter/issues

## Cleanup

```bash
docker compose down -v
```
