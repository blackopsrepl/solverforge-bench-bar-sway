# frozen_string_literal: true

require_relative "test_helper"

# Structural contract for the bounded bar drop-down surface.
#
# The panel used to be a full-screen transparent overlay with an input mask:
# the Wayland surface spanned the whole screen, so the desktop under it was a
# click-catcher and the modal read like a website overlay. The window itself
# is now bounded to the card's rect (plus a shadow halo at the bottom edge),
# hung from the bar with margins, and carries no scrim, no backdrop, and no
# input mask. qmllint cannot validate this file in CI (the Quickshell ShellRoot
# type only resolves where Quickshell is installed), so the load-bearing shape
# is asserted here.
class PanelSurfaceTest < Minitest::Test
  PANEL = File.expand_path("../frontend/quickshell/shell.qml", __dir__)

  def panel_source
    @panel_source ||= File.read(PANEL)
  end

  def test_window_is_bounded_to_the_card_not_the_screen
    # Anchoring only the top and left edges of the layer surface: a bottom or
    # right anchor pins that edge to the screen and stretches the window back
    # into an overlay, defeating the bounded surface.
    assert_match(/anchors\s*\{\s*\n\s*top: true\s*\n\s*left: true\s*\n\s*\}/m, panel_source)
    refute_match(/anchors\s*\{[^}]*bottom: true/m, panel_source)
    refute_match(/anchors\s*\{[^}]*right: true/m, panel_source)
    assert_includes panel_source, "implicitWidth: root.dropCardWidth"
    assert_includes panel_source, "implicitHeight: root.dropCardHeight + 6"
    # The old full-screen geometry declarations must be gone entirely.
    refute_match(/implicitHeight: screen \? screen\.height/, panel_source)
    refute_match(/implicitWidth: screen \? screen\.width/, panel_source)
  end

  def test_no_scrim_backdrop_or_input_mask_remains
    # The two centered scrim rectangles and the Region input mask were the
    # full-screen era; the bounded surface needs none of them. Centering
    # inside the list bands (empty states) is unaffected and stays.
    refute_match(/Qt\.rgba\(0, 0, 0, 0\.22\)/, panel_source)
    refute_match(/Qt\.rgba\(0, 0, 0, 0\.34\)/, panel_source)
    refute_includes panel_source, "mask: Region"
    refute_includes panel_source, "Intersection.Intersect"
    refute_includes panel_source, "width: card.width + 10"
    refute_includes panel_source, "height: card.height + 4"
  end

  def test_height_is_counted_from_laid_out_parts_and_capped_at_the_viewport
    assert_includes panel_source, "function benchbarCardHeight()"
    # Bands counted at their laid-out sizes: banner when present, 48 header,
    # 74 tiles, the cohort band, and the recent band — never a viewport-sized
    # sum. popupTopMargin and the 6px halo live in the WINDOW's height, not in
    # the card's counted content height.
    assert_includes panel_source, "var fixed_bands = banner + 48 + 74 + cohort_band + recent_band"
    assert_includes panel_source, "var content_height = fixed_bands + monitor_band"
    assert_includes panel_source, "recent_band = root.countedShortViewport ? 72 : 92"
    assert_includes panel_source, "Math.min(root.popupMaxHeight, Math.max(root.popupMinHeight, content_height), available_window)"
    assert_includes panel_source, "implicitHeight: root.dropCardHeight + 6"
  end

  def test_width_is_content_fit_with_a_floor_and_a_cap
    assert_includes panel_source, "property int popupMinWidth: 460"
    assert_includes panel_source, "property int popupMaxWidth: 1120"
    assert_includes panel_source, "readonly property int dropCardWidth: Math.min(popupMaxWidth, Math.max(popupMinWidth, (modal.screen ? modal.screen.width : 1440) - 36))"
  end

  def test_card_hangs_from_the_bar_edge_left_of_center
    assert_includes panel_source, "exclusionMode: ExclusionMode.Ignore"
    assert_includes panel_source, "WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand"
    assert_includes panel_source, "property int popupTopMargin: 52"
    assert_match(/margins\s*\{[^}]*top: root\.popupTopMargin/m, panel_source)
    # The chip lives in the Waybar left cluster, so the drop-down leans left
    # of center instead of centering on the screen.
    assert_includes panel_source, "function dropLeftOffset()"
    assert_includes panel_source, "left: root.dropLeftOffset()"
    refute_includes panel_source, "anchors.horizontalCenter"
  end

  def test_clicks_inside_the_window_but_outside_the_card_dismiss_it
    # The catcher fills the now-card-sized window (behind the card), not the
    # screen; the card keeps its own swallow area so real content clicks pass.
    assert_match(/MouseArea\s*\{\s*anchors\.fill: parent\s*z: -1\s*onClicked: root\.closeModal\(\)/m, panel_source)
    assert_match(/Rectangle\s*\{\s*id: card.*?onClicked: mouse\.accepted = true/m, panel_source)
    assert_includes panel_source, "id: frameShadow"
    # Escape keeps closing the panel regardless of where focus sits.
    assert_match(/sequence: "Esc"/, panel_source)
    assert_includes panel_source, "onActivated: root.closeModal()"
  end

  def test_viewports_read_the_window_dimensions_with_the_same_thresholds
    # modal.width/height used to be the whole screen; with the bounded surface
    # they are the card's own rect, so the thresholds keep the same decisions.
    assert_match(/property bool narrowLayout: modal\.width < 720/, panel_source)
    assert_match(/property bool shortViewport: modal\.height < 660/, panel_source)
    # The card must fill the bounded window exactly (the surface is the card's
    # rect plus the halo), not re-derive viewport arithmetic from margins.
    assert_match(/Rectangle\s*\{\s*id: card\s*anchors\.fill: parent\s*anchors\.bottomMargin: 6/m, panel_source)
    refute_match(/id: card\s*width: root\.narrowLayout \? Math\.max\(320, modal\.width - 16\)/m, panel_source)
    refute_match(/Math\.max\(560, modal\.height - 32\)/, panel_source)
    # The height counter cannot read shortViewport: the window height binds
    # from the counted height, so a window-read back into the count is a
    # binding cycle. The tight decision comes from the screen-side predicate.
    height_fn = panel_source[/function benchbarCardHeight\(\).*?\n    \}/m]
    assert height_fn, "the counted-height function is missing"
    refute_includes height_fn, "root.shortViewport"
    assert_includes height_fn, "root.countedShortViewport"
  end

  def test_header_carries_the_live_dot
    # Family polish: the header dot mirrors the snapshot's own status tone
    # (the presenter's language, not the panel's), going amber only for the
    # runner the refresh shares and red when an action errored.
    assert_includes panel_source, "id: liveDot"
    assert_match(/id: liveDot.*?root\.(actionError|closeRunner\.running|statusColor)/m, panel_source)
    assert_match(/id: liveDot.*?actionRunner\.running/m, panel_source)
  end

  def test_panel_stays_strictly_read_only
    dispatched = panel_source.scan(/runBenchbar\(\[([^\]]*)\]\)/).flatten
    assert_equal [], dispatched.reject { |args| args.include?("\"refresh\"") || args.include?("\"ui\"") },
                 "the panel dispatches a mutation or trigger command"
    assert_includes panel_source, 'root.runBenchbar(["refresh"])'
    assert_includes panel_source, "ui\", \"close"
    refute_match(/command: \[[^\]]*"(stop|retry|launch|cleanup|repair)"/, panel_source)
  end
end