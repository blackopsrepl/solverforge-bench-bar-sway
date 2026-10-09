# frozen_string_literal: true

require_relative "test_helper"

class VersionContractTest < Minitest::Test
  PROJECT_ROOT = File.expand_path("..", __dir__)

  VERSION_DOCS = %w[
    README.md
    AGENTS.md
    WIREFRAME.md
    docs/configuration.md
    docs/runtime-contracts.md
  ].freeze

  def test_public_version_surfaces_match_the_runtime_version
    version = SolverForgeBenchBar::VERSION

    assert_includes read("README.md"), "The current development version is `#{version}`."
    assert_includes read("AGENTS.md"), "Application version `#{version}`"
    assert_includes read("WIREFRAME.md"), "Application version: `#{version}`"
    assert_match(/^## \[?#{Regexp.escape(version)}\]?[ (]/, read("CHANGELOG.md"))
    assert_includes read("docs/configuration.md"), "application version `#{version}`"
    assert_includes read("docs/runtime-contracts.md"), "application version `#{version}`"
  end

  def test_no_doc_surface_names_a_stale_application_version
    # Only tagged releases count: the curated 0.1.0 baseline notes are
    # intentionally unreleased, and AGENTS.md references them by design.
    # On the first tagged release there is nothing stale to check yet.
    tagged = `git tag --list 'v*'`.scan(/v(\d+\.\d+\.\d+)/).flatten
    stale = tagged.reject { |v| v == SolverForgeBenchBar::VERSION }
    stale.each do |old|
      VERSION_DOCS.each do |path|
        refute_includes read(path), "`#{old}`",
          "#{path} still names stale application version #{old}"
      end
    end
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
