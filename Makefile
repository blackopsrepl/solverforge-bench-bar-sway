PREFIX ?= $(HOME)/.local
APP_HOME ?= $(PREFIX)/share/solverforge-bench-bar
BIN_DIR ?= $(PREFIX)/bin
CONFIG_PATH ?= $(HOME)/.config/solverforge-bench-bar/config.json
SOLVERFORGE_PATH ?= $(HOME)/.local/share/solverforge
RUBY ?= /usr/bin/ruby
QMLLINT ?= /usr/bin/qmllint

.PHONY: help test syntax syntax-check smoke qml-lint qml-check check check-live-readonly install configure-user install-solverforge-linux-integration release-check

help:
	@printf '%s\n' \
		'solverforge-bench-bar-sway targets:' \
		'  syntax                                Validate Ruby and Bash syntax' \
		'  test                                  Run deterministic Ruby tests' \
		'  smoke                                 Exercise the CLI against isolated fixtures' \
		'  qml-lint                              Validate the QuickShell QML' \
		'  check                                 Run tests and static validation' \
		'  check-live-readonly                   Exercise the forced-read-only live source' \
		'  install                               Install the standalone app under ~/.local' \
		'  configure-user                        Create the user config when absent' \
		'  install-solverforge-linux-integration Install the managed-layer Waybar wrapper' \
		'  release-check                         Alias for the full deterministic check'

test:
	"$(RUBY)" test/run.rb

syntax: syntax-check

syntax-check:
	find bin lib test -type f -name '*.rb' -print -exec "$(RUBY)" -wc {} \;
	bash -n packaging/solverforge-linux/solverforge-waybar-benchbar

smoke:
	"$(RUBY)" test/smoke.rb

qml-lint: qml-check

qml-check:
	"$(QMLLINT)" frontend/quickshell/shell.qml

check: syntax test smoke qml-lint

check-live-readonly:
	"$(RUBY)" bin/solverforge-bench-bar daemon --once --config "$(CONFIG_PATH)" >/dev/null

install:
	mkdir -p "$(APP_HOME)" "$(BIN_DIR)"
	cp -R bin lib frontend docs packaging README.md WIREFRAME.md AGENTS.md CHANGELOG.md Makefile "$(APP_HOME)/"
	chmod +x "$(APP_HOME)/bin/solverforge-bench-bar"
	ln -sfn "$(APP_HOME)/bin/solverforge-bench-bar" "$(BIN_DIR)/solverforge-bench-bar"

configure-user: install
	@test -f "$(CONFIG_PATH)" || "$(BIN_DIR)/solverforge-bench-bar" config init --config "$(CONFIG_PATH)" >/dev/null

install-solverforge-linux-integration:
	mkdir -p "$(SOLVERFORGE_PATH)/bin"
	cp packaging/solverforge-linux/solverforge-waybar-benchbar "$(SOLVERFORGE_PATH)/bin/solverforge-waybar-benchbar"
	chmod +x "$(SOLVERFORGE_PATH)/bin/solverforge-waybar-benchbar"

release-check: check
