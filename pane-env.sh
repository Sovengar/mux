#!/bin/bash
# Give a command launched by a terminal keymap a mux identity, then present it
# as an overlay.
#
# A process launched from a kitty keymap has no HERDR_* / TUIOS_* / TMUX env, so
# `mux --layout overlay` can only fall back to backend=none and the command would
# run in a hidden background window. This script recovers the enclosing herdr
# pane (so the overlay still has a target) and then lets `mux` present the command
# as an overlay: the herdr.mux overlay pane under herdr, or a zoomed split.
#
# The herdr popup placement is not used here on purpose: while a popup pane is
# open herdr redraws the whole window on every keystroke, and that makes every
# full-screen TUI unusable.
#
# Usage: pane-env.sh LABEL [WIDTH] [HEIGHT] -- COMMAND [ARG...]
set -u

label=${1:?usage: pane-env.sh LABEL [WIDTH] [HEIGHT] -- COMMAND [ARG...]}
shift

width=90%
height=90%
case ${1:-} in
*% | *[0-9])
	width=$1
	shift
	height=${1:-90%}
	shift
	;;
esac
[ "${1:-}" = -- ] && shift

[ $# -gt 0 ] || {
	printf 'pane-env.sh: no command given\n' >&2
	exit 1
}

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

exec mux --layout overlay --label "$label" --width "$width" --height "$height" --cwd "${MUX_PANE_CWD:-$PWD}" -- "$@"
