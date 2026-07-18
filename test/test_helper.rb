# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "solverforge_bench_bar"

module TestSupport
  FIXTURE_DIR = File.expand_path("fixtures", __dir__)

  def fixture(name)
    File.read(File.join(FIXTURE_DIR, name))
  end

  def temp_config(root)
    config = SolverForgeBenchBar::Core::Config.default_config
    config[:runtime][:stateDir] = File.join(root, "state")
    config[:runtime][:quickShellShell] = File.join(root, "shell.qml")
    SolverForgeBenchBar::Core::Config.normalize_config(config)
  end

  def active_run(overrides = {})
    base = {
      id: "11111111-2222-3333-4444-555555555555",
      benchmarkName: "cvrp",
      benchmarkCategory: "list_variable",
      runKind: "candidate",
      nightly: true,
      warehouseStatus: "running",
      createdAt: "2026-07-18T01:00:00Z",
      completedAt: nil,
      resultCount: 25,
      solvers: %w[solverforge solverforge-py],
      timeLimitsSeconds: [1, 10],
      repoRoot: "/tmp/repo",
      logPath: "/tmp/repo/run.log",
      gitCommit: "abc123",
      gitDirty: false,
      metadata: { watchdog_multiplier: 1.25, watchdog_grace_seconds: 5.0 },
      lastResult: {
        rowIndex: 25,
        createdAt: "2026-07-18T01:09:50Z",
        instance: "X-n101-k25",
        solver: "solverforge-py",
        timeLimitSeconds: 10,
        actualTimeSeconds: 10.1,
        watchdogKilled: false,
        runError: "",
        hardFeasible: true
      },
      counters: SolverForgeBenchBar::Core::RunState.empty_counters,
      perSolver: {}
    }
    base.merge(overrides)
  end

  def active_evidence(overrides = {})
    base = {
      status: "ok",
      fileMtime: "2026-07-18T01:10:00Z",
      lastEventAt: "2026-07-18T01:10:00Z",
      currentWork: {
        instance: "X-n101-k25",
        solver: "solverforge",
        timeLimitSeconds: 10,
        watchdogSeconds: 15.0,
        startedAt: "2026-07-18T01:10:00Z"
      },
      terminalEvent: nil,
      terminalAt: nil,
      terminalMessage: nil,
      tailTruncated: false,
      error: nil
    }
    base.merge(overrides)
  end
end

class Minitest::Test
  include TestSupport
end

