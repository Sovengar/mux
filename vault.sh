#!/bin/bash
# Open the Obsidian vault in Neovim, launched from a terminal keymap.
#
# The vault root is $VAULT (see ~/.config/environment.d/vault.conf). A process
# started by a kitty keymap does not always inherit it, so the file is sourced
# as a fallback.
set -u

if [ -z "${VAULT:-}" ]; then
	conf=${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/vault.conf
	# shellcheck disable=SC1090
	[ -r "$conf" ] && . "$conf"
fi
: "${VAULT:?VAULT no esta definido: revisa ~/.config/environment.d/vault.conf}"

cd "$VAULT" || exit 1
exec "${EDITOR:-nvim}" .
