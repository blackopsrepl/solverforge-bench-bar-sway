# solverforge-bench-bar

`solverforge-bench-bar` is a read-only Waybar and QuickShell companion for monitoring running `solverforge-bench` workloads in real time.

It uses a Ruby daemon to query persisted benchmark progress through a forced read-only PostgreSQL session, inspects bounded tails of the run logs already referenced by the warehouse, writes a cached JSON snapshot, renders a compact Waybar chip, and opens a detailed QuickShell modal.

It never launches, stops, retries, repairs, or otherwise mutates benchmarks.

## Runtime Shape

```text
PostgreSQL SELECT (read-only) --\
                                Ruby daemon -> snapshot.json -> Waybar
bounded run-log tails --------/               -> QuickShell
```

PostgreSQL supplies persisted run and result truth. Log events supply current solver activity and evidence for stale warehouse rows. Raw warehouse status and derived observed state remain separate.

## Commands

```bash
solverforge-bench-bar config init
solverforge-bench-bar config validate
solverforge-bench-bar snapshot --format json --pretty
solverforge-bench-bar refresh
solverforge-bench-bar daemon
solverforge-bench-bar daemon --once
solverforge-bench-bar panel
solverforge-bench-bar ui open|close|toggle|status
solverforge-bench-bar waybar render|refresh|panel
```

## State

- Config: `~/.config/solverforge-bench-bar/config.json`
- Runtime state: `~/.local/state/solverforge-bench-bar/`
- Installed application: `~/.local/share/solverforge-bench-bar/`
- User binary: `~/.local/bin/solverforge-bench-bar`

Waybar reads cached state only. Live PostgreSQL and log reads happen during `refresh`, `snapshot`, or daemon refresh work.

## Install

```bash
make check
make install
make configure-user
make install-solverforge-linux-integration
```

The SolverForge Linux Waybar module and daemon supervision live in its managed default layer. Do not edit symlinked files under `~/.config/waybar`.

## Validation

`make check` is deterministic and does not contact the live warehouse. Use `make check-live-readonly` only for the explicit forced-read-only live smoke.

See `WIREFRAME.md` for the shipped interface and runtime contract.

