# Configuration

The default config path is `~/.config/solverforge-bench-bar/config.json`.

- `version`: config schema version (`1`), independent from application version `0.1.2` and snapshot schema version `1`.
- `source.databaseUrl`: PostgreSQL connection string. `SOLVERFORGE_BENCH_BAR_DATABASE_URL` overrides it without changing the file.
- `source.psqlCommand`: `psql` executable.
- `source.connectTimeoutSeconds`: bounded connection timeout.
- `source.statementTimeoutMilliseconds`: PostgreSQL statement timeout.
- `source.lockTimeoutMilliseconds`: PostgreSQL lock timeout.
- `source.commandTimeoutSeconds`: outer timeout for the `psql` process.
- `source.activeRunLimit`, `source.recentRunLimit`: bounded result sets.
- `source.logTailBytes`: maximum bytes inspected from each active run log.
- `runtime.stateDir`: private cached-state directory.
- `runtime.refreshSeconds`: daemon cadence.
- `runtime.waybarSignal`: RTMIN signal used for immediate repaint.
- `runtime.quickShellCommand`, `runtime.quickShellShell`: QuickShell launcher and QML path.
- `display.staleAfterSeconds`: cached snapshot freshness boundary.
- `display.stallGraceSeconds`: grace added after a run's watchdog evidence.
- `display.maxTooltipRuns`: bounded tooltip detail.
- `display.cohortWindowSeconds`: start-time window for grouping nightly suite siblings.

The current-nightly terminal cohort is fetched independently from `source.recentRunLimit`, with an internal maximum of 100 rows. Active nightly candidates are merged into that cohort by the presenter.

## Validation Bounds

| Field | Accepted value |
|---|---:|
| `source.connectTimeoutSeconds` | at least 1 |
| `source.statementTimeoutMilliseconds` | at least 100 |
| `source.lockTimeoutMilliseconds` | at least 1 |
| `source.commandTimeoutSeconds` | at least 1 |
| `source.activeRunLimit` | 1–100 |
| `source.recentRunLimit` | 1–100 |
| `source.logTailBytes` | 4,096–4,194,304 |
| `runtime.refreshSeconds` | at least 1 |
| `runtime.waybarSignal` | 1–31 |
| `display.staleAfterSeconds` | at least 1 and not below `runtime.refreshSeconds` |
| `display.stallGraceSeconds` | at least 0 |
| `display.maxTooltipRuns` | 1–20 |
| `display.cohortWindowSeconds` | 1–600 |

Operational commands normalize and validate these bounds before use. `config validate` intentionally loads without the operational rejection step so it can report all issues. Empty runtime paths remain empty until validation rather than expanding to the current directory.

`config init` and all config saves create the same-directory atomic-write temporary file as mode `0600` before credentials are written, then install the final config as mode `0600`.
