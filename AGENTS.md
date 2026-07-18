# Repository Guidelines

## Product Contract

- `solverforge-bench-bar` is a strictly read-only Linux monitor for running `solverforge-bench` workloads.
- The supported stack is Ruby + QuickShell QML + Waybar, with a small Bash wrapper for SolverForge Linux integration.
- PostgreSQL and the run logs referenced by PostgreSQL are observation sources. They are never mutated.
- The human-facing UI is `frontend/quickshell/shell.qml`. Waybar is a compact cached-state chip and launcher.
- `snapshot.json`, `ui.json`, and `state-event.json` are the backend/frontend contract.
- Application version `0.1.0` is owned by `SolverForgeBenchBar::VERSION`; config schema `1` and snapshot schema `1` are independent compatibility contracts.

## Non-Interference Rules

- Never edit, build, install dependencies into, signal, stop, restart, or otherwise mutate the live `solverforge-bench` checkout from this project.
- Never issue PostgreSQL writes. The warehouse adapter must force `default_transaction_read_only=on` and use bounded connection, statement, and lock timeouts.
- Never invoke the benchmark Python environment or import benchmark modules. Use the existing warehouse schema and bounded run-log reads.
- Never expose stop, retry, cleanup, launch, or warehouse-repair controls in the CLI or UI.
- Never copy raw log tails or database connection strings into runtime state.
- Waybar rendering reads cached state only. Database queries and log inspection belong in refresh and daemon paths.

## Project Structure

- `bin/solverforge-bench-bar`: Ruby entrypoint.
- `lib/solverforge_bench_bar/core`: config, process, warehouse, redaction, log inspection, run-state, and formatting logic.
- `lib/solverforge_bench_bar/runtime`: daemon, state files, presenter, QuickShell control, and Waybar renderer.
- `frontend/quickshell/shell.qml`: the only human-facing UI.
- `packaging/solverforge-linux`: reproducible SolverForge Linux wrapper.
- `test`: deterministic tests using fixtures and temporary files only.
- `docs`, `README.md`, and `WIREFRAME.md`: operator, architecture, and shipped-interface contracts.
- `Makefile`: deterministic validation, installation, and explicit live-read-only gates.

## Architecture Rules

- Ruby only for the application backend. Do not add Python, TypeScript, Swift, Electron, or another UI stack.
- Use Ruby standard-library dependencies. `psql` is the external warehouse boundary.
- Preserve raw `warehouseStatus` separately from derived `observedState`.
- Treat a warehouse row marked `running` as a candidate, not proof of liveness.
- Derive liveness from transactional result progress plus bounded structured log evidence.
- Fetch current-nightly terminal siblings independently from the generic recent-run limit, then merge them with active nightly candidates in the presenter.
- Count an active run with result failures as both active and attention without duplicating its monitor card.
- Treat terminal drift as neutral warehouse-consistency evidence; exclude it from live attention and global operational status.
- Do not invent overall completion percentages when the warehouse does not contain a planned result count.
- Keep presenter output view-ready so QML does not reproduce backend classification rules.
- Derive cached-view staleness from `generatedAt` and `display.staleAfterSeconds`, including when the daemon stops.
- Keep config and state files mode `0600` and write them atomically.

## Versioning

- Keep `SolverForgeBenchBar::VERSION`, the current `CHANGELOG.md` heading, README, AGENTS, and WIREFRAME application-version statements aligned.
- Do not confuse application version `0.1.0` with config schema `1` or snapshot schema `1`.
- Do not mark a version released without a corresponding release action or tag; the current `0.1.0` line remains unreleased.

## SolverForge Linux Integration

- Edit the managed default layer under `~/.local/share/solverforge/`, never the symlinked `~/.config/waybar` files.
- Use Fira Code and the existing Hackerman palette and semantic warning/critical colors.
- The installed wrapper is `solverforge-waybar-benchbar`; the Waybar module is `custom/benchbar`.
- `make install-solverforge-linux-integration` installs the wrapper only; module placement, styling, and daemon supervision belong to the SolverForge Linux managed layer.

## Validation

Run:

```bash
make syntax
make test
make smoke
make qml-lint
make check
```

`make check` must not contact the live warehouse. `make check-live-readonly` is the explicit live smoke and must remain read-only.
