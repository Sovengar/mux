#!/bin/bash
# Open a new herdr tab in the directory of the focused pane.
#
# Started from a kitty keymap, so the cwd comes from identity.sh instead of the
# kitty window cwd.
set -u

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

herdr tab create --cwd "${MUX_PANE_CWD:-$PWD}" --focus
