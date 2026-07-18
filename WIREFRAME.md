# solverforge-bench-bar Wireframe

This document defines the shipped Waybar chip, QuickShell modal, CLI, and cached-state contract.

## Scope

The application observes `solverforge-bench`; it never controls it. Refresh work may run a static read-only PostgreSQL query and inspect bounded tails of log paths recorded in the warehouse. Waybar and QML consume cached JSON only.

## Waybar Chip

```text
SFB ...       loading
SFB idle      no active candidate
SFB 1         one observed active run
SFB 1 !3      one active run and three rows needing attention
SFB !3        no active run and three rows needing attention
SFB err       no usable source state
```

The tooltip includes current suite, instance, solver, nominal limit, elapsed watchdog time, persisted rows, and bounded attention details.

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
  | [watchdog rail]   run errors 95  validation 102  fair-start 0      |
  | ... active, stalled, or unknown live rows ...                       |
  +--------------------------------------------------------------------+
  | RECENT RUNS                                                        |
  +--------------------------------------------------------------------+
```

Refresh and close/toggle are the only actions.

## Observed States

- `active`: warehouse running plus fresh log/result evidence.
- `completed`: terminal warehouse completion.
- `failed`: terminal warehouse failure.
- `terminal-drift`: warehouse still running while the log records terminal completion or failure.
- `stalled`: activity has exceeded the current watchdog-derived freshness window.
- `unknown`: the referenced log cannot provide enough safe evidence.
- `source-error`: PostgreSQL refresh failed; the last good run data stays cached.

Terminal drift is warehouse consistency evidence, not a live execution state. Drift rows are excluded from the live run list, chip attention count, and global operational state; the neutral stale-row count remains available for diagnosis.

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
    "error": null
  },
  "runs": [],
  "cohortRuns": [],
  "recentRuns": [],
  "summary": {},
  "view": {}
}
```

The runtime strips database URLs, raw command arguments, raw log tails, and unrestricted filesystem paths before writing state.

## Files

Under `~/.local/state/solverforge-bench-bar/`:

- `snapshot.json`: normalized run state and presenter view.
- `ui.json`: modal visibility state.
- `state-event.json`: watched reload marker.
- `daemon.lock`: singleton daemon lock.
- `refresh.lock`: serialized refresh lock.

## CLI

```text
solverforge-bench-bar config init|validate
solverforge-bench-bar snapshot
solverforge-bench-bar refresh
solverforge-bench-bar daemon [--once]
solverforge-bench-bar panel
solverforge-bench-bar ui open|close|toggle|status
solverforge-bench-bar waybar render|refresh|panel
```
