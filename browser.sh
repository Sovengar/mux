#!/bin/bash
# Open the terminal browser in a right split of the focused pane.
#
# Started from a kitty keymap: identity.sh supplies the pane directory and the
# herdr identity, mux does the split and runs the browser inside it.
set -u

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

exec mux --layout pane --direction right --label browser \
	--cwd "${MUX_PANE_CWD:-$PWD}" -- terminal-browser open
