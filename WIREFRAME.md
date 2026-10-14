# solverforge-bench-bar-sway Wireframe

This document defines the shipped Waybar chip, QuickShell modal, CLI, and cached-state contract.

The project is named `solverforge-bench-bar-sway`; its installed runtime command and path family remain `solverforge-bench-bar`.

- Application version: `0.5.0`.
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
Bounded bar drop-down (window surface = the card's rect + 6px halo)

                ┌ Waybar top strip ────────────────────────────┐
  (52px)        └──────────────────────────────────────────────┘
        ┌─────────────────────────────────────────────┐
        │ [!] diagnostics banner (ingest/stale)        │   ← only when a message is up
        │ SFB  SolverForge Bench      <status>   ⟨dot⟩ │
        │      read-only monitor    Refresh    Close   │
        ├──────────┬────────────┬────────────┬────────┤
        │ active   │ cohort     │ rows       │ attn   │
        ├──────────┴────────────┴────────────┴────────┤
        │ CURRENT NIGHTLY COHORT                       │
        │ [CVRP active] [Job shop completed]           │
        ├──────────────────────────────────────────────┤
        │ RUN MONITOR                                  │
        │ CVRP  active   case 95  trial 8/24           │
        │ ... live rows (scrolls inside the band) ...  │
        │ empty state: what appears here, how recorded │
        ├──────────────────────────────────────────────┤
        │ RECENT TERMINAL RUNS     [cue: scroll right] │
        │ [cvrp failed 87d ago 1,944 rows] ...         │
        └──────────────────────────────────────────────┘
        ▲ 6px shadow halo (dismiss strip) — desktop beneath and
          beside the card stays interactive (no scrim, no overlay)
```

The layer surface is anchored to only the top and left screen edges; the window is exactly the card plus the halo — full-screen it never is. Height is counted from the laid-out bands (banner 34 only while up, header 48, tiles 70, cohort 112/155, monitor flex 110→300, recent 92/72), floored at 640, capped at 860 and at the room between the bar and the screen edge; the width is content-fit (460 floor, 1120 cap). The card hangs 52px under the bar's top edge and leans left of center, on its chip's side.

Below the breakpoint predicates (`modal.width < 720`, `modal.height < 660`, now reading the card-sized window) the margins tighten and the fixed bands shrink; the monitor and history lists scroll within the card instead of pushing past it.

Refresh and close are the only modal actions. Escape, the Close button, and a click inside the window but outside the card all close the modal through a runner independent from refresh. The screen-wide outside-click dismissal of an overlay is not preserved — the bounded surface keeps the desktop beside it interactive, which is the family-standard trade. CLI toggle support changes only modal visibility. There are no stop, retry, launch, cleanup, or repair actions.

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
