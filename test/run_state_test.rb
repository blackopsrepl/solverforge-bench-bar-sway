# frozen_string_literal: true

require_relative "test_helper"

class RunStateTest < Minitest::Test
  RunState = SolverForgeBenchBar::Core::RunState

  def setup
    @config = temp_config(Dir.tmpdir)
  end

  def test_active_run_has_exact_matrix_position
    state = RunState.normalize_active(
      active_run,
      active_evidence,
      @config,
      now: Time.parse("2026-07-18T01:10:05Z")
    )

    assert_equal "active", state[:observedState]
    assert_equal 4, state[:matrixWidth]
    assert_equal 6, state[:completedCases]
    assert_equal 1, state[:trialInCase]
    assert_equal "2026-07-18T01:10:15Z", state.dig(:currentWork, :deadlineAt)
  end

  def test_current_work_becomes_stalled_after_watchdog_and_grace
    state = RunState.normalize_active(
      active_run,
      active_evidence,
      @config,
      now: Time.parse("2026-07-18T01:11:00Z")
    )

    assert_equal "stalled", state[:observedState]
    assert_equal "warning", state[:severity]
  end

  def test_terminal_log_conflict_is_explicit
    evidence = active_evidence(
      currentWork: nil,
      terminalEvent: "failed",
      terminalAt: "2026-07-18T01:10:01Z",
      terminalMessage: "connection closed"
    )
    state = RunState.normalize_active(active_run, evidence, @config, now: Time.parse("2026-07-18T01:10:02Z"))

    assert_equal "running", state[:warehouseStatus]
    assert_equal "terminal-drift", state[:observedState]
    assert_equal "info", state[:severity]
  end

  def test_fresh_warehouse_progress_is_active_when_log_is_unavailable
    evidence = active_evidence(
      status: "missing",
      lastEventAt: nil,
      currentWork: nil,
      error: "run log is missing"
    )
    state = RunState.normalize_active(
      active_run,
      evidence,
      @config,
      now: Time.parse("2026-07-18T01:10:00Z")
    )

    assert_equal "active", state[:observedState]
  end

  def test_stale_warehouse_progress_remains_unknown_without_safe_log
    evidence = active_evidence(
      status: "unsafe",
      lastEventAt: nil,
      currentWork: nil,
      error: "run log is unsafe"
    )
    run = active_run(
      createdAt: "2026-07-18T01:00:00Z",
      lastResult: active_run[:lastResult].merge(createdAt: "2026-07-18T01:00:10Z")
    )
    state = RunState.normalize_active(
      run,
      evidence,
      @config,
      now: Time.parse("2026-07-18T01:10:00Z")
    )

    assert_equal "unknown", state[:observedState]
  end
end
