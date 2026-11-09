#!/bin/sh
# Behaviour tests for the tab verbs (`mux next_tab`, `mux prev_tab`, `mux tabN`).
# Run: sh tests/mux-tab.sh
set -eu

# shellcheck disable=SC1007 # CDPATH= stops cd from printing a path; space required
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
mux_bin=$repo/mux
tab_bin=$repo/tab.sh

unset MUX_IN_POPUP

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
pass=0
ok() { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; printf '       %s\n' "$2"; }
assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected: $2 | actual: $3"; fi; }
assert_contains() {
	case $3 in
	*"$2"*) ok "$1" ;;
	*) no "$1" "missing: $2 | in: $3" ;;
	esac
}

# A fake herdr: one workspace with four tabs and a second workspace that must
# never show up, so a wrong workspace filter fails loudly.
bin=$work/bin
mkdir -p "$bin"
cat >"$bin/herdr" <<'EOF'
#!/bin/sh
case "$1 $2" in
"pane list")
	cat <<'JSON'
{"result":{"panes":[
 {"pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1","focused":false},
 {"pane_id":"w1:p4","tab_id":"w1:t4","workspace_id":"w1","focused":true},
 {"pane_id":"w2:p1","tab_id":"w2:t1","workspace_id":"w2","focused":false}]}}
JSON
	;;
"pane current") printf '{"error":{"code":"pane_not_found"}}\n' ;;
"tab list")
	# `--workspace` is honoured; anything else would leak the other workspace.
	case "$*" in
	*"--workspace w1"*)
		cat <<'JSON'
{"result":{"tabs":[
 {"tab_id":"w1:t4","workspace_id":"w1","number":40,"focused":true},
 {"tab_id":"w1:t1","workspace_id":"w1","number":10,"focused":false},
 {"tab_id":"w1:t3","workspace_id":"w1","number":30,"focused":false},
 {"tab_id":"w1:t2","workspace_id":"w1","number":20,"focused":false}]}}
JSON
		;;
	*)
		cat <<'JSON'
{"result":{"tabs":[{"tab_id":"w2:t1","workspace_id":"w2","number":1,"focused":true}]}}
JSON
		;;
	esac
	;;
"tab focus") printf 'focused %s\n' "$3" ;;
*) printf 'herdr: unexpected call: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
chmod +x "$bin/herdr"

run_tab() { PATH=$bin:$PATH HERDR_PANE_ID=${HERDR_PANE_ID:-w1:p4} sh "$tab_bin" "$@"; }
run_mux() { PATH=$bin:$PATH HERDR_PANE_ID=${HERDR_PANE_ID:-w1:p4} sh "$mux_bin" "$@"; }

# Tabs arrive unsorted; the verbs must use tab-bar position, not `number`.
assert_eq "tab2 is the second tab in tab-bar order" \
	"focused w1:t2" "$(run_tab 2)"
assert_eq "tab4 is the last tab" "focused w1:t4" "$(run_tab 4)"
assert_eq "tab1 is the leftmost tab" "focused w1:t1" "$(run_tab 1)"

# next from the last tab wraps to the first; prev from the first wraps to the last.
assert_eq "next wraps around" "focused w1:t1" "$(HERDR_PANE_ID=w1:p4 run_tab next)"
assert_eq "prev wraps around" "focused w1:t4" "$(HERDR_PANE_ID=w1:p1 run_tab prev)"

# A missing numbered tab is an error, never a silent no-op.
err=$(run_tab 5 2>&1) && rc=0 || rc=$?
assert_eq "tab5 fails when there are four tabs" "1" "$rc"
assert_contains "tab5 names the missing tab" "tab 5 does not exist" "$err"

# The facade maps one verb per keybinding onto the helper.
assert_eq "mux tab3 dispatches" "focused w1:t3" "$(run_mux tab3)"
assert_eq "mux next_tab dispatches" "focused w1:t1" "$(run_mux next_tab)"
assert_eq "mux prev_tab dispatches" "focused w1:t3" "$(run_mux prev_tab)"
assert_eq "mux tab without a digit is not a verb" "2" \
	"$(rc=0; PATH=$bin:$PATH HERDR_PANE_ID=w1:p4 sh "$mux_bin" tab10 >/dev/null 2>&1 || rc=$?; echo "$rc")"
assert_eq "tab.sh rejects an unknown target" "2" \
	"$(rc=0; run_tab sideways >/dev/null 2>&1 || rc=$?; echo "$rc")"

# The verb list is data the keybinding table reads.
verbs=$(PATH=$bin:$PATH sh "$mux_bin" verbs)
assert_contains "verbs lists next_tab" "next_tab" "$verbs"
assert_contains "verbs lists prev_tab" "prev_tab" "$verbs"
assert_contains "VERBS string contains tab9" "tab9" "$(sed -n 's/^VERBS=//p' "$repo/mux")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
