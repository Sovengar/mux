#!/bin/bash
# Open a new shell pane next to the focused pane.
#
# Usage: split.sh right|down|left|up
#
# Started from a kitty keymap: identity.sh supplies the pane directory and the
# herdr identity, mux does the split and leaves a plain shell in the new pane.
set -u

direction=${1:-right}
case $direction in
right | down | left | up) ;;
*)
	printf 'split.sh: unknown direction: %s\n' "$direction" >&2
	exit 2
	;;
esac

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

exec mux --layout pane --direction "$direction" --label shell \
	${HERDR_PANE_ID:+--pane "$HERDR_PANE_ID"} \
	--cwd "${MUX_PANE_CWD:-$PWD}"
