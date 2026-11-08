#!/bin/bash
# Open a multi-pane group as one native herdr tab.
#
# Usage:
#   multi.sh [options] --pane SPEC [--pane SPEC ...]
#   multi.sh --kill
#
# SPEC = COMMAND[@SIZE:POSITION[:TARGET]]
#   COMMAND   command to run in that pane (empty or '-' = plain shell)
#   SIZE      percent of the parent pane taken by THIS pane (default 50)
#   POSITION  left|right|up|down, side of the parent (default right)
#   TARGET    1-based index of the pane to split (default: the previous pane)
#
# The first --pane fills the whole tab; its SIZE, POSITION and TARGET are
# ignored. The group is one tab, so killing it kills every pane inside,
# whatever their number.
#
# Options:
#   --cwd DIR        working directory for every pane (default: pane dir)
#   --label NAME     tab label (default: multi)
#   --no-focus       do not focus the new tab/panes
#   --dry-run        print the resolved plan and exit
#   --kill           close the last group opened by this script
set -u

# shellcheck source=identity.sh
. "$(dirname "$0")/identity.sh"

state_dir=${XDG_RUNTIME_DIR:-/tmp}/mux
state_file=$state_dir/multi.state

die() {
	printf 'multi: %s\n' "$*" >&2
	exit 2
}

usage() {
	sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

cwd=${MUX_PANE_CWD:-$PWD}
label=multi
focus=1
dry_run=0
kill=0
specs=()

while [ $# -gt 0 ]; do
	case $1 in
	--pane)
		[ $# -ge 2 ] || die "--pane needs a value"
		specs+=("$2")
		shift 2
		;;
	--cwd | --working-dir)
		cwd=${2:?--cwd needs a value}
		shift 2
		;;
	--label)
		label=${2:?--label needs a value}
		shift 2
		;;
	--no-focus)
		focus=0
		shift
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	--kill)
		kill=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		die "unknown option: $1"
		;;
	esac
done

if [ "$kill" = 1 ]; then
	[ -s "$state_file" ] || {
		printf 'multi: nothing to kill\n'
		exit 0
	}
	# shellcheck disable=SC1090
	. "$state_file"
	[ -n "${MULTI_TAB:-}" ] || die "state file has no tab id: $state_file"
	herdr tab close "$MULTI_TAB" >/dev/null 2>&1 || true
	rm -f "$state_file"
	printf 'multi: closed tab %s\n' "$MULTI_TAB"
	exit 0
fi

[ "${#specs[@]}" -gt 0 ] || {
	usage >&2
	exit 2
}

[ "${HERDR_ENV:-}" = 1 ] || die "multi needs the herdr backend (HERDR_ENV=1)"

# Parse every spec before touching the layout, so a typo cannot leave a
# half-built tab behind.
cmds=()
sizes=()
positions=()
targets=()
for spec in "${specs[@]}"; do
	cmd=$spec size=50 pos=right tgt=0
	if [[ $spec =~ ^(.*)@([0-9]{1,3})%?:(left|right|up|down)(:([0-9]+))?$ ]]; then
		cmd=${BASH_REMATCH[1]}
		size=${BASH_REMATCH[2]}
		pos=${BASH_REMATCH[3]}
		tgt=${BASH_REMATCH[5]:-0}
	fi
	[ "$size" -ge 1 ] && [ "$size" -le 99 ] || die "size out of range (1..99): $spec"
	cmds+=("$cmd")
	sizes+=("$size")
	positions+=("$pos")
	targets+=("$tgt")
done

if [ "$dry_run" = 1 ]; then
	printf 'backend=herdr layout=tab label=%s cwd=%s panes=%d\n' \
		"$label" "$cwd" "${#specs[@]}"
	for i in "${!specs[@]}"; do
		pos=${positions[$i]} size=${sizes[$i]} tgt=${targets[$i]}
		printf '  pane %d: size=%s%% pos=%s target=%s cmd=%s\n' \
			"$((i + 1))" "$size" "$pos" "$([ "$tgt" = 0 ] && echo prev || echo "$tgt")" \
			"${cmds[$i]:-<shell>}"
	done
	exit 0
fi

ws=$(herdr pane current | jq -r '.result.pane.workspace_id // empty')
[ -n "$ws" ] || die "could not resolve the herdr workspace"

_focus=--focus
[ "$focus" = 0 ] && _focus=--no-focus
out=$(herdr tab create --workspace "$ws" --cwd "$cwd" --label "$label" $_focus)
tab=$(printf '%s' "$out" | jq -r '.result.tab.tab_id // empty')
root=$(printf '%s' "$out" | jq -r '.result.root_pane.pane_id // empty')
[ -n "$tab" ] && [ -n "$root" ] || die "could not create the herdr tab"

panes=("$root")
run_cmd() {
	[ -n "$1" ] && [ "$1" != "-" ] || return 0
	herdr pane run "$2" "$1" >/dev/null 2>&1 || printf 'multi: could not run in %s: %s\n' "$2" "$1" >&2
}
run_cmd "${cmds[0]}" "$root"

for i in $(seq 1 $((${#specs[@]} - 1))); do
	tgt=${targets[$i]}
	if [ "$tgt" = 0 ]; then
		target=${panes[${#panes[@]} - 1]}
	elif [ "$tgt" -ge 1 ] && [ "$tgt" -le "${#panes[@]}" ]; then
		target=${panes[$((tgt - 1))]}
	else
		die "target out of range: $tgt"
	fi
	pos=${positions[$i]}
	# herdr only grows panes right or down: split on the matching axis and then
	# swap the new pane into place.
	axis=$pos
	swap=
	case $pos in
	left) axis=right swap=left ;;
	up) axis=down swap=up ;;
	esac
	# herdr's --ratio is the share the EXISTING pane keeps. For left/up the new
	# pane is split on the opposite axis and then swapped into place, and a swap
	# moves the pane together with its slot, so there the ratio is the new
	# pane's own share.
	if [ -n "$swap" ]; then
		ratio=$(awk -v s="${sizes[$i]}" 'BEGIN { printf "%.2f", s / 100 }')
	else
		ratio=$(awk -v s="${sizes[$i]}" 'BEGIN { printf "%.2f", 1 - s / 100 }')
	fi
	_focus=
	[ "$i" = "$((${#specs[@]} - 1))" ] && [ "$focus" = 1 ] && _focus=--focus
	out=$(herdr pane split --pane "$target" --direction "$axis" --ratio "$ratio" \
		--cwd "$cwd" $_focus 2>&1) || die "split failed: $out"
	id=$(printf '%s' "$out" | sed -n 's/.*"pane_id":"\([^"]*\)".*/\1/p' | head -n 1)
	[ -n "$id" ] || die "could not resolve the new pane id"
	[ -n "$swap" ] && herdr pane swap --pane "$id" --direction "$swap" >/dev/null 2>&1
	panes+=("$id")
	run_cmd "${cmds[$i]}" "$id"
done

mkdir -p "$state_dir"
{
	printf 'MULTI_TAB=%s\n' "$tab"
	printf "MULTI_PANES='%s'\n" "${panes[*]}"
} >"$state_file"

printf 'multi: tab %s panes %s\n' "$tab" "${panes[*]}"
