# CLI

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

Common options are `--config PATH`, `--format text|json`, `--pretty`, and `-h`/`--help`. `--once` is a daemon option. Unknown options fail with exit status `1`; in particular, a misspelled `--once` cannot accidentally start the long-running daemon.

- `config init` writes normalized defaults to the selected path and replaces an existing file there; the `make configure-user` wrapper is the non-overwriting first-install path. `config validate` reports every validation error without first rejecting the file.
- `snapshot` performs a read-only source refresh and always prints the resulting JSON.
- `refresh` performs the same refresh and prints only when `--format json` is requested.
- `daemon` refreshes at `runtime.refreshSeconds`; `daemon --once` performs one refresh and returns nonzero when source observation fails.
- `panel` writes open UI state and launches the configured QuickShell instance.
- `ui open|close|toggle|status` changes or reads modal visibility. JSON output is available with `--format json`.
- `waybar render` reads cached state only and always emits the Waybar JSON payload.
- `waybar refresh` performs read-only source observation; `waybar panel` opens the modal.

`--pretty` affects JSON formatting only. Live PostgreSQL and log observation is confined to `snapshot`, `refresh`, the daemon, and `waybar refresh`.
