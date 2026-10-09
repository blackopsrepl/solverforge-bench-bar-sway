# solverforge-bench-bar-sway Wireframe

This document defines the shipped Waybar chip, QuickShell modal, CLI, and cached-state contract.

The project is named `solverforge-bench-bar-sway`; its installed runtime command and path family remain `solverforge-bench-bar`.

- Application version: `0.1.2`.
- Config schema version: `1`.
- Snapshot schema version: `1`.

The three versions are independent; `SolverForgeBenchBar::VERSION` owns the application version.

## Scope

The application observes `solverforge-bench`; it never controls it. Refresh work runs a static read-only PostgreSQL query for bounded running candidates, an independently bounded current-nightly cohort, and bounded recent terminal runs, then inspects bounded tails of log paths recorded for running candidates. Waybar and QML consume cached JSON only.

## Waybar Chip

```text
SFB ...       loading
SFB idle      no active candidate
SFB 1         one observed active run
SFB 1 !1      one active run that also needs attention
SFB 1 !3      one active run and three runs needing attention
SFB !3        no active run and three runs needing attention
SFB err       no usable source state
```

The attention suffix counts runs, not result rows. Active and attention membership may overlap; a failing active run appears once in the monitor while contributing to both counts.

The tooltip includes current suite, instance, solver, nominal limit, elapsed and watchdog timing, persisted rows, bounded attention details, and neutral terminal-drift diagnostics. When a source refresh fails but cached data remains usable, the chip retains its cached counts while source-error classes and tooltip text expose the failure. A stale cache likewise retains its cached text while using stale classes and labels.

## QuickShell Modal

```text
Full-screen transparent overlay

  +--------------------------------------------------------------------+
  | SFB  SolverForge Bench        <status>       Refresh       Close   |
  |      read-only warehouse and run-log monitor                       |
  +--------------------------------------------------------------------+
  | active | cohort suites | persisted rows | attention                |
  +--------------------------------------------------------------------+
  | CURRENT NIGHTLY COHORT                                             |
  | [CVRP active] [Employee completed] [Job shop completed]             |
  +--------------------------------------------------------------------+
  | RUN MONITOR                                                        |
  | CVRP  active     case 95  trial 8/24      2,287 rows               |
  | X-n895-k37 / solverforge / 60s       elapsed 34s / watchdog 75s    |
  | [watchdog rail] run errors 95 watchdog 0 validation 102            |
  |                 infeasible 0 fair-start 0 wall-time 0              |
  | ... active, stalled, or unknown live rows ...                       |
  +--------------------------------------------------------------------+
  | RECENT RUNS                                                        |
  +--------------------------------------------------------------------+
```

Refresh and close are the only modal actions. Escape and an overlay click also close the modal through a runner independent from refresh. CLI toggle support changes only modal visibility. There are no stop, retry, launch, cleanup, or repair actions.

## Run States

- `active`: warehouse running plus fresh log/result evidence.
- `terminal-drift`: warehouse still running while the log records terminal completion or failure.
- `stalled`: activity has exceeded the current watchdog-derived freshness window.
- `unknown`: the referenced log cannot provide enough safe evidence.
- `completed`: terminal warehouse completion in cohort and recent-run data.
- `failed`: terminal warehouse failure in cohort and recent-run data.

Terminal drift is warehouse consistency evidence, not a live execution state. Drift rows are excluded from the live run list, chip attention count, and global operational state; the neutral stale-row count remains available for diagnosis.

## Global Status

- `loading`: no cached snapshot is available yet.
- `idle`: no operational candidate is active or needs attention.
- `active`: at least one operational candidate is active and none needs attention.
- `warning`: at least one operational candidate needs attention, including an active run with nonzero issue counters.
- `source-error`: PostgreSQL refresh failed; the last good run data remains cached when available.
- `stale`: `generatedAt` has crossed `display.staleAfterSeconds`, even if the daemon is no longer running.

## Snapshot Contract

```json
{
  "snapshotVersion": 1,
  "generatedAt": "2026-07-18T14:00:00Z",
  "status": "warning",
  "source": {
    "status": "ok",
    "queriedAt": "2026-07-18T14:00:00Z",
    "lastSuccessAt": "2026-07-18T14:00:00Z",
    "latencyMs": 12,
    "error": null
  },
  "runs": [],
  "cohortRuns": [],
  "recentRuns": [],
  "summary": {},
  "view": {}
}
```

`runs` contains normalized running candidates, `cohortRuns` contains independently fetched terminal siblings for the latest nightly cohort, and `recentRuns` contains the generic bounded terminal history. `summary` and `view` are presenter-owned; QML renders `view` rather than reclassifying runs.

The runtime strips database URLs, raw command arguments, raw log tails, and unrestricted filesystem paths before writing state. Source-error snapshots replace source diagnostics but retain the last good run collections when available.

## Files

Under `~/.local/state/solverforge-bench-bar/`:

- `snapshot.json`: normalized run state and presenter view.
- `ui.json`: modal visibility state.
- `state-event.json`: watched reload marker.
- `daemon.lock`: singleton daemon lock.
- `refresh.lock`: serialized refresh lock.

The directory is mode `0700`; JSON state and lock files are mode `0600`. JSON writes are atomic. `state-event.json` is the single QML reload marker, and timestamp/latency-only source changes do not trigger a material Waybar repaint.

## CLI

```text
solverforge-bench-bar help
solverforge-bench-bar config init|validate
solverforge-bench-bar snapshot
solverforge-bench-bar refresh
solverforge-bench-bar daemon [--once]
solverforge-bench-bar panel
solverforge-bench-bar ui open|close|toggle|status
solverforge-bench-bar waybar render|refresh|panel
```

`--config PATH` selects a config. `--format json` enables JSON output where supported, `--pretty` formats JSON, `--once` belongs to `daemon`, and `-h`/`--help` prints usage. Unknown options fail instead of falling through to a long-running command.

`snapshot` always performs a read-only refresh and prints JSON. `refresh` performs the same refresh and prints only when JSON format is requested. `waybar render` reads cached state only; `waybar refresh` performs source observation; `waybar panel` opens the modal.
