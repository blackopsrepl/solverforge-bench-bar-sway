# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "solverforge_bench_bar"

ROOT = File.expand_path("..", __dir__)
ENTRYPOINT = File.join(ROOT, "bin", "solverforge-bench-bar")
FIXTURE = File.join(__dir__, "fixtures", "warehouse_snapshot.json")

Dir.mktmpdir("solverforge-bench-bar-smoke-") do |dir|
  timestamp = Time.now.utc.iso8601
  log_path = File.join(dir, "run.log")
  File.write(
    log_path,
    "#{timestamp} solver_start instance=smoke-instance solver=solverforge time_limit=10 watchdog=15\n"
  )

  warehouse = JSON.parse(File.read(FIXTURE))
  warehouse["queried_at"] = timestamp
  active_run = warehouse.fetch("active_runs").first
  active_run["created_at"] = timestamp
  active_run["last_result_at"] = timestamp
  active_run["repo_root"] = dir
  active_run["log_path"] = log_path
  %w[
    run_error_count watchdog_kill_count infeasible_count validation_error_count
    fair_start_failure_count wall_time_violation_count
  ].each { |key| active_run[key] = 0 }
  warehouse_path = File.join(dir, "warehouse.json")
  File.write(warehouse_path, JSON.generate(warehouse))

  fake_psql = File.join(dir, "fake-psql")
  File.write(fake_psql, <<~RUBY)
    #!/usr/bin/ruby
    print File.read(ENV.fetch("SOLVERFORGE_BENCH_BAR_SMOKE_WAREHOUSE"))
  RUBY
  File.chmod(0o700, fake_psql)

  config = SolverForgeBenchBar::Core::Config.default_config
  config[:source][:psqlCommand] = fake_psql
  config[:runtime][:stateDir] = File.join(dir, "state")
  config[:runtime][:quickShellShell] = File.join(ROOT, "frontend", "quickshell", "shell.qml")
  config_path = File.join(dir, "config.json")
  SolverForgeBenchBar::Core::Config.save_config(config, config_path)

  environment = { "SOLVERFORGE_BENCH_BAR_SMOKE_WAREHOUSE" => warehouse_path }
  _stdout, stderr, status = Open3.capture3(
    environment,
    RbConfig.ruby,
    ENTRYPOINT,
    "daemon",
    "--once",
    "--config",
    config_path
  )
  abort(stderr) unless status.success?

  snapshot_path = File.join(config[:runtime][:stateDir], "snapshot.json")
  snapshot = JSON.parse(File.read(snapshot_path))
  abort("smoke snapshot source is not healthy") unless snapshot.dig("source", "status") == "ok"
  abort("smoke run was not classified active") unless snapshot.dig("summary", "activeCount") == 1

  waybar_output, stderr, status = Open3.capture3(
    RbConfig.ruby,
    ENTRYPOINT,
    "waybar",
    "render",
    "--config",
    config_path
  )
  abort(stderr) unless status.success?

  waybar = JSON.parse(waybar_output)
  abort("smoke Waybar payload is not active") unless waybar.fetch("text") == "SFB 1"
end
