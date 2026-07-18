# UI

The Waybar chip is a compact cached-state summary. The QuickShell modal is the only detailed product UI.

The modal uses Fira Code, the SolverForge Linux Hackerman palette, and semantic warning and critical colors. It contains a header, four summary tiles, the current nightly cohort, detailed live run cards, and horizontally scrolling recent terminal runs.

Active and attention membership may overlap: an active run with result issues contributes to both tiles but appears once in the monitor. Each card exposes run-error, watchdog, validation, infeasible, fair-start, and wall-time counters. Terminal warehouse drift is excluded from the live list, chip attention count, and global status; only its neutral stale-row count remains in diagnostics. Recent terminal failures remain history and do not create live attention.

Current solver elapsed time updates locally once per second. Cache staleness is also derived locally from the snapshot timestamp and configured threshold, so the modal changes to a neutral cached state if refreshes stop. Source observation remains daemon-owned.

Snapshot and UI files reload through the single state-event marker. Both run-list and recent-run scroll offsets are captured before reload and restored after the replacement models settle.

Refresh uses its own process runner. Close, Escape, and overlay clicks use a separate close runner, so closing is never dropped merely because a refresh is in progress. The UI exposes no benchmark-control action.
