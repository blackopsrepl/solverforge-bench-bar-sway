# frozen_string_literal: true

require_relative "test_helper"

class WaybarTest < Minitest::Test
  Waybar = SolverForgeBenchBar::Runtime::Waybar

  def test_loading_payload_requires_no_live_source
    config = temp_config(Dir.tmpdir)
    payload = Waybar.payload(config, nil)

    assert_equal "SFB ...", payload[:text]
    assert_includes payload[:class], "loading"
  end

  def test_render_reads_only_cached_snapshot
    Dir.mktmpdir do |dir|
      config = temp_config(dir)
      snapshot = {
        generatedAt: Time.now.utc.iso8601,
        source: { status: "ok" },
        runs: [],
        recentRuns: [],
        summary: {},
        view: {}
      }
      SolverForgeBenchBar::Runtime::State.write_snapshot(config, snapshot)
      config_path = File.join(dir, "config.json")
      SolverForgeBenchBar::Core::Config.save_config(config, config_path)
      output = StringIO.new

      Waybar.render(config_path, out: output)
      assert_equal "SFB idle", JSON.parse(output.string).fetch("text")
    end
  end
end

