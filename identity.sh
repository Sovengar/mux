# Resolve the enclosing mux identity for a keymap-launched process.
#
# A process started by a kitty keymap has no HERDR_* / TUIOS_* / TMUX env, and
# its cwd is the kitty window cwd (often /), not the cwd of the pane the user is
# looking at. Sourcing this file exports the current herdr pane and its
# directory (MUX_PANE_CWD) so `mux` presents the command in the right place.
# Safe to source more than once.
if [ -z "${MUX_PANE_CWD:-}" ] && command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
	_info=$(herdr pane current 2>/dev/null) || _info=
	if [ -n "${_info:-}" ]; then
		pane=$(printf '%s' "$_info" | jq -r '.result.pane.pane_id // empty')
		MUX_PANE_CWD=$(printf '%s' "$_info" | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty')
		[ -n "${MUX_PANE_CWD:-}" ] && export MUX_PANE_CWD
		if [ -n "$pane" ] && [ -z "${HERDR_PANE_ID:-}" ]; then
			export HERDR_ENV=1
			export HERDR_PANE_ID=$pane
		fi
	fi
	unset _info pane
fi
