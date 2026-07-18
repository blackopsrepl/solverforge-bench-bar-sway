# frozen_string_literal: true

require_relative "test_helper"

class VersionContractTest < Minitest::Test
  PROJECT_ROOT = File.expand_path("..", __dir__)

  def test_public_version_surfaces_match_the_runtime_version
    version = SolverForgeBenchBar::VERSION

    assert_includes read("README.md"), "The current development version is `#{version}`."
    assert_includes read("AGENTS.md"), "Application version `#{version}`"
    assert_includes read("WIREFRAME.md"), "Application version: `#{version}` (unreleased)."
    assert_match(/^## #{Regexp.escape(version)} - Unreleased$/, read("CHANGELOG.md"))
  end

  def test_schema_versions_remain_independent_from_the_application_version
    assert_equal 1, SolverForgeBenchBar::Core::Config.default_config[:version]
    assert_equal 1, SolverForgeBenchBar::Runtime::State::SNAPSHOT_VERSION
    assert_includes read("README.md"), "Config schema version `1` and snapshot schema version `1` evolve independently"
  end

  private

  def read(path)
    File.read(File.join(PROJECT_ROOT, path))
  end
end
