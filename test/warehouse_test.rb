# frozen_string_literal: true

require_relative "test_helper"

class WarehouseTest < Minitest::Test
  Warehouse = SolverForgeBenchBar::Core::Warehouse

  def test_parses_and_normalizes_snapshot
    payload = Warehouse.parse_payload(fixture("warehouse_snapshot.json"), latency_ms: 12)
    run = payload[:activeRuns].first
    cohort = payload[:cohortRuns]
    recent = payload[:recentRuns].first

    assert_equal 12, payload[:latencyMs]
    assert_equal "cvrp", run[:benchmarkName]
    assert_equal 2287, run[:resultCount]
    assert_equal 95, run.dig(:counters, :runErrors)
    assert_equal %w[employee-scheduling job-shop-scheduling], cohort.map { |row| row[:benchmarkName] }
    refute_includes recent[:failureError], "secret:password"
    assert_includes recent[:failureError], "<redacted-database-url>"
  end


  def test_snapshot_query_fetches_bounded_cohort_independently_of_recent_limit
    sql = Warehouse.snapshot_query(active_limit: 16, recent_limit: 1, cohort_window_seconds: 120)

    assert_includes sql, "cohort_rows AS"
    assert_includes sql, "LIMIT #{Warehouse::NIGHTLY_COHORT_LIMIT}"
    assert_includes sql, "LIMIT 1"
    assert_includes sql, "'cohort_runs'"
    assert_operator sql.index("cohort_rows AS"), :<, sql.index("recent_rows AS")
  end

  def test_psql_environment_forces_read_only_and_decomposes_url
    config = SolverForgeBenchBar::Core::Config.normalize_config(SolverForgeBenchBar::Core::Config.default_config)
    env = Warehouse.psql_environment(config)

    assert_includes env.fetch("PGOPTIONS"), "default_transaction_read_only=on"
    assert_includes env.fetch("PGOPTIONS"), "statement_timeout=2000"
    assert_equal "localhost", env.fetch("PGHOST")
    assert_equal "postgres", env.fetch("PGUSER")
    assert_equal "solverforge_bench", env.fetch("PGDATABASE")
    refute env.values.include?(SolverForgeBenchBar::Core::Config::DEFAULT_DATABASE_URL)
  end

  def test_psql_environment_decodes_credentials_and_ssl_mode
    config = SolverForgeBenchBar::Core::Config.default_config
    config[:source][:databaseUrl] = "postgresql://bench%2Duser:p%40ss@db.example:5544/nightly%2Dbench?sslmode=require"
    env = Warehouse.psql_environment(config)

    assert_equal "bench-user", env.fetch("PGUSER")
    assert_equal "p@ss", env.fetch("PGPASSWORD")
    assert_equal "db.example", env.fetch("PGHOST")
    assert_equal "5544", env.fetch("PGPORT")
    assert_equal "nightly-bench", env.fetch("PGDATABASE")
    assert_equal "require", env.fetch("PGSSLMODE")
  end

  def test_connection_environment_preserves_plus_signs
    env = Warehouse.connection_environment("postgresql://bench:p+ss@db.example/db+name")

    assert_equal "p+ss", env.fetch("PGPASSWORD")
    assert_equal "db+name", env.fetch("PGDATABASE")
  end

  def test_connection_environment_unbrackets_ipv6_host
    env = Warehouse.connection_environment("postgresql://bench@[::1]/bench")

    assert_equal "::1", env.fetch("PGHOST")
  end

  def test_rejects_non_postgresql_connection_string
    error = assert_raises(Warehouse::SourceError) do
      Warehouse.connection_environment("solverforge_bench")
    end

    assert_equal "source.databaseUrl must be a PostgreSQL URL", error.message
  end

  def test_fetch_uses_fake_psql_without_live_database
    Dir.mktmpdir do |dir|
      fake = File.join(dir, "fake-psql")
      File.write(fake, "#!/bin/sh\n/usr/bin/printf '%s' \"$FAKE_WAREHOUSE_JSON\"\n")
      File.chmod(0o755, fake)
      config = temp_config(dir)
      config[:source][:psqlCommand] = fake
      ENV["FAKE_WAREHOUSE_JSON"] = fixture("warehouse_snapshot.json")

      payload = Warehouse.fetch(config)
      assert_equal 1, payload[:activeRuns].length
    ensure
      ENV.delete("FAKE_WAREHOUSE_JSON")
    end
  end
end
