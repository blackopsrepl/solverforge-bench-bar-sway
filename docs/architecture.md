# Architecture

`solverforge-bench-bar` has five layers:

1. Ruby CLI entrypoint.
2. Read-only PostgreSQL and bounded run-log adapters.
3. Pure run-state classification and presentation.
4. Atomic cached JSON state under `~/.local/state/solverforge-bench-bar`.
5. QuickShell modal plus cached-state Waybar renderer.

`psql` is the warehouse boundary. The configured PostgreSQL URL is decomposed into libpq environment variables so credentials never appear in process arguments, and every session is forced into read-only transactions with short timeouts. A single query returns bounded running candidates, an independently bounded terminal slice for the current nightly cohort, and bounded recent terminal runs.

Log inspection applies only to running candidates. It accepts readable files resolving beneath the run's recorded repository root, reads at most `source.logTailBytes`, and persists normalized event evidence rather than raw tails. Warehouse `running` is only a candidate state; the classifier combines fresh transactional progress and structured log events to derive `active`, `stalled`, `unknown`, or neutral `terminal-drift` state.

The presenter owns operational status, attention overlap, cohort merging, chip text/classes, and QML-ready collections. Active runs with result issues belong to both active and attention collections but occur once in `monitorRuns`. Terminal drift is excluded from operational attention.

Snapshots are private atomic cache files. Source errors retain the last good run data. Material-change detection ignores query timestamps and latency for Waybar signaling, while both Waybar and QML independently derive cache staleness from `generatedAt`.

Waybar and QML never access PostgreSQL or benchmark logs directly. The application does not import or invoke the benchmark Python environment.
