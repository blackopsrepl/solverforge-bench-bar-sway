# UI

The Waybar chip is a compact cached-state summary. The QuickShell panel is the only detailed product UI.

The panel is a bar drop-down, not an overlay. The `PanelWindow` layer surface is bounded to exactly the card's rect plus a 6px shadow halo at its bottom edge, anchored to only the top and left screen edges with `ExclusionMode.Ignore` (it reserves no layout space) and `WlrKeyboardFocus.OnDemand` (opening it never steals keyboard focus). The card hangs from the bar's top edge at `popupTopMargin` = 52px, leans left of center — the side its Waybar chip lives on — and the desktop beside and below the card stays fully interactive: clicks never pass through a Wayland surface, so no scrim, no backdrop, and no screen-wide input mask exists. The surface is never full-screen.

The card height is counted from the parts actually laid out — diagnostics banner (34 only while a message is up), header row, four metric tiles, the cohort band, the monitor band, and the recent-runs band — and capped at the room between the bar and the screen's bottom edge, floored at 640 and capped at 860; the monitor band carries the flex and its lists scroll instead of pushing the surface past the screen. The width is content-fit with a 460 floor and a 1120 cap. It uses Fira Code, the SolverForge Linux Hackerman palette, and semantic warning and critical colors. It contains a header with a live status dot, four summary tiles, the current nightly cohort, detailed live run cards, and horizontally scrolling recent terminal runs.

The layout adapts to the card with two breakpoint predicates: `narrowLayout` (`modal.width < 720`) and `shortViewport` (`modal.height < 660`). Because the bounded window is exactly the card, these read the card's own rect and keep the same decisions the viewport predicates used to make: below the breakpoints the margins tighten and the fixed diagnostic, monitor, and recent bands shrink; cohort pills wrap onto further lines instead of one overflowing row; the monitor and history lists keep their own scrollbars.

The header carries a live dot mirroring the snapshot's own status tone (amber while a refresh or close command is in flight), so the header, the card border, and the chip agree on health at a glance.

Active and attention membership may overlap: an active run with result issues contributes to both tiles but appears once in the monitor. Each card exposes run-error, watchdog, validation, infeasible, fair-start, and wall-time counters. Terminal warehouse drift is excluded from the live list, chip attention count, and global status; only its neutral stale-row count remains in diagnostics. Recent terminal failures remain history and do not create live attention.

Empty surfaces explain themselves. The run monitor shows what appears there and how a run gets recorded (once a benchmark writes its first warehouse rows the daemon classifies it); the history band states that completed and failed runs will appear newest first. The terminal error branch keeps its dedicated redacted message.

Diagnostics surface at the top of the card as a read-only banner: a failed warehouse ingest names the redacted error and states that cached data below is unchanged, and a stale snapshot names the staleness with a humanized refresh age. Neither is a control. History cards carry a humanized completion age and, when more runs exist than fit, an explicit "scroll right for more runs" cue plus an AsNeeded horizontal scrollbar.

Current solver elapsed time updates locally once per second. Cache staleness is also derived locally from the snapshot timestamp and configured threshold, so the panel changes to a neutral cached state if refreshes stop. Source observation remains daemon-owned.

Snapshot and UI files reload through the single state-event marker. Both run-list and recent-run scroll offsets are captured before reload and restored after the replacement models settle.

Refresh uses its own process runner. Close, Escape, and a click inside the window but outside the card (the shadow halo strip below the card's bottom edge and its corner gaps) use a separate close runner, so closing is never dropped merely because a refresh is in progress. The UI exposes no benchmark-control action.

Family-standard trade: because the surface is bounded to the card, the screen-wide "click anywhere outside to dismiss" behavior of an overlay is intentionally not preserved — the desktop outside the window must remain interactive, and a Wayland surface is opaque to input. Dismissal paths are Escape, the Close button, and a click in the window's own halo margin; CLI `ui close|toggle` continues to work unchanged. This is the standing trade for every bounded drop-down in the bar family.