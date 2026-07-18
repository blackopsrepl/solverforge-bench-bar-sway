# Installation

Runtime requirements are Ruby, `psql`, QuickShell, and Waybar. `qmllint` is required by the deterministic validation gate.

Validate, install the standalone application, and create the config only when absent:

```bash
make check
make configure-user
```

`configure-user` depends on `install`, so a separate `make install` is unnecessary. It installs the application under `~/.local/share/solverforge-bench-bar/`, links `~/.local/bin/solverforge-bench-bar`, and preserves any existing `~/.config/solverforge-bench-bar/config.json`.

Install the SolverForge Linux wrapper after its managed Waybar module is present:

```bash
make install-solverforge-linux-integration
```

This target installs only `solverforge-waybar-benchbar` into the SolverForge Linux managed `bin` directory. The `custom/benchbar` module, style, and companion-daemon supervisor must already be present in the managed default layer under `~/.local/share/solverforge/`. The files under `~/.config/waybar` are symlinks and must not be edited directly.

`make check-live-readonly` is deliberately separate from installation and deterministic validation because it contacts the configured warehouse. It still forces PostgreSQL read-only mode and returns nonzero on source failure.
