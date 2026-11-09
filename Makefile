# mux lives in this repo and is used through PATH: no target requires you to
# cd here. `make install` only puts a symlink on PATH, so edits here are live.

PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
MUX     := $(CURDIR)/mux

TESTS   := tests/mux-scratch-tmux.sh tests/mux-tmux-shell.sh tests/mux-tab.sh

.PHONY: help install uninstall test lint check

help:
	@printf '%s\n' \
	  'make install       symlink mux into $(BINDIR)' \
	  'make uninstall     remove that symlink' \
	  'make test          run the behaviour tests' \
	  'make lint          shellcheck every script' \
	  'make check         parse every script (sh -n)'

install:
	@mkdir -p "$(BINDIR)"
	ln -sfn "$(MUX)" "$(BINDIR)/mux"
	@printf 'installed %s -> %s\n' "$(BINDIR)/mux" "$(MUX)"

uninstall:
	@if [ -L "$(BINDIR)/mux" ]; then rm -f "$(BINDIR)/mux" && printf 'removed %s\n' "$(BINDIR)/mux"; fi

test:
	@set -e; for t in $(TESTS); do printf '== %s\n' "$$t"; sh "$$t"; done

lint:
	@command -v shellcheck >/dev/null 2>&1 || { printf 'shellcheck not installed\n' >&2; exit 1; }
	shellcheck -s sh mux
	shellcheck -s bash *.sh
	shellcheck -s sh -S warning tests/*.sh

check:
	@set -e; for f in mux tests/*.sh; do sh -n "$$f"; done; \
	for f in *.sh; do bash -n "$$f"; done; printf 'parse ok\n'
