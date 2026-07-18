# frozen_string_literal: true

require "json"

module SolverForgeBenchBar
  module CLI
    module_function

    def run(argv = ARGV)
      argv = argv.dup
      command = argv.shift || "help"
      if %w[-h --help].include?(command)
        puts usage
        return 0
      end
      raise ArgumentError, "Unknown option: #{command}" if command.start_with?("-")

      args = parse_args(argv)
      if args[:help]
        puts usage
        return 0
      end
      config_path = args[:config] || Core::Config.default_config_path

      case command
      when "config"
        run_config_command(args, config_path)
      when "daemon"
        snapshot = Runtime::Daemon.run(config_path, once: args[:once])
        if args[:once] && snapshot.dig(:source, :status) == "error"
          warn "Source check failed: #{Core::Redaction.clean(snapshot.dig(:source, :error))}"
          1
        else
          0
        end
      when "help", "--help", "-h"
        puts usage
        0
      when "panel"
        Runtime::QuickShell.open(config_path)
        0
      when "refresh"
        snapshot = Runtime::Daemon.refresh(config_path)
        print_json_if_requested(snapshot, args)
        0
      when "snapshot"
        print_json(Runtime::Daemon.refresh(config_path), args)
        0
      when "ui"
        run_ui_command(args, config_path)
      when "waybar"
        run_waybar_command(args, config_path)
      else
        raise ArgumentError, "Unknown command: #{command}"
      end
    rescue StandardError => e
      warn Core::Redaction.clean(e.message)
      1
    end

    def parse_args(argv)
      args = { format: "text", once: false, pretty: false, help: false, positionals: [] }
      index = 0
      while index < argv.length
        value = argv[index]
        case value
        when "--config"
          index += 1
          raise ArgumentError, "--config requires a path" unless argv[index]
          args[:config] = argv[index]
        when "--format"
          index += 1
          raise ArgumentError, "--format requires text or json" unless %w[text json].include?(argv[index])
          args[:format] = argv[index]
        when "--pretty"
          args[:pretty] = true
        when "--once"
          args[:once] = true
        when "--help", "-h"
          args[:help] = true
        else
          raise ArgumentError, "Unknown option: #{value}" if value.start_with?("-")

          args[:positionals] << value
        end
        index += 1
      end
      args
    end

    def run_config_command(args, config_path)
      subcommand = args[:positionals].first || "validate"
      if subcommand == "init"
        print_json(Core::Config.init_config(config_path), args)
        return 0
      end
      raise ArgumentError, "Unknown config subcommand: #{subcommand}" unless subcommand == "validate"

      config = Core::Config.load_config(config_path, validate: false)
      issues = Core::Config.validate_config(config)
      if args[:format] == "json"
        print_json(issues, args)
      elsif issues.empty?
        puts "Config valid."
      else
        issues.each { |issue| puts "#{issue[:severity].upcase}: #{issue[:field]} #{issue[:message]}" }
      end
      issues.any? { |issue| issue[:severity] == "error" } ? 1 : 0
    end

    def run_ui_command(args, config_path)
      subcommand = args[:positionals].first || "open"
      payload = case subcommand
                when "open"
                  Runtime::QuickShell.open(config_path)
                  Runtime::QuickShell.status(config_path)
                when "close"
                  Runtime::QuickShell.close(config_path)
                  Runtime::QuickShell.status(config_path)
                when "toggle"
                  Runtime::QuickShell.toggle(config_path)
                when "status"
                  Runtime::QuickShell.status(config_path)
                else
                  raise ArgumentError, "Unknown ui subcommand: #{subcommand}"
                end
      print_json_if_requested(payload, args)
      0
    end

    def run_waybar_command(args, config_path)
      subcommand = args[:positionals].first || "render"
      case subcommand
      when "render"
        Runtime::Waybar.render(config_path)
      when "refresh"
        Runtime::Waybar.refresh(config_path)
      when "panel", "open"
        Runtime::Waybar.open_panel(config_path)
      else
        raise ArgumentError, "Unknown waybar subcommand: #{subcommand}"
      end
      0
    end

    def print_json_if_requested(payload, args)
      print_json(payload, args) if args[:format] == "json"
    end

    def print_json(payload, args)
      puts(args[:pretty] ? JSON.pretty_generate(payload) : JSON.generate(payload))
    end

    def usage
      <<~TEXT
        solverforge-bench-bar commands:
          config init|validate
          snapshot
          refresh
          daemon [--once]
          panel
          ui open|close|toggle|status
          waybar render|refresh|panel
      TEXT
    end
  end
end
