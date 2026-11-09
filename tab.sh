#!/bin/bash
# Switch tabs inside the current herdr workspace.
#
# Usage: tab.sh next|prev|1..9
#
# next and prev wrap around the tab bar. A numbered tab that does not exist is
# an error, so a wrong keymap number never lands on an unrelated tab.
set -u

target=${1:-}
case $target in
next | prev | [1-9]) ;;
*)
	printf 'tab.sh: expected next, prev or a tab number 1-9: %s\n' "$target" >&2
	exit 2
	;;
esac

command -v herdr >/dev/null 2>&1 || {
	printf 'tab.sh: herdr is not installed\n' >&2
	exit 1
}
command -v jq >/dev/null 2>&1 || {
	printf 'tab.sh: herdr tab switching needs jq\n' >&2
	exit 1
}

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

_panes=$(herdr pane list 2>/dev/null) || _panes=
[ -n "$_panes" ] || {
	printf 'tab.sh: cannot read herdr panes\n' >&2
	exit 1
}

# The invoking pane names the workspace; a keymap-launched process has none, so
# identity.sh already recovered the focused pane, and the focused pane answers
# both questions when there is no HERDR_PANE_ID at all.
_pane_ws() {
	printf '%s' "$_panes" |
		jq -r --arg p "$1" '.result.panes[] | select(.pane_id == $p) | .workspace_id' |
		head -n 1
}
_pane_tab() {
	printf '%s' "$_panes" |
		jq -r --arg p "$1" '.result.panes[] | select(.pane_id == $p) | .tab_id' |
		head -n 1
}
_focused_pane() {
	printf '%s' "$_panes" | jq -r '.result.panes[] | select(.focused) | .pane_id' | head -n 1
}

_pane=${HERDR_PANE_ID:-}
[ -n "$_pane" ] || _pane=$(_focused_pane)

_ws=
[ -n "$_pane" ] && _ws=$(_pane_ws "$_pane")
[ -n "$_ws" ] || _ws=$(_pane_ws "$(_focused_pane)")
[ -n "$_ws" ] || {
	printf 'tab.sh: no herdr workspace in this terminal\n' >&2
	exit 1
}

_tabs=$(herdr tab list --workspace "$_ws" 2>/dev/null) || _tabs=
[ -n "$_tabs" ] || {
	printf 'tab.sh: cannot read herdr tabs in workspace %s\n' "$_ws" >&2
	exit 1
}

# Positional order is the tab bar order: tab1 is the leftmost tab, whatever
# herdr reports in `number`.
_tab_ids=$(printf '%s' "$_tabs" | jq -r '.result.tabs | sort_by(.number) | .[].tab_id') || _tab_ids=
_count=$(printf '%s\n' "$_tab_ids" | awk 'NF { n++ } END { print n + 0 }')
[ "$_count" -gt 0 ] || {
	printf 'tab.sh: workspace %s has no tabs\n' "$_ws" >&2
	exit 1
}

_cur=
[ -n "$_pane" ] && _cur=$(_pane_tab "$_pane")
[ -n "$_cur" ] || _cur=$(printf '%s' "$_tabs" | jq -r '.result.tabs[] | select(.focused) | .tab_id' | head -n 1)

_cur_pos=0
if [ -n "$_cur" ]; then
	_cur_pos=$(printf '%s\n' "$_tab_ids" | awk -v want="$_cur" '$0 == want { print NR }' | head -n 1)
	_cur_pos=${_cur_pos:-0}
fi

case $target in
next)
	# No known position: `next` still means the first tab.
	if [ "$_cur_pos" -ge "$_count" ]; then
		_pos=1
	else
		_pos=$((_cur_pos + 1))
	fi
	;;
prev)
	if [ "$_cur_pos" -le 1 ]; then
		_pos=$_count
	else
		_pos=$((_cur_pos - 1))
	fi
	;;
*)
	_pos=$target
	if [ "$_pos" -gt "$_count" ]; then
		printf 'tab.sh: tab %s does not exist: workspace %s has %s tab(s)\n' \
			"$_pos" "$_ws" "$_count" >&2
		exit 1
	fi
	;;
esac

_tab=$(printf '%s\n' "$_tab_ids" | awk -v pos="$_pos" 'NR == pos { print }')
[ -n "$_tab" ] || {
	printf 'tab.sh: cannot resolve tab %s in workspace %s\n' "$_pos" "$_ws" >&2
	exit 1
}

herdr tab focus "$_tab"
