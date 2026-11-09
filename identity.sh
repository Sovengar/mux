# Resolve the enclosing mux identity for a keymap-launched process.
#
# A process started by a kitty keymap or by a herdr key command has no pane
# context of its own: no HERDR_PANE_ID, sometimes no TMUX, and a cwd that is the
# terminal's or the server's, not the directory the user is looking at. Sourcing
# this file exports the current herdr pane and its directory (MUX_PANE_CWD) so
# `mux` presents the command in the right place.
# Safe to source more than once.
if [ -z "${MUX_PANE_CWD:-}" ]; then
	_pane=${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}
	# Herdr hands a key command the pane it fired in. Prefer that over any API
	# guess: it is the pane the user is looking at.
	MUX_PANE_CWD=${HERDR_ACTIVE_PANE_CWD:-}
	_info=
	if [ -z "${_pane:-}" ] && command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
		# No pane in the environment: a keymap-launched process has no pane
		# context, so `pane current` answers pane_not_found. Fall back to the pane
		# the server reports as focused, which is the one the user is looking at.
		_info=$(herdr pane current 2>/dev/null) || _info=
		_pane=$(printf '%s' "${_info:-}" | jq -r '.result.pane.pane_id // empty' 2>/dev/null) || _pane=
		if [ -z "${_pane:-}" ]; then
			_info=$(herdr pane list 2>/dev/null | jq -c '.result.panes[] | select(.focused) | {pane: .}' 2>/dev/null | head -n 1) || _info=
			_pane=$(printf '%s' "${_info:-}" | jq -r '.pane.pane_id // empty' 2>/dev/null) || _pane=
		fi
	fi
	[ -n "${MUX_PANE_CWD:-}" ] ||
		MUX_PANE_CWD=$(printf '%s' "${_info:-}" | jq -r '(.result.pane // .pane) | .foreground_cwd // .cwd // empty' 2>/dev/null) ||
		MUX_PANE_CWD=
	[ -n "${MUX_PANE_CWD:-}" ] && export MUX_PANE_CWD
	if [ -n "${_pane:-}" ] && [ -z "${HERDR_PANE_ID:-}" ]; then
		export HERDR_ENV=1
		export HERDR_PANE_ID="$_pane"
	fi
	unset _info _pane
fi
