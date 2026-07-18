# CLI

```text
solverforge-bench-bar config init|validate
solverforge-bench-bar snapshot
solverforge-bench-bar refresh
solverforge-bench-bar daemon [--once]
solverforge-bench-bar panel
solverforge-bench-bar ui open|close|toggle|status
solverforge-bench-bar waybar render|refresh|panel
```

Global flags are `--config PATH`, `--format text|json`, `--pretty`, and `--once`.

`snapshot`, `refresh`, and the daemon may perform read-only source observation. `waybar render` reads cached state only.

