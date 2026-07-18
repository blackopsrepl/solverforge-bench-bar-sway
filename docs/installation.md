# Installation

Validate and install the standalone application:

```bash
make check
make install
make configure-user
```

Install the SolverForge Linux wrapper after its managed Waybar module is present:

```bash
make install-solverforge-linux-integration
```

The managed Waybar config, style, and companion-daemon supervisor live under `~/.local/share/solverforge/`. The files under `~/.config/waybar` are symlinks and must not be edited directly.

