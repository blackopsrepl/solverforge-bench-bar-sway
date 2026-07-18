# UI

The Waybar chip is a compact cached-state summary. The QuickShell modal is the only detailed product UI.

The modal uses Fira Code, the SolverForge Linux Hackerman palette, and semantic warning and critical colors. It contains a header, summary tiles, current nightly cohort, detailed live run cards, and recent terminal runs. The global modal state represents live source and execution health. Terminal warehouse drift is excluded from the live list, chip attention count, and global status; only its neutral stale-row count remains in diagnostics.

Current solver elapsed time updates locally once per second. Source observation remains daemon-owned.

Snapshot and UI files reload through the single state-event marker. Both run-list and recent-run scroll offsets are captured before reload and restored after the replacement models settle.
