# frozen_string_literal: true

require_relative "test_helper"

class StateTest < Minitest::Test
  State = SolverForgeBenchBar::Runtime::State

  def test_state_files_are_private_and_ui_state_is_normalized
    Dir.mktmpdir do |dir|
      config = temp_config(dir)
      State.write_snapshot(config, { generatedAt: "2026-07-18T00:00:00Z" })
      State.write_ui_state(config, { open: 1, requestedAt: 123 })

      assert_equal 0o700, File.stat(State.state_dir(config)).mode & 0o777
      assert_equal 0o600, File.stat(State.snapshot_path(config)).mode & 0o777
      assert_equal({ open: true, requestedAt: "123" }, State.read_ui_state(config))
    end
  end

  def test_material_change_ignores_refresh_timestamps
    first = {
      generatedAt: "2026-07-18T00:00:00Z",
      source: { queriedAt: "a", lastSuccessAt: "a", latencyMs: 1, status: "ok" },
      view: { source: { queriedAt: "a", lastSuccessAt: "a", latencyMs: 1, status: "ok" } },
      runs: []
    }
    second = {
      generatedAt: "2026-07-18T00:00:02Z",
      source: { queriedAt: "b", lastSuccessAt: "b", latencyMs: 2, status: "ok" },
      view: { source: { queriedAt: "b", lastSuccessAt: "b", latencyMs: 2, status: "ok" } },
      runs: []
    }

    refute State.materially_changed?(first, second)
  end
end
