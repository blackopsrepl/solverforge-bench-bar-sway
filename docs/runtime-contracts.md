# Runtime Contracts

The Ruby runtime owns all files under `runtime.stateDir`. The directory is mode `0700`; JSON state and lock files are mode `0600`.

`snapshot.json` uses snapshot schema version `1`, independent from application version `0.1.0` and config schema version `1`. It contains:

- `generatedAt` and presenter-owned global `status`.
- `source`: status, query/success timestamps, latency, and a redacted error.
- `runs`: normalized warehouse-running candidates with derived liveness evidence.
- `cohortRuns`: independently fetched terminal siblings for the latest nightly cohort.
- `recentRuns`: the generic bounded terminal history.
- `summary`: aggregate counts, including overlapping active and attention run counts plus neutral terminal drift.
- `view`: chip content and QML-ready headline, cohort, monitor, recent, drift, staleness, and source models.

It never contains raw database credentials, raw command arguments, raw log tails, or unrestricted filesystem paths.

`ui.json` has the shape:

```json
{"open": false, "requestedAt": ""}
```

`state-event.json` changes after snapshot or UI writes so QuickShell can reload both files.

`daemon.lock` enforces one daemon per state directory. `refresh.lock` serializes manual and daemon refreshes. All JSON writes replace their targets atomically.

On source failure, the runtime retains the previous run collections when available, replaces `source` with redacted failure details, and presents `source-error`. Without usable cached data, the chip text becomes `SFB err`; otherwise cached counts remain visible with source-error classes and tooltip detail.

Waybar and QML calculate staleness from `generatedAt` and `display.staleAfterSeconds`. This makes a cached active snapshot visibly stale even when no daemon remains to write another snapshot. Source query timestamps and latency are excluded from material Waybar change detection.

The Waybar payload has the standard shape:

```json
{"text":"SFB 1 !3","tooltip":"...","class":["benchbar","warning","active","has-attention"]}
```

The attention suffix counts runs and may overlap the active count. Waybar rendering reads cached state only.
