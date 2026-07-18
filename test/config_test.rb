# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  Config = SolverForgeBenchBar::Core::Config

  def test_default_config_is_valid
    assert_empty Config.validate_config(Config.normalize_config(Config.default_config))
  end

  def test_init_writes_private_config
    Dir.mktmpdir do |dir|
      path = File.join(dir, "config.json")
      Config.init_config(path)

      assert_equal 0o600, File.stat(path).mode & 0o777
      assert_equal 12, Config.load_config(path).dig(:runtime, :waybarSignal)
    end
  end

  def test_environment_database_url_takes_precedence
    config = Config.normalize_config(Config.default_config)
    ENV[Config::DATABASE_URL_ENV] = "postgresql://example/bench"
    assert_equal "postgresql://example/bench", Config.database_url(config)
  ensure
    ENV.delete(Config::DATABASE_URL_ENV)
  end

  def test_validation_rejects_unsafe_limits
    config = Config.normalize_config(Config.default_config)
    config[:source][:logTailBytes] = 10
    config[:runtime][:waybarSignal] = 42

    fields = Config.validate_config(config).map { |issue| issue[:field] }
    assert_includes fields, "source.logTailBytes"
    assert_includes fields, "runtime.waybarSignal"
  end

  def test_validation_rejects_empty_runtime_paths_before_expansion
    config = Config.default_config
    config[:runtime][:stateDir] = ""
    config[:runtime][:quickShellShell] = "  "

    normalized = Config.normalize_config(config)
    fields = Config.validate_config(normalized).map { |issue| issue[:field] }

    assert_equal "", normalized.dig(:runtime, :stateDir)
    assert_equal "  ", normalized.dig(:runtime, :quickShellShell)
    assert_includes fields, "runtime.stateDir"
    assert_includes fields, "runtime.quickShellShell"
    assert_raises(ArgumentError) { SolverForgeBenchBar::Runtime::State.state_dir(normalized) }
    assert_raises(ArgumentError) do
      SolverForgeBenchBar::Runtime::QuickShell.launch("unused.json", normalized)
    end
  end

  def test_runtime_load_rejects_invalid_bounds_by_default
    Dir.mktmpdir do |dir|
      config = Config.default_config
      config[:runtime][:refreshSeconds] = 0
      config[:source][:activeRunLimit] = 100_000
      config[:source][:logTailBytes] = 2_000_000_000
      path = File.join(dir, "invalid.json")
      File.write(path, JSON.generate(config))

      error = assert_raises(Config::ValidationError) { Config.load_config(path) }
      fields = error.issues.map { |issue| issue[:field] }

      assert_includes fields, "runtime.refreshSeconds"
      assert_includes fields, "source.activeRunLimit"
      assert_includes fields, "source.logTailBytes"
      assert_equal 0, Config.load_config(path, validate: false).dig(:runtime, :refreshSeconds)
    end
  end

  def test_save_rejects_invalid_config_without_creating_file
    Dir.mktmpdir do |dir|
      config = Config.default_config
      config[:source][:logTailBytes] = 10
      path = File.join(dir, "invalid.json")

      assert_raises(Config::ValidationError) { Config.save_config(config, path) }
      refute File.exist?(path)
    end
  end

  def test_atomic_config_write_opens_private_exclusive_temp_file
    opened = []
    real_open = File.method(:open)
    wrapper = lambda do |path, *arguments, &block|
      opened << [path, arguments]
      real_open.call(path, *arguments, &block)
    end

    Dir.mktmpdir do |dir|
      path = File.join(dir, "config.json")
      File.stub(:open, wrapper) { Config.init_config(path) }

      temp_open = opened.find { |opened_path, _arguments| opened_path.start_with?("#{path}.tmp.") }
      refute_nil temp_open
      flags, mode = temp_open.last
      assert_operator flags & File::EXCL, :positive?
      assert_equal 0o600, mode
    end
  end
end
