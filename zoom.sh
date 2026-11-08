#!/bin/bash
# Zoom (maximise) one pane.
#
# Usage: zoom.sh [on|off|toggle] [PANE_ID]
#
# Defaults: toggle the focused pane. This is the one place that knows how each
# stack zooms; mux --layout overlay calls it after splitting, so the overlay
# layout stays a mux concept while the mechanism stays here.
set -u

mode=${1:-toggle}
case $mode in
toggle | on | off) ;;
*)
	# Allow `zoom.sh <pane_id>` as a shorthand for `zoom.sh toggle <pane_id>`.
	case $mode in
	w[0-9]* | *:* ) pane_id=$mode mode=toggle ;;
	*)
		printf 'zoom.sh: unknown mode: %s\n' "$mode" >&2
		exit 2
		;;
	esac
	;;
esac

pane_id=${pane_id:-${2:-}}

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"
pane_id=${pane_id:-${HERDR_PANE_ID:-}}

# tuios has no zoom verb: it exposes a ToggleZoom UI command, so only toggle is
# possible. The daemon runs it on the attached client's focused pane.
if command -v tuios >/dev/null 2>&1 &&
	[ -n "${TUIOS_ENV:-}${TUIOS_SESSION:-}${TUIOS_PANE_ID:-}" ]; then
	if [ "$mode" != toggle ]; then
		printf 'zoom.sh: tuios only supports toggle\n' >&2
		exit 1
	fi
	tuios call run-command '{"command":"toggle_zoom"}' >/dev/null
	exit
fi

if command -v herdr >/dev/null 2>&1 && [ -n "${pane_id:-}" ]; then
	case $mode in
	on) herdr pane zoom "$pane_id" --on ;;
	off) herdr pane zoom "$pane_id" --off ;;
	*) herdr pane zoom "$pane_id" --toggle ;;
	esac
	exit
fi

if [ -n "${TMUX:-}" ]; then
	# tmux has a single zoomed pane per window: target by pane id.
	_pane=${pane_id#*:}
	tmux resize-pane -Z -t "$_pane"
	exit
fi

printf 'zoom.sh: no zoom support for this backend\n' >&2
exit 1
