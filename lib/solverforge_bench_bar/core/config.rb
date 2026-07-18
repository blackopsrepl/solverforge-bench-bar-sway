# frozen_string_literal: true

require "fileutils"
require "json"
require "securerandom"

module SolverForgeBenchBar
  module Core
    module Config
      DEFAULT_DATABASE_URL = "postgresql://postgres@localhost/solverforge_bench"
      DATABASE_URL_ENV = "SOLVERFORGE_BENCH_BAR_DATABASE_URL"

      class ValidationError < ArgumentError
        attr_reader :issues

        def initialize(issues)
          @issues = issues
          detail = issues.map { |issue| "#{issue[:field]} #{issue[:message]}" }.join(", ")
          super("Invalid solverforge-bench-bar config: #{detail}")
        end
      end

      module_function

      def default_config_path
        File.join(Dir.home, ".config", "solverforge-bench-bar", "config.json")
      end

      def default_config
        {
          version: 1,
          source: {
            databaseUrl: DEFAULT_DATABASE_URL,
            psqlCommand: "psql",
            connectTimeoutSeconds: 2,
            statementTimeoutMilliseconds: 2_000,
            lockTimeoutMilliseconds: 500,
            commandTimeoutSeconds: 5,
            activeRunLimit: 16,
            recentRunLimit: 12,
            logTailBytes: 131_072
          },
          runtime: {
            stateDir: File.join(Dir.home, ".local", "state", "solverforge-bench-bar"),
            refreshSeconds: 2,
            waybarSignal: 12,
            quickShellCommand: "quickshell",
            quickShellShell: File.join(
              Dir.home,
              ".local",
              "share",
              "solverforge-bench-bar",
              "frontend",
              "quickshell",
              "shell.qml"
            )
          },
          display: {
            staleAfterSeconds: 8,
            stallGraceSeconds: 30,
            maxTooltipRuns: 4,
            cohortWindowSeconds: 120
          }
        }
      end

      def init_config(path = default_config_path)
        config = normalize_config(default_config)
        save_config(config, path)
        config
      end

      def load_config(path = default_config_path, validate: true)
        expanded = File.expand_path(path)
        raw = File.file?(expanded) ? JSON.parse(File.read(expanded), symbolize_names: true) : default_config
        config = normalize_config(raw)
        validate_config!(config) if validate
        config

      rescue JSON::ParserError => e
        raise ArgumentError, "Invalid solverforge-bench-bar config #{path}: #{e.message}"
      end

      def save_config(config, path = default_config_path)
        expanded = File.expand_path(path)
        FileUtils.mkdir_p(File.dirname(expanded))
        normalized = normalize_config(config)
        validate_config!(normalized)
        atomic_write_json(expanded, normalized)
      end

      def database_url(config)
        override = ENV[DATABASE_URL_ENV].to_s.strip
        return override unless override.empty?

        config.dig(:source, :databaseUrl).to_s
      end

      def validate_config(config)
        issues = []
        source = config.fetch(:source, {})
        runtime = config.fetch(:runtime, {})
        display = config.fetch(:display, {})

        required(issues, source, :databaseUrl, "source.databaseUrl")
        required(issues, source, :psqlCommand, "source.psqlCommand")
        required(issues, runtime, :stateDir, "runtime.stateDir")
        required(issues, runtime, :quickShellCommand, "runtime.quickShellCommand")
        required(issues, runtime, :quickShellShell, "runtime.quickShellShell")

        minimum(issues, source, :connectTimeoutSeconds, 1, "source.connectTimeoutSeconds")
        minimum(issues, source, :statementTimeoutMilliseconds, 100, "source.statementTimeoutMilliseconds")
        minimum(issues, source, :lockTimeoutMilliseconds, 1, "source.lockTimeoutMilliseconds")
        minimum(issues, source, :commandTimeoutSeconds, 1, "source.commandTimeoutSeconds")
        bounded(issues, source, :activeRunLimit, 1, 100, "source.activeRunLimit")
        bounded(issues, source, :recentRunLimit, 1, 100, "source.recentRunLimit")
        bounded(issues, source, :logTailBytes, 4_096, 4_194_304, "source.logTailBytes")
        minimum(issues, runtime, :refreshSeconds, 1, "runtime.refreshSeconds")
        bounded(issues, runtime, :waybarSignal, 1, 31, "runtime.waybarSignal")
        minimum(issues, display, :staleAfterSeconds, 1, "display.staleAfterSeconds")
        minimum(issues, display, :stallGraceSeconds, 0, "display.stallGraceSeconds")
        bounded(issues, display, :maxTooltipRuns, 1, 20, "display.maxTooltipRuns")
        bounded(issues, display, :cohortWindowSeconds, 1, 600, "display.cohortWindowSeconds")

        if display[:staleAfterSeconds].to_i < runtime[:refreshSeconds].to_i
          issues << issue(:error, "display.staleAfterSeconds", "must be at least runtime.refreshSeconds")
        end

        issues
      end

      def validate_config!(config)
        errors = validate_config(config).select { |issue| issue[:severity] == "error" }
        raise ValidationError, errors unless errors.empty?

        config
      end

      def normalize_config(config)
        merged = deep_merge(default_config, symbolize(config || {}))
        merged[:version] = merged[:version].to_i
        integer_keys(merged[:source], %i[
          connectTimeoutSeconds statementTimeoutMilliseconds lockTimeoutMilliseconds
          commandTimeoutSeconds activeRunLimit recentRunLimit logTailBytes
        ])
        integer_keys(merged[:runtime], %i[refreshSeconds waybarSignal])
        integer_keys(merged[:display], %i[
          staleAfterSeconds stallGraceSeconds maxTooltipRuns cohortWindowSeconds
        ])
        merged[:runtime][:stateDir] = normalize_path(merged[:runtime][:stateDir])
        merged[:runtime][:quickShellShell] = normalize_path(merged[:runtime][:quickShellShell])
        merged
      end

      def normalize_path(value)
        path = value.to_s
        path.strip.empty? ? path : File.expand_path(path)
      end

      def validated_path(value, field)
        path = value.to_s
        raise ArgumentError, "#{field} must be set" if path.strip.empty?

        File.expand_path(path)
      end

      def atomic_write_json(path, payload)
        temp_path = "#{path}.tmp.#{$$}.#{SecureRandom.hex(6)}"
        flags = File::WRONLY | File::CREAT | File::EXCL
        File.open(temp_path, flags, 0o600) do |file|
          file.write("#{JSON.pretty_generate(payload)}\n")
        end
        File.rename(temp_path, path)
        File.chmod(0o600, path)
        payload
      ensure
        FileUtils.rm_f(temp_path) if temp_path && File.exist?(temp_path)
      end

      def integer_keys(hash, keys)
        keys.each { |key| hash[key] = hash[key].to_i }
      end

      def required(issues, hash, key, field)
        issues << issue(:error, field, "must be set") if hash[key].to_s.strip.empty?
      end

      def minimum(issues, hash, key, minimum_value, field)
        return if hash[key].to_i >= minimum_value

        issues << issue(:error, field, "must be at least #{minimum_value}")
      end

      def bounded(issues, hash, key, minimum_value, maximum_value, field)
        value = hash[key].to_i
        return if (minimum_value..maximum_value).cover?(value)

        issues << issue(:error, field, "must be between #{minimum_value} and #{maximum_value}")
      end

      def issue(severity, field, message)
        { severity: severity.to_s, field: field, message: message }
      end

      def symbolize(value)
        case value
        when Hash
          value.each_with_object({}) { |(key, inner), out| out[key.to_sym] = symbolize(inner) }
        when Array
          value.map { |inner| symbolize(inner) }
        else
          value
        end
      end

      def deep_merge(base, override)
        base.merge(override) do |_key, old_value, new_value|
          old_value.is_a?(Hash) && new_value.is_a?(Hash) ? deep_merge(old_value, new_value) : new_value
        end
      end
    end
  end
end
