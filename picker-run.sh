#!/bin/bash
# Run a picker in a mux overlay, then present the chosen command on its own layer.
#
# Design: the picker never runs the application. It only prints one line
#
#     LAYOUT<TAB>COMMAND
#
# where LAYOUT is pane|tab|overlay|multi[:LABEL], and COMMAND is a shell command
# line. For `multi`, COMMAND is a pipe-separated pane list:
# CMD[@SIZE:POSITION]|CMD|...
# This script waits for the picker overlay to finish, then hands the command to
# `mux` with that layout, so every app opens on its own layer.
#
# The legacy `popup` and `popup:WIDTHxHEIGHT` layouts are accepted and mapped to
# overlay: the herdr popup placement redraws the whole window on each key, which
# makes any TUI unusable, so nothing asks for a popup any more.
#
# Usage: picker-run.sh LABEL PICKER [WIDTH] [HEIGHT] [PICKER ARG...]
set -u

label=${1:?usage: picker-run.sh LABEL PICKER [WIDTH] [HEIGHT] [PICKER ARG...]}
picker=${2:?usage: picker-run.sh LABEL PICKER [WIDTH] [HEIGHT] [PICKER ARG...]}
shift 2

# The optional WIDTH/HEIGHT arguments are kept for call compatibility and
# ignored: an overlay takes the pane size, so there is nothing to size.
case ${1:-} in
*% | *[0-9])
	shift
	shift || true
	;;
esac

[ -f "$picker" ] || {
	printf 'picker-run.sh: picker not found: %s\n' "$picker" >&2
	exit 1
}

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

plan=$(mktemp -u).plan
mkfifo "$plan" || exit 1
trap 'rm -f "$plan"' EXIT

# The picker writes its choice to the fifo. Reading it blocks until the overlay
# exits, which also avoids opening a second layer while the first closes.
workdir=${MUX_PANE_CWD:-$PWD}
# $1 and $2 belong to the inner sh, so they must stay unexpanded here.
# shellcheck disable=SC2016
mux --layout overlay --label "$label" --cwd "$workdir" -- \
	sh -c 'exec bash "$1" > "$2"' _ "$picker" "$plan"

exec 3<"$plan"
IFS=$'\t' read -r pick_layout pick_cmd <&3 || true
exec 3<&-

[ -n "${pick_layout:-}" ] && [ -n "${pick_cmd:-}" ] || exit 0

case $pick_layout in
pane | tab | overlay) ;;
multi) multi_label=multi ;;
multi:*) multi_label=${pick_layout#multi:} pick_layout=multi ;;
popup | popup:*) pick_layout=overlay ;;
*)
	printf 'picker-run.sh: invalid layout from picker: %s\n' "$pick_layout" >&2
	exit 1
	;;
esac

if [ "$pick_layout" = multi ]; then
	panes=()
	_old_ifs=$IFS
	IFS='|'
	for spec in $pick_cmd; do
		panes+=(--pane "$spec")
	done
	IFS=$_old_ifs
	[ "${#panes[@]}" -gt 0 ] || exit 0
	exec mux multi --cwd "$workdir" --label "${multi_label:-multi}" "${panes[@]}"
fi

present_label=${pick_cmd%% *}
present_label=${present_label##*/}
printf 'mux: presenting %s in a %s\n' "$present_label" "$pick_layout" >&2

exec mux --layout "$pick_layout" --label "$present_label" --cwd "$workdir" -- sh -c "$pick_cmd"
