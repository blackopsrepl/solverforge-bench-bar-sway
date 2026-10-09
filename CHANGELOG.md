# Changelog

All notable changes to this project will be documented in this file. See [commit-and-tag-version](https://github.com/absolute-version/commit-and-tag-version) for commit guidelines.

## [0.1.2](https://github.com/blackopsrepl/solverforge-bench-bar-sway/compare/v0.1.1...v0.1.2) (2026-10-09)


### Bug Fixes

* **version:** assert the released version contract, not an unreleased one ([79ef6bf](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/79ef6bf20922e3c20c91cc597c59dd2776a1532e))

## 0.1.1 (2026-09-17)


### Features

* **cli:** expose read-only monitor commands ([44c5a9f](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/44c5a9f19ca81bf4d49aa87a56a23273658c6711))
* **config:** add bounded private monitor settings ([3866503](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/38665038a7f2aa84cec2b39cbea3030bc7e50b72))
* **linux:** add managed Waybar launcher ([2f6727b](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/2f6727b69d75581bd04a91f6d0036127c11c70ec))
* **logs:** inspect bounded benchmark activity ([726cb54](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/726cb54cef7ff5c42f703f0493c1cd264b4b8c47))
* **runtime:** cache resilient monitor snapshots ([d596542](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/d596542bf79ac769c27e1de0fab5a799588f728f))
* **source:** query benchmark warehouse read-only ([3b031cc](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/3b031ccee860ae7b8f5d7bc9e69a4d5ab8cc663e))
* **state:** classify and present benchmark health ([9183874](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/91838745a2ef2a7d4dc7824168f6cc05d1b0ded7))
* **ui:** add real-time QuickShell benchmark panel ([043178b](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/043178b9c49773a86b73b21ab37b233728518098))
* **ui:** square the panel and add motion polish ([28fc434](https://github.com/blackopsrepl/solverforge-bench-bar-sway/commit/28fc434806cbaa407cc22d03b10180503dca795d))

## 0.1.0 - Unreleased

### Added

- Read-only Ruby daemon for bounded PostgreSQL and structured run-log observation.
- Cached Waybar chip and Fira Code QuickShell modal with live run, nightly cohort, terminal history, issue-counter, elapsed, and watchdog detail.
- Strict CLI for config validation, refresh, snapshot, modal state, cached Waybar rendering, and one-shot source checks.
- SolverForge Linux managed-layer wrapper for `custom/benchbar` actions.

### Changed

- Named the repository project `solverforge-bench-bar-sway` while preserving `solverforge-bench-bar` as its installed runtime identity.

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
