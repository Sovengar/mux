# mux lives in this repo and is used through PATH: no target requires you to
# cd here. `make install` only puts a symlink on PATH, so edits here are live.

PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
LIBDIR  ?= $(PREFIX)/lib/mux
MUX     := $(CURDIR)/mux

TESTS   := tests/mux-scratch-tmux.sh tests/mux-tmux-shell.sh

.PHONY: help install install-lib uninstall test lint check

help:
	@printf '%s\n' \
	  'make install       symlink mux into $(BINDIR)' \
	  'make install-lib   symlink this directory at $(LIBDIR) (for configs that' \
	  '                   name a helper path directly, e.g. kitty keymaps)' \
	  'make uninstall     remove those symlinks' \
	  'make test          run the behaviour tests' \
	  'make lint          shellcheck every script' \
	  'make check         parse every script (sh -n)'

install:
	@mkdir -p "$(BINDIR)"
	ln -sfn "$(MUX)" "$(BINDIR)/mux"
	@printf 'installed %s -> %s\n' "$(BINDIR)/mux" "$(MUX)"

install-lib:
	ln -sfn "$(CURDIR)" "$(LIBDIR)"
	@printf 'installed %s -> %s\n' "$(LIBDIR)" "$(CURDIR)"

uninstall:
	@for f in "$(BINDIR)/mux" "$(LIBDIR)"; do \
	  if [ -L "$$f" ]; then rm -f "$$f" && printf 'removed %s\n' "$$f"; fi; \
	done

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
