# frozen_string_literal: true

require_relative "test_helper"

class QmlContractTest < Minitest::Test
  QML_PATH = File.expand_path("../frontend/quickshell/shell.qml", __dir__)

  def qml_source
    File.read(QML_PATH)
  end

  def test_issue_details_include_wall_time_violations
    assert_includes qml_source, '"   wall-time " + (counters.wallTimeViolations || 0)'
  end

  def test_empty_state_explains_what_appears_and_how_a_run_is_recorded
    qml = qml_source

    # The run monitor must explain the waiting state, what appears here, and
    # how a run gets recorded, instead of blank space or a bare refusal.
    assert_match(/Waiting for the first snapshot/, qml)
    assert_match(/Live run cards appear here once the warehouse records a running nightly cohort/, qml)
    assert_match(/writes its first warehouse rows/, qml)
    # Terminal history must not be silent blank space either.
    assert_match(/No terminal run history is cached yet/, qml)

    # The error branch keeps its dedicated message and stays visually separate.
    assert_match(/visible: root\.monitorRuns\.length === 0 && root\.source\.status === "error"/, qml)
  end

  def test_history_rows_show_timestamps_and_overflow_cue
    qml = qml_source

    # History cards humanize their age (no raw ISO strings) and carry an
    # explicit overflow cue plus an AsNeeded horizontal scrollbar. The
    # delegate scope is isolated, so the card's own id carries modelData.
    assert_match(/function humanizeAge\(/, qml)
    assert_match(/humanizeAge\(recentCard\.modelData\.completedAt \|\| recentCard\.modelData\.createdAt\)/, qml)
    assert_match(/recentList\.contentWidth > recentList\.width/, qml)
    assert_match(/ScrollBar\.horizontal: ScrollBar \{/, qml)
    assert_match(/id: recentScrollBar/, qml)
    assert_match(/policy: ScrollBar\.AsNeeded/, qml)
    # The overflow cue's visibility derives from the real overflow predicate.
    assert_match(/visible: recentList\.contentWidth > recentList\.width/, qml)
  end

  def test_diagnostics_surface_ingest_failure_and_stale_data
    qml = qml_source

    # A diagnostics banner exists and renders whenever a diagnostics message
    # is present; the empty state yields to it instead of talking over it.
    assert_match(/component DiagnosticsBanner: Rectangle/, qml)
    assert_match(/Layout\.preferredHeight: root\.diagnosticsMessage\.length > 0 \? 34 : 0/, qml)
    assert_match(/visible: root\.diagnosticsMessage\.length > 0\n/, qml)
    # Stale data must be named; ingest failure must surface the redacted error.
    assert_match(/Snapshot is stale/, qml)
    assert_match(/Warehouse snapshot failed/, qml)
    assert_match(/root\.source\.error/, qml)
    # Negative control the skill requires: a stale-data render without the
    # banner construct is a regression, and so is silent staling (the old
    # header-only hint must never be the only surface again).
    silence = qml.gsub(/^.*Snapshot is stale.*$/, "")
    assert_match(/component DiagnosticsBanner: Rectangle/, silence)
    # The stale branch must be reachable: guarded by the snapshotExpired
    # predicate, not dead code (a muted branch would restore silent staling).
    assert_match(/if \(root\.snapshotExpired\) \{\n            return "Snapshot is stale:/, qml)
  end

  def test_viewport_breakpoints_drive_layout_adaptation
    qml = qml_source

    # Breakpoints mirror Switchyard's pattern: width/height predicates checked
    # against the modal window, with shortViewport tightening margins.
    assert_match(/property bool narrowLayout: modal\.width < \d+/, qml)
    assert_match(/property bool shortViewport: modal\.height < \d+/, qml)
    assert_match(/anchors\.margins: root\.shortViewport \? \d+ : 18/, qml)
    assert_match(/spacing: root\.shortViewport \? \d+ : 12/, qml)
    # Cohort pills must wrap instead of overflowing on one line.
    assert_match(/component CohortFlow: Flow \{/, qml)
    assert_match(/CohortFlow \{$/, qml)
  end
end
