# frozen_string_literal: true

require_relative "test_helper"

class PresenterTest < Minitest::Test
  Presenter = SolverForgeBenchBar::Runtime::Presenter

  def test_chip_reports_active_and_attention_rows
    config = temp_config(Dir.tmpdir)
    active = SolverForgeBenchBar::Core::RunState.normalize_active(
      active_run,
      active_evidence,
      config,
      now: Time.parse("2026-07-18T01:10:05Z")
    )
    drift = active.merge(
      id: "other",
      observedState: "terminal-drift",
      severity: "info",
      createdAt: "2026-07-17T01:00:00Z"
    )
    recent = SolverForgeBenchBar::Core::RunState.normalize_recent(
      id: "recent",
      benchmarkName: "employee-scheduling",
      benchmarkCategory: "scalar_variable",
      runKind: "candidate",
      nightly: true,
      warehouseStatus: "completed",
      createdAt: "2026-07-18T01:00:01Z",
      completedAt: "2026-07-18T04:00:00Z",
      resultCount: 504,
      solvers: %w[solverforge solverforge-py],
      timeLimitsSeconds: [1, 10],
      failureError: ""
    )
    snapshot = {
      generatedAt: "2026-07-18T01:10:05Z",
      source: { status: "ok" },
      runs: [active, drift],
      cohortRuns: [recent],
      recentRuns: [recent]
    }

    presented = Presenter.apply(snapshot, config)
    assert_equal "SFB 1", presented.dig(:view, :chip, :text)
    assert_equal 1, presented.dig(:summary, :activeCount)
    assert_equal 1, presented.dig(:summary, :warehouseDriftCount)
    assert_equal 1, presented.dig(:summary, :operationalCandidateCount)
    assert_equal 2, presented.dig(:summary, :cohortSuiteCount)
    assert_equal "active", presented[:status]
    assert_equal 8, presented.dig(:view, :staleAfterSeconds)
    assert_equal "active", presented.dig(:view, :monitorRuns, 0, :observedState)
    assert_equal 1, presented.dig(:view, :monitorRuns).length
    assert_equal "terminal-drift", presented.dig(:view, :warehouseDriftRuns, 0, :observedState)
    refute_includes presented.dig(:view, :chip, :classes), "has-attention"
    assert_includes presented.dig(:view, :chip, :tooltipLines), "1 stale warehouse row excluded from live monitor"
  end

  def test_active_run_with_result_failures_is_also_attention_without_duplicate_monitor_row
    config = temp_config(Dir.tmpdir)
    counters = SolverForgeBenchBar::Core::RunState.empty_counters.merge(runErrors: 2)
    active_with_issues = SolverForgeBenchBar::Core::RunState.normalize_active(
      active_run(counters: counters),
      active_evidence,
      config,
      now: Time.parse("2026-07-18T01:10:05Z")
    )
    snapshot = {
      generatedAt: "2026-07-18T01:10:05Z",
      source: { status: "ok" },
      runs: [active_with_issues],
      cohortRuns: [],
      recentRuns: []
    }

    presented = Presenter.apply(snapshot, config, now: Time.parse("2026-07-18T01:10:05Z"))

    assert_equal "SFB 1 !1", presented.dig(:view, :chip, :text)
    assert_equal "warning", presented[:status]
    assert_equal 1, presented.dig(:summary, :activeCount)
    assert_equal 1, presented.dig(:summary, :attentionRunCount)
    assert_equal [active_with_issues[:id]], presented.dig(:view, :activeRuns).map { |run| run[:id] }
    assert_equal [active_with_issues[:id]], presented.dig(:view, :attentionRuns).map { |run| run[:id] }
    assert_equal [active_with_issues[:id]], presented.dig(:view, :monitorRuns).map { |run| run[:id] }
    assert_includes presented.dig(:view, :chip, :classes), "has-attention"
  end

  def test_current_cohort_uses_independent_cohort_rows_not_generic_recent_rows
    config = temp_config(Dir.tmpdir)
    active = SolverForgeBenchBar::Core::RunState.normalize_active(
      active_run,
      active_evidence,
      config,
      now: Time.parse("2026-07-18T01:10:05Z")
    )
    completed = SolverForgeBenchBar::Core::RunState.normalize_recent(
      id: "employee",
      benchmarkName: "employee-scheduling",
      benchmarkCategory: "scalar_variable",
      runKind: "candidate",
      nightly: true,
      warehouseStatus: "completed",
      createdAt: "2026-07-18T01:00:01Z",
      completedAt: "2026-07-18T04:00:00Z",
      resultCount: 10,
      solvers: ["solverforge"],
      timeLimitsSeconds: [10],
      failureError: ""
    )
    failed = completed.merge(
      id: "job-shop",
      benchmarkName: "job-shop-scheduling",
      benchmarkLabel: "Job-shop scheduling",
      warehouseStatus: "failed",
      observedState: "failed",
      severity: "critical",
      createdAt: "2026-07-18T01:00:02Z"
    )
    newer_non_nightly = failed.merge(id: "manual", nightly: false, createdAt: "2026-07-18T02:00:00Z")
    snapshot = {
      source: { status: "ok" },
      runs: [active],
      cohortRuns: [completed, failed],
      recentRuns: [newer_non_nightly]
    }

    cohort = Presenter.apply(snapshot, config).dig(:view, :currentCohort)

    assert_equal %w[cvrp employee-scheduling job-shop-scheduling], cohort[:runs].map { |run| run[:benchmarkName] }
    assert_equal 3, cohort[:runs].length
    assert_equal 1, cohort[:activeCount]
    assert_equal 1, cohort[:completedCount]
    assert_equal 1, cohort[:failedCount]
  end

  def test_terminal_drift_alone_leaves_monitor_idle
    config = temp_config(Dir.tmpdir)
    drift = SolverForgeBenchBar::Core::RunState.normalize_active(
      active_run,
      active_evidence(currentWork: nil, terminalEvent: "failed", terminalMessage: "connection closed"),
      config,
      now: Time.parse("2026-07-18T01:10:05Z")
    )
    snapshot = {
      generatedAt: "2026-07-18T01:10:05Z",
      source: { status: "ok" },
      runs: [drift],
      cohortRuns: [],
      recentRuns: []
    }

    presented = Presenter.apply(snapshot, config)

    assert_equal "info", drift[:severity]
    assert_equal "idle", presented[:status]
    assert_equal "SFB idle", presented.dig(:view, :chip, :text)
    assert_empty presented.dig(:view, :monitorRuns)
    assert_equal 1, presented.dig(:summary, :warehouseDriftCount)
  end

  def test_source_error_without_data_renders_error_chip
    config = temp_config(Dir.tmpdir)
    snapshot = { generatedAt: Time.now.utc.iso8601, source: { status: "error", error: "offline" }, runs: [], recentRuns: [] }

    assert_equal "SFB err", Presenter.apply(snapshot, config).dig(:view, :chip, :text)
  end
end
