# frozen_string_literal: true

require_relative "test_helper"

class CLITest < Minitest::Test
  def test_daemon_once_fails_when_source_observation_fails
    Dir.mktmpdir do |dir|
      config = temp_config(dir)
      config[:source][:psqlCommand] = File.join(dir, "missing-psql")
      config_path = File.join(dir, "config.json")
      SolverForgeBenchBar::Core::Config.save_config(config, config_path)

      _stdout, stderr = capture_io do
        assert_equal 1, SolverForgeBenchBar::CLI.run(["daemon", "--once", "--config", config_path])
      end
      snapshot = SolverForgeBenchBar::Runtime::State.read_snapshot(config)

      assert_equal "error", snapshot.dig(:source, :status)
      assert_includes stderr, "Source check failed:"
      assert_includes snapshot.dig(:source, :error), "<redacted-path>"
      refute_includes snapshot.dig(:source, :error), dir
    end
  end


  def test_misspelled_option_fails_without_starting_daemon
    daemon_called = false
    _stdout, stderr = capture_io do
      SolverForgeBenchBar::Runtime::Daemon.stub(:run, ->(*) { daemon_called = true }) do
        assert_equal 1, SolverForgeBenchBar::CLI.run(["daemon", "--onc"])
      end
    end

    refute daemon_called
    assert_includes stderr, "Unknown option: --onc"
  end

  def test_command_help_does_not_start_daemon
    daemon_called = false
    stdout, stderr = capture_io do
      SolverForgeBenchBar::Runtime::Daemon.stub(:run, ->(*) { daemon_called = true }) do
        assert_equal 0, SolverForgeBenchBar::CLI.run(["daemon", "--help"])
      end
    end

    refute daemon_called
    assert_empty stderr
    assert_includes stdout, "solverforge-bench-bar commands:"
  end

  def test_operational_command_rejects_invalid_config_before_refresh
    Dir.mktmpdir do |dir|
      config = SolverForgeBenchBar::Core::Config.default_config
      config[:runtime][:refreshSeconds] = 0
      config_path = File.join(dir, "config.json")
      File.write(config_path, JSON.generate(config))
      warehouse_called = false

      _stdout, stderr = capture_io do
        SolverForgeBenchBar::Core::Warehouse.stub(:fetch, ->(*) { warehouse_called = true }) do
          assert_equal 1, SolverForgeBenchBar::CLI.run(["refresh", "--config", config_path])
        end
      end

      refute warehouse_called
      assert_includes stderr, "runtime.refreshSeconds must be at least 1"
    end
  end
end
