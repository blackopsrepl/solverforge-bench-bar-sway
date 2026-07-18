# frozen_string_literal: true

require_relative "test_helper"

class QmlContractTest < Minitest::Test
  def test_issue_details_include_wall_time_violations
    qml = File.read(File.expand_path("../frontend/quickshell/shell.qml", __dir__))

    assert_includes qml, '"   wall-time " + (counters.wallTimeViolations || 0)'
  end
end
