# frozen_string_literal: true

require_relative "test_helper"

class DaemonTest < Minitest::Test
  Daemon = SolverForgeBenchBar::Runtime::Daemon

  def test_refresh_exception_uses_failure_backoff_before_retry
    config = temp_config(Dir.tmpdir)
    lock = fake_lock
    delays = []

    SolverForgeBenchBar::Core::Config.stub(:load_config, ->(*) { config }) do
      SolverForgeBenchBar::Runtime::State.stub(:acquire_daemon_lock, ->(*) { lock }) do
        Daemon.stub(:refresh, ->(*, **) { raise "persistent fault" }) do
          Daemon.stub(:wait, lambda { |seconds|
            delays << seconds
            raise Interrupt
          }) do
            _stdout, stderr = capture_io do
              assert_raises(Interrupt) { Daemon.run("config.json") }
            end

            assert_includes stderr, "daemon refresh error: persistent fault"
          end
        end
      end
    end

    assert_equal [Daemon::ERROR_BACKOFF_SECONDS], delays
    assert lock.closed?
  end

  def test_successful_refresh_uses_configured_cadence
    config = temp_config(Dir.tmpdir)
    config[:runtime][:refreshSeconds] = 3
    lock = fake_lock
    delays = []

    SolverForgeBenchBar::Core::Config.stub(:load_config, ->(*) { config }) do
      SolverForgeBenchBar::Runtime::State.stub(:acquire_daemon_lock, ->(*) { lock }) do
        Daemon.stub(:refresh, ->(*, **) { nil }) do
          Daemon.stub(:wait, lambda { |seconds|
            delays << seconds
            raise Interrupt
          }) do
            assert_raises(Interrupt) { Daemon.run("config.json") }
          end
        end
      end
    end

    assert_equal [3], delays
    assert lock.closed?
  end

  private

  def fake_lock
    Object.new.tap do |lock|
      lock.instance_variable_set(:@closed, false)
      lock.define_singleton_method(:close) { @closed = true }
      lock.define_singleton_method(:closed?) { @closed }
    end
  end
end
