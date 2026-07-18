# frozen_string_literal: true

require "time"

module SolverForgeBenchBar
  module Runtime
    module Daemon
      ERROR_BACKOFF_SECONDS = 10

      module_function

      def run(config_path, once: false)
        config = Core::Config.load_config(config_path)
        return refresh(config_path, config: config) if once

        lock = State.acquire_daemon_lock(config)
        raise "solverforge-bench-bar daemon already running for #{State.state_dir(config)}" unless lock

        loop do
          delay = config.dig(:runtime, :refreshSeconds).to_i
          begin
            refresh(config_path, config: config)
          rescue StandardError => e
            warn "solverforge-bench-bar daemon refresh error: #{Core::Redaction.clean(e.message)}"
            delay = [delay, ERROR_BACKOFF_SECONDS].max
          end
          wait(delay)
        end
      ensure
        lock&.close
      end

      def refresh(config_path, config: nil)
        config ||= Core::Config.load_config(config_path)
        snapshot = nil
        changed = false

        State.with_refresh_lock(config) do
          previous = State.read_snapshot(config)
          snapshot = build_snapshot(config, previous: previous)
          changed = State.materially_changed?(previous, snapshot)
          State.write_snapshot(config, snapshot)
        end

        signal_waybar(config) if changed
        snapshot
      end

      def build_snapshot(config, previous: nil, now: Time.now.utc)
        payload = Core::Warehouse.fetch(config)
        runs = payload[:activeRuns].map do |run|
          evidence = Core::LogProbe.inspect_run(run, config)
          Core::RunState.normalize_active(run, evidence, config, now: now)
        end
        cohort_runs = payload[:cohortRuns].map { |run| Core::RunState.normalize_recent(run) }
        recent_runs = payload[:recentRuns].map { |run| Core::RunState.normalize_recent(run) }
        base = {
          snapshotVersion: State::SNAPSHOT_VERSION,
          generatedAt: now.iso8601(6),
          status: "loading",
          source: {
            status: "ok",
            queriedAt: payload[:queriedAt],
            lastSuccessAt: payload[:queriedAt],
            latencyMs: payload[:latencyMs],
            error: nil
          },
          runs: runs,
          cohortRuns: cohort_runs,
          recentRuns: recent_runs,
          summary: {},
          view: {}
        }
        Presenter.apply(base, config, stale: false, now: now)
      rescue Core::Warehouse::SourceError => e
        build_source_error_snapshot(config, previous, e.message, now)
      end

      def build_source_error_snapshot(config, previous, message, now)
        base = previous ? State.deep_copy(previous) : {
          snapshotVersion: State::SNAPSHOT_VERSION,
          runs: [],
          cohortRuns: [],
          recentRuns: [],
          summary: {},
          view: {}
        }
        base[:generatedAt] = now.iso8601(6)
        base[:source] = {
          status: "error",
          queriedAt: now.iso8601(6),
          lastSuccessAt: previous&.dig(:source, :lastSuccessAt),
          latencyMs: nil,
          error: Core::Redaction.clean(message, limit: 300)
        }
        Presenter.apply(base, config, stale: false, now: now)
      end

      def signal_waybar(config)
        signal = config.dig(:runtime, :waybarSignal).to_i
        return if signal <= 0

        Core::Process.run_command("pkill", ["-RTMIN+#{signal}", "waybar"], timeout: 2)
      rescue StandardError
        nil
      end

      def wait(seconds)
        sleep(seconds)
      end
    end
  end
end
