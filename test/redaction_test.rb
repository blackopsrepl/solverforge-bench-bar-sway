# frozen_string_literal: true

require_relative "test_helper"

class RedactionTest < Minitest::Test
  Redaction = SolverForgeBenchBar::Core::Redaction

  def test_removes_database_urls_passwords_and_absolute_paths
    cleaned = Redaction.clean(
      "failed at /home/operator/private/run.log:12 using postgresql://secret:password@db/bench password=hunter2"
    )

    assert_includes cleaned, "<redacted-path>"
    assert_includes cleaned, "<redacted-database-url>"
    assert_includes cleaned, "password=<redacted>"
    refute_includes cleaned, "/home/operator"
    refute_includes cleaned, "hunter2"
  end

  def test_does_not_treat_web_urls_as_filesystem_paths
    cleaned = Redaction.clean("request failed for https://example.test/status")

    assert_equal "request failed for https://example.test/status", cleaned
  end
end
