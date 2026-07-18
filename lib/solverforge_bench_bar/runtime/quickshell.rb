# frozen_string_literal: true

require "time"

module SolverForgeBenchBar
  module Runtime
    module QuickShell
      module_function

      def open(config_path)
        config = Core::Config.load_config(config_path)
        State.write_ui_state(config, { open: true, requestedAt: Time.now.utc.iso8601(6) })
        launch(config_path, config)
      end

      def close(config_path)
        config = Core::Config.load_config(config_path)
        State.write_ui_state(config, { open: false, requestedAt: Time.now.utc.iso8601(6) })
      end

      def toggle(config_path)
        config = Core::Config.load_config(config_path)
        State.read_ui_state(config)[:open] ? close(config_path) : open(config_path)
        State.read_ui_state(config)
      end

      def status(config_path)
        config = Core::Config.load_config(config_path)
        State.read_ui_state(config)
      end

      def launch(config_path, config = nil)
        config ||= Core::Config.load_config(config_path)
        shell = Core::Config.validated_path(config.dig(:runtime, :quickShellShell), "runtime.quickShellShell")
        command = config.dig(:runtime, :quickShellCommand).to_s
        env = {
          "SOLVERFORGE_BENCH_BAR_BIN" => resolved_binary,
          "SOLVERFORGE_BENCH_BAR_CONFIG" => File.expand_path(config_path),
          "SOLVERFORGE_BENCH_BAR_STATE_DIR" => State.state_dir(config),
          "QT_QPA_PLATFORM" => "wayland"
        }
        result = Core::Process.run_command(
          command,
          ["--daemonize", "--no-duplicate", "--path", shell],
          timeout: 5,
          env: env
        )
        raise Core::Redaction.clean(result.stderr) unless result.success?

        result
      end

      def resolved_binary
        configured = ENV["SOLVERFORGE_BENCH_BAR_BIN"].to_s
        configured.empty? ? "solverforge-bench-bar" : configured
      end
    end
  end
end
