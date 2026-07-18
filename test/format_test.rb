# frozen_string_literal: true

require_relative "test_helper"

class FormatTest < Minitest::Test
  Format = SolverForgeBenchBar::Core::Format

  def test_current_work_tooltip_includes_elapsed_and_watchdog_timing
    line = Format.run_tooltip_line(
      {
        benchmarkLabel: "CVRP",
        observedState: "active",
        resultCount: 25,
        currentWork: {
          instance: "X-n101-k25",
          solver: "solverforge",
          timeLimitSeconds: 10,
          watchdogSeconds: 15,
          startedAt: "2026-07-18T01:10:00Z"
        }
      },
      now: Time.parse("2026-07-18T01:10:05Z")
    )

    assert_includes line, "X-n101-k25 / solverforge / 10s"
    assert_includes line, "elapsed 5s / watchdog 15s"
  end
end
