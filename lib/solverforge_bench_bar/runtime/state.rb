# frozen_string_literal: true

require "fileutils"
require "json"
require "time"

module SolverForgeBenchBar
  module Runtime
    module State
      SNAPSHOT_VERSION = 1
      SNAPSHOT_FILE = "snapshot.json"
      UI_STATE_FILE = "ui.json"
      STATE_EVENT_FILE = "state-event.json"
      DAEMON_LOCK_FILE = "daemon.lock"
      REFRESH_LOCK_FILE = "refresh.lock"

      module_function

      def state_dir(config)
        Core::Config.validated_path(config.dig(:runtime, :stateDir), "runtime.stateDir")
      end

      def snapshot_path(config)
        File.join(state_dir(config), SNAPSHOT_FILE)
      end

      def ui_state_path(config)
        File.join(state_dir(config), UI_STATE_FILE)
      end

      def state_event_path(config)
        File.join(state_dir(config), STATE_EVENT_FILE)
      end

      def read_snapshot(config)
        read_json(snapshot_path(config))
      end

      def write_snapshot(config, snapshot)
        ensure_state_dir(config)
        atomic_write_json(snapshot_path(config), snapshot)
        write_state_event(config)
        snapshot
      end

      def read_ui_state(config)
        normalize_ui_state(read_json(ui_state_path(config)))
      end

      def write_ui_state(config, ui_state)
        ensure_state_dir(config)
        atomic_write_json(ui_state_path(config), normalize_ui_state(ui_state))
        write_state_event(config)
      end

      def default_ui_state
        { open: false, requestedAt: "" }
      end

      def normalize_ui_state(ui_state)
        state = default_ui_state.merge((ui_state || {}).transform_keys(&:to_sym))
        { open: !!state[:open], requestedAt: state[:requestedAt].to_s }
      end

      def stale?(snapshot, config, now = Time.now)
        generated = parse_time(snapshot && snapshot[:generatedAt])
        return true unless generated

        generated < now - config.dig(:display, :staleAfterSeconds).to_i
      end

      def materially_changed?(previous, current)
        return true unless previous

        semantic_snapshot(previous) != semantic_snapshot(current)
      end

      def semantic_snapshot(snapshot)
        payload = deep_copy(snapshot || {})
        payload.delete(:generatedAt)
        strip_volatile_source(payload[:source])
        strip_volatile_source(payload.dig(:view, :source))
        payload
      end

      def strip_volatile_source(source)
        return unless source

        source.delete(:queriedAt)
        source.delete(:lastSuccessAt)
        source.delete(:latencyMs)
      end

      def with_refresh_lock(config)
        ensure_state_dir(config)
        File.open(lock_path(config, REFRESH_LOCK_FILE), File::RDWR | File::CREAT, 0o600) do |file|
          file.flock(File::LOCK_EX)
          yield
        end
      end

      def acquire_daemon_lock(config)
        ensure_state_dir(config)
        file = File.open(lock_path(config, DAEMON_LOCK_FILE), File::RDWR | File::CREAT, 0o600)
        return nil unless file.flock(File::LOCK_EX | File::LOCK_NB)

        file.rewind
        file.truncate(0)
        file.write("#{::Process.pid}\n")
        file.flush
        file
      rescue Errno::EWOULDBLOCK, Errno::EAGAIN
        nil
      end

      def ensure_state_dir(config)
        FileUtils.mkdir_p(state_dir(config))
        File.chmod(0o700, state_dir(config))
      end

      def read_json(path)
        expanded = File.expand_path(path)
        return nil unless File.file?(expanded)

        JSON.parse(File.read(expanded), symbolize_names: true)
      rescue JSON::ParserError
        nil
      end

      def atomic_write_json(path, payload)
        temp_path = "#{path}.tmp.#{$$}"
        File.write(temp_path, "#{JSON.pretty_generate(payload)}\n")
        File.chmod(0o600, temp_path)
        File.rename(temp_path, path)
        File.chmod(0o600, path)
        path
      ensure
        FileUtils.rm_f(temp_path) if temp_path && File.exist?(temp_path)
      end

      def write_state_event(config)
        atomic_write_json(state_event_path(config), { updatedAt: Time.now.utc.iso8601(6) })
      end

      def lock_path(config, name)
        File.join(state_dir(config), name)
      end

      def parse_time(value)
        return nil if value.to_s.strip.empty?

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def deep_copy(value)
        JSON.parse(JSON.generate(value), symbolize_names: true)
      end
    end
  end
end
