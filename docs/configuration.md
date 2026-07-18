# Configuration

The default config path is `~/.config/solverforge-bench-bar/config.json`.

- `source.databaseUrl`: PostgreSQL connection string. `SOLVERFORGE_BENCH_BAR_DATABASE_URL` overrides it without changing the file.
- `source.psqlCommand`: `psql` executable.
- `source.connectTimeoutSeconds`: bounded connection timeout.
- `source.statementTimeoutMilliseconds`: PostgreSQL statement timeout.
- `source.lockTimeoutMilliseconds`: PostgreSQL lock timeout.
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

Operational commands reject invalid bounds before using the config. The config and its same-directory atomic-write temporary file are created with mode `0600`.
