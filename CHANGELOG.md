# Changelog

## 0.1.0 - Unreleased

### Added

- Read-only Ruby daemon for bounded PostgreSQL and structured run-log observation.
- Cached Waybar chip and Fira Code QuickShell modal with live run, nightly cohort, terminal history, issue-counter, elapsed, and watchdog detail.
- Strict CLI for config validation, refresh, snapshot, modal state, cached Waybar rendering, and one-shot source checks.
- SolverForge Linux managed-layer wrapper for `custom/benchbar` actions.

### Correctness

- Derived active, stalled, unknown, and terminal-drift states without treating warehouse `running` as proof of liveness.
- Fetched the current nightly cohort independently from generic recent history.
- Counted active runs with result failures as attention without duplicating monitor cards.
- Kept terminal drift neutral and excluded it from live alert state.
- Preserved QML scroll position across refreshes and derived staleness locally when refreshes stop.

### Safety

- Forced PostgreSQL read-only mode with bounded connection, statement, lock, and process timeouts.
- Bounded log-tail reads to paths resolving inside the recorded benchmark checkout.
- Validated runtime bounds before operational use and created config temporary files privately from their first write.
- Redacted database URLs, credentials, and filesystem paths from persisted diagnostics.
