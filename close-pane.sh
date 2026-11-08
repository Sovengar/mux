#!/bin/bash
# Close the focused herdr pane, for a terminal keymap that shadows herdr's own
# close_pane binding.
set -u

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

[ -n "${HERDR_PANE_ID:-}" ] || {
	printf 'close-pane.sh: no herdr pane in this terminal\n' >&2
	exit 1
}

herdr pane close "$HERDR_PANE_ID"
