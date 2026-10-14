# frozen_string_literal: true

require_relative "test_helper"

# Family-wide visual contract, shared by the *-bar panels under /srv/lab/tools
# (TokenMaxx's square-cornered mac-bar aesthetic at Switchyard's font scale).
# Radii: zero on every shaped surface — the drop-down card, its shadow band,
# the inner border line, tiles, cohort pills, buttons, run cards, badge
# backgrounds, progress tracks and fills. Two exemptions are shapes, not
# corner rounding: the header live dot (7x7 at radius 3.5) is the only
# circle. Fonts:
# Switchyard's scale — 7 dot glyph only, 9 secondary/meta, 10 body,
# 11 card labels, 12 summary values, 15 detail headers, 21 panel titles.
class QmlVisualUniformityTest < Minitest::Test
  QML_PATH = File.expand_path("../frontend/quickshell/shell.qml", __dir__)
  SWITCHYARD_QML = "/srv/lab/tools/switchyard/frontend/quickshell/shell.qml"

  def qml
    @qml ||= File.read(QML_PATH)
  end

  def test_radius_is_zero_everywhere_except_the_dots
    radii = qml.scan(/radius:\s*([0-9.]+)/).flatten.map(&:to_f)
    refute_empty radii, "the panel must still shape its dots"

    allowed = lambda do |value|
      value.zero? ||
        value == 3.5    # the live/status dot: a circle, not a corner
    end

    bad = radii.reject { |value| allowed.call(value) }
    assert_empty bad,
      "unexpected radii (family spec: 0 everywhere, dots 3.5): #{bad.uniq}"
  end

  # The component's own block: from the marker line (whose own `{` opens the
  # root) to the line whose brace count closes it. String contents and `//`
  # comments are blanked first so braces inside them cannot skew the count.
  def component_block(marker)
    depth = nil
    block = []
    qml.each_line do |line|
      if depth.nil?
        depth = 1 if line.include?(marker)
        next
      end
      clean = line.gsub(/"[^"]*"/, '""').split("//")[0]
      depth += clean.count("{") - clean.count("}")
      break if depth <= 0

      block << line
    end
    block.join
  end

  def test_frame_card_buttons_tiles_and_pills_carry_radius_zero
    frame   = qml[/id: frameShadow.*?^\s*\}/m].to_s
    card    = qml[/id: card.*?^\s*MouseArea/m].to_s
    buttons = component_block("component ActionButton: Rectangle")
    tiles   = component_block("component MetricTile: Rectangle")
    pills   = component_block("component CohortPill: Rectangle")
    badge   = component_block("component StateBadge: Rectangle")

    [frame, card, buttons, tiles, pills, badge].each do |block|
      refute_empty block, "a named component disappeared from shell.qml"
      assert_match(/radius: 0\b/, block, "named surfaces must carry radius: 0")
    end
  end

  def test_pre_unification_radii_do_not_survive
    assert_match(/radius:\s*0\b/, qml, "square corners must actually appear in the source")
    # The old rounded frame and card radii must be gone; the dot's 3.5
    # stays as the one named circle.
    [10, 9, 4, 6, 8].each do |gone|
      bad = qml.scan(/radius:\s*#{Regexp.escape(gone.to_s)}\b(?!\.\d)/)
      assert_empty bad, "the pre-unification radius #{gone} must not survive"
    end
  end

  def test_font_scale_is_the_family_scale
    allowed = [7, 9, 10, 11, 12, 15, 21]
    sizes = qml.scan(/font\.pixelSize:\s*([0-9]+)/).flatten.map(&:to_i)
    bad = sizes.reject { |value| allowed.include?(value) }
    assert_empty bad, "off-scale font sizes in panel text: #{bad.uniq}"

    # Every tier must still be present so the hierarchy survives unified.
    (allowed - [21]).each do |size|
      assert_includes sizes, size, "font scale #{size} must still appear"
    end
  end

  def test_panel_title_reads_the_family_title_size
    # The panel title ("solverforge-bench-bar", Fira Code, bold, in the
    # header row with the live dot) holds the 21 top step.
    refute_includes qml, "font.pixelSize: 24", "the title must not exceed 21"
    refute_includes qml, "font.pixelSize: 23", "the summary value must not exceed 21"
    title = qml[/text: "solverforge-bench-bar".*?font\.pixelSize:\s*([0-9]+)/m, 1]
    assert_equal "21", title, "the panel title reads the family title size"
  end

  def test_summary_values_read_the_family_summary_size
    # MetricTile's value is the summary/metric slot: 12 (was 23).
    tile = qml[/Text \{\n\s*text: value\n.*?font\.pixelSize:\s*([0-9]+)/m, 1]
    assert_equal "12", tile, "MetricTile's metric value reads the 12 summary size"
  end

  def test_run_card_headline_reads_the_detail_header_size
    # The live run card's name line is the detail-view header: 15 (was 14).
    head = qml[/benchmarkLabel \|\| modelData\.benchmarkName \|\| "benchmark".*?font\.pixelSize:\s*([0-9]+)/m, 1]
    assert_equal "15", head, "run-card headline joins the 15 detail-header step"
  end

  def test_state_badge_text_reads_the_body_size
    # The 7 stays reserved for the badge's dot glyph in the text font; the
    # badge label itself moves up to body size 10.
    sevens = qml.scan(/font\.pixelSize:\s*7\b/).length
    assert_equal 1, sevens, "7 stays only on the badge's dot glyph"
    badge = component_block("component StateBadge: Rectangle")
    badge_text = badge[/id: badgeText.*?font\.pixelSize:\s*([0-9]+)/m, 1]
    assert_equal "9", badge_text, "state-badge text reads the 9 secondary size"
  end

  def test_documented_stale_font_pins_are_re_sourced
    # Re-source every pin the family contract carries: each value below must
    # be found in the source it names, so a family spec drift fails here
    # first — before this panel is ever compared against a drifted copy.
    pins = {
      SWITCHYARD_QML => [
        /radius:\s*0/,
        /font\.pixelSize:\s*root\.shortViewport \? 19 : 21/, # the panel title
        /font\.pixelSize:\s*15/,                             # detail-view headers
        /font\.pixelSize:\s*12/                              # summary values
      ]
    }
    pins.each do |source, patterns|
      body = File.read(source)
      patterns.each do |pattern|
        assert_match(pattern, body, "family pin #{pattern} drifted in #{source}")
      end
    end
  end
end