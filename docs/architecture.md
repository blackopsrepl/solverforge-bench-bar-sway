# Architecture

`solverforge-bench-bar` has five layers:

1. Ruby CLI entrypoint.
2. Read-only PostgreSQL and bounded run-log adapters.
3. Pure run-state classification and presentation.
4. Atomic cached JSON state under `~/.local/state/solverforge-bench-bar`.
5. QuickShell modal plus cached-state Waybar renderer.

`psql` is the warehouse boundary. The configured PostgreSQL URL is decomposed into libpq environment variables so credentials never appear in process arguments, and every session is forced into read-only transactions with short timeouts. Log inspection accepts only readable files resolving beneath the run's recorded repository root and never persists raw tails.

Waybar and QML never access PostgreSQL or benchmark logs directly. The application does not import or invoke the benchmark Python environment.
