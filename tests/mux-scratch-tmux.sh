#!/bin/sh
# Behaviour tests for `mux scratch_tmux`.
# Run: sh tests/mux-scratch-tmux.sh
set -eu

# shellcheck disable=SC1007 # CDPATH= stops cd from printing a path; space required
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
mux_src=$repo/mux
# The terminal configs stay in the chezmoi repo: they are not mux code.
conf_src=${CHEZMOI_SRC:-$HOME/.local/share/chezmoi/home}
kitty_conf=$conf_src/dot_config/kitty/kitty.conf
herdr_conf=$conf_src/dot_config/herdr/config.toml

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Hermetic: inherit nothing that changes mux's own branching. MUX_IN_POPUP makes
# mux exec the command instead of presenting it, which silently skips every
# layout assertion when the suite runs inside a mux popup.
unset MUX_IN_POPUP

fail=0
pass=0
skipped=0

ok() { pass=$((pass + 1)); printf 'ok   - %s\n' "$1"; }
no() { fail=$((fail + 1)); printf 'FAIL - %s\n' "$1"; printf '       %s\n' "$2"; }
skip() { skipped=$((skipped + 1)); printf 'skip - %s\n' "$1"; }

assert_eq() { # name expected actual
	if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected: $2 | actual: $3"; fi
}

assert_contains() { # name needle haystack
	case $3 in
	*"$2"*) ok "$1" ;;
	*) no "$1" "missing: $2" ;;
	esac
}

# A scratch lib dir: fake scratch.sh and pane-env.sh record how they were called.
lib=$work/lib
mkdir -p "$lib"
cat >"$lib/scratch.sh" <<'EOF'
#!/bin/sh
printf 'scratch.sh %s\n' "$*"
EOF
cat >"$lib/pane-env.sh" <<'EOF'
#!/bin/sh
printf 'pane-env.sh %s\n' "$*"
EOF
chmod +x "$lib/scratch.sh" "$lib/pane-env.sh"

# A fake `mux` on PATH: scratch_tmux re-execs mux, so capture the argv it builds.
bin=$work/bin
mkdir -p "$bin"
cat >"$bin/mux" <<'EOF'
#!/bin/sh
printf 'mux %s\n' "$*"
EOF
chmod +x "$bin/mux"

# Hermetic tmux: no client unless a scenario says otherwise, so the tests do not
# depend on whatever tmux server the machine happens to run.
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
case $1 in
list-clients) exit 0 ;;
*) printf 'tmux %s\n' "$*" ;;
esac
EOF
chmod +x "$bin/tmux"

run_mux() { # env assignments... -- args handled by caller
	PATH=$bin:$PATH MUX_LIB_DIR=$lib sh "$mux_src" "$@"
}

# Scenario 1: TMUX set -> native tmux popup via the existing popup branch.
out=$(TMUX=/tmp/tmux-test,1,0 run_mux scratch_tmux arg1 2>"$work/err1") || true
assert_eq "scenario 1: re-execs mux with the tmux popup" \
	"mux --backend tmux --layout popup --label scratch --width 40 --height 60 --cwd $PWD -- $lib/scratch.sh arg1" \
	"$out"
assert_eq "scenario 1: nothing on stderr" "" "$(cat "$work/err1")"

# Scenario 1: the width/height/cwd overrides are honoured.
out=$(TMUX=/tmp/tmux-test,1,0 MUX_SCRATCH_WIDTH=90% MUX_SCRATCH_HEIGHT=40% \
	MUX_PANE_CWD=/tmp/elsewhere run_mux scratch_tmux 2>/dev/null) || true
assert_eq "scenario 1: honours MUX_SCRATCH_* and MUX_PANE_CWD" \
	"mux --backend tmux --layout popup --label scratch --width 90% --height 40% --cwd /tmp/elsewhere -- $lib/scratch.sh" \
	"$out"

# Scenario 2: no TMUX, no tmux server -> tmux itself runs in an overlay, so the
# scratch shell is still a real tmux pane.
out=$(env -u TMUX PATH=$bin:$PATH MUX_LIB_DIR=$lib sh "$mux_src" scratch_tmux arg1 2>"$work/err2") || true
assert_eq "scenario 2: warns on stderr" \
	"mux: no attached tmux client; opening the popup in an overlay" \
	"$(cat "$work/err2")"
assert_contains "scenario 2: overlay runs a popup window command" \
	"pane-env.sh scratch 70% 70% -- tmux new-session -s mux-popup-" "$out"
assert_contains "scenario 2: popup uses percentages" \
	"-w 40% -h 60%" "$out"

# Scenario 3: `mux verbs` lists the verb and describes it.
out=$(run_mux verbs)
assert_contains "scenario 3: verbs lists scratch_tmux" "scratch_tmux" "$out"
assert_contains "scenario 3: verbs describes scratch_tmux" \
	"scratch_tmux         scratch shell in a native tmux popup" "$out"
assert_contains "scenario 3: VERBS string contains scratch_tmux" \
	"scratch scratch_tmux launch" \
	"$(sed -n 's/^VERBS=//p' "$mux_src")"

# Scenario 4: the opt-in comment sits above the case arm.
arm=$(sed -n '/^\tscratch_tmux)/,/^\t\t;;/p' "$mux_src")
assert_contains "scenario 4: comment explains opt-in" "opt-in" "$arm"
assert_contains "scenario 4: comment mentions the slow herdr popup" "herdr popup pane is slow" "$arm"
assert_contains "scenario 4: comment mentions the attached tmux client" "attached tmux client" "$arm"

# Legacy popup branch in mux is untouched: run_tmux still calls display-popup,
# now with the optional client selector in front.
assert_contains "regression: run_tmux keeps tmux display-popup" \
	"tmux display-popup \$_popup_client -E -d \"\$cwd\" -T \"\$label\" -w \"\$_w\" -h \"\$_h\" \"\$cmd\"" \
	"$(cat "$mux_src")"

# Scenario 11: a cell size larger than the client is clamped, not forwarded, so
# tmux does not fail with "height too large".
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
case "$*" in
*client_width*) printf '81\n' ;;
*client_height*) printf '47\n' ;;
*) printf 'tmux %s\n' "$*" ;;
esac
EOF
chmod +x "$bin/tmux"
out=$(PATH=$bin:$PATH sh "$mux_src" --backend tmux --layout popup \
	--tmux-client /dev/pts/5 --width 40 --height 60 -- true)
assert_contains "scenario 11: height clamped to the client" "-h 45" "$out"
assert_contains "scenario 11: fitting width kept" "-w 40" "$out"

# Scenario 12: sizes that already fit are untouched.
out=$(PATH=$bin:$PATH sh "$mux_src" --backend tmux --layout popup \
	--tmux-client /dev/pts/5 --width 40 --height 20 -- true)
assert_contains "scenario 12: fitting height kept" "-h 20" "$out"

# Scenario 5: no TMUX, but the tmux server reports an attached client -> popup
# against that client. This is the path a kitty map or a herdr key takes.
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
case $1 in
list-clients) printf '%s\n' /dev/pts/9 ;;
*) printf 'tmux %s\n' "$*" ;;
esac
EOF
chmod +x "$bin/tmux"
out=$(env -u TMUX -u HERDR_ENV PATH=$bin:$PATH MUX_LIB_DIR=$lib sh "$mux_src" scratch_tmux arg1 2>"$work/err5") || true
assert_eq "scenario 5: targets the attached client" \
	"mux --backend tmux --layout popup --tmux-client /dev/pts/9 --label scratch --width 40 --height 60 --cwd $PWD -- $lib/scratch.sh arg1" \
	"$out"
assert_eq "scenario 5: no warning when a client exists" "" "$(cat "$work/err5")"

# Scenario 5b: tmux runs in another pane -> never borrow that client, because
# the popup would appear in the wrong pane.
: >"$work/fake-tty"
# The sleep holds a tty open so the pane pid stays valid; it reads no stdin.
# shellcheck disable=SC2217
sleep 5 <"$work/fake-tty" &
fake_pane_pid=$!
cat >"$bin/herdr" <<EOF
#!/bin/sh
printf '{"result":{"process_info":{"shell_pid":$fake_pane_pid}}}\n'
EOF
chmod +x "$bin/herdr"
out=$(HERDR_ENV=1 PATH=$bin:$PATH MUX_LIB_DIR=$lib sh "$mux_src" scratch_tmux 2>/dev/null) || true
kill $fake_pane_pid 2>/dev/null || true
case $out in
*tmux-client*) no "scenario 5b: never borrows another pane's client" "$out" ;;
*) ok "scenario 5b: never borrows another pane's client" ;;
esac
rm -f "$bin/herdr"

# Scenario 6: the server reports no client -> overlay fallback.
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
case $1 in
list-clients) exit 0 ;;
*) printf 'tmux %s\n' "$*" ;;
esac
EOF
chmod +x "$bin/tmux"
out=$(env -u TMUX PATH=$bin:$PATH MUX_LIB_DIR=$lib sh "$mux_src" scratch_tmux 2>"$work/err6") || true
assert_contains "scenario 6: no client -> popup in an overlay" \
	"tmux new-session -s mux-popup-" "$out"
assert_eq "scenario 6: warns when no client exists" \
	"mux: no attached tmux client; opening the popup in an overlay" \
	"$(cat "$work/err6")"

# Scenario 7: MUX_TMUX_CLIENT overrides the detected client.
out=$(env -u TMUX MUX_TMUX_CLIENT=/dev/pts/42 PATH=$bin:$PATH MUX_LIB_DIR=$lib \
	sh "$mux_src" scratch_tmux 2>/dev/null) || true
assert_eq "scenario 7: MUX_TMUX_CLIENT wins" \
	"mux --backend tmux --layout popup --tmux-client /dev/pts/42 --label scratch --width 40 --height 60 --cwd $PWD -- $lib/scratch.sh" \
	"$out"

# Scenario 8: --tmux-client reaches display-popup through the popup branch.
out=$(run_mux --backend tmux --layout popup --tmux-client /dev/pts/9 --dry-run -- true)
assert_contains "scenario 8: --tmux-client is an accepted option" "layout=popup" "$out"

# Scenarios 9 and 10 pick a tmux client by matching the caller's pane tty, so
# they need a real terminal on stdin; without one there is no tty to match.
if [ -t 0 ]; then
# Scenario 9: several clients, tmux running inside a herdr pane -> pick the
# client whose tty is that pane's tty, not merely the first one.
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
case $1 in
list-clients) printf '/dev/pts/9\n/dev/pts/4\n' ;;
*) printf 'tmux %s\n' "$*" ;;
esac
EOF
chmod +x "$bin/tmux"
cat >"$bin/herdr" <<EOF
#!/bin/sh
# the pane shell is this test's own shell: its fd 0 is the tty below
printf '{"result":{"process_info":{"shell_pid":%s}}}\n' "\$PPID"
EOF
chmod +x "$bin/herdr"
out=$(env -u TMUX HERDR_ENV=1 PATH=$bin:$PATH MUX_LIB_DIR=$lib sh "$mux_src" scratch_tmux 2>/dev/null) || true
case $out in
*--tmux-client*) ok "scenario 9: targets a live client" ;;
*) no "scenario 9: targets a live client" "$out" ;;
esac

# Scenario 10: the attached client wins over the first one when the pane tty is
# in the list.
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
case $1 in
list-clients) printf '/dev/pts/9\n%s\n' "$(readlink -f /proc/$PPID/fd/0 2>/dev/null)" ;;
*) printf 'tmux %s\n' "$*" ;;
esac
EOF
chmod +x "$bin/tmux"
out=$(env -u TMUX HERDR_ENV=1 PATH=$bin:$PATH MUX_LIB_DIR=$lib MUX_TMUX_CLIENT= sh "$mux_src" scratch_tmux 2>/dev/null) || true
case $out in
*--tmux-client*) ok "scenario 10: keeps a client argument" ;;
*) no "scenario 10: keeps a client argument" "$out" ;;
esac
else
	skip "scenarios 9-10: client selection by pane tty (no tty on stdin)"
fi


# Regression: the herdr overlay must land in the tab of the caller. herdr
# rejects --target-pane for overlay placement, so the plugin pane is opened
# with the zoomed placement and the focused pane named explicitly.
assert_contains "uses the zoomed placement that accepts a target" \
	"--plugin herdr.mux --entrypoint run --placement zoomed" "$(cat "$mux_src")"
assert_contains "names the caller pane" \
	"--target-pane" "$(cat "$mux_src")"

# Acceptances: keybindings point at the new verb. The terminal configs are the
# author's, so this block skips on a checkout that has none.
if [ -f "$kitty_conf" ] && [ -f "$herdr_conf" ]; then
	assert_contains "kitty alt+backspace uses mux scratch_tmux" \
		"map alt+backspace launch --type=background --cwd=current bash $HOME/.local/bin/mux scratch_tmux" \
		"$(cat "$kitty_conf")"
	assert_contains "herdr alt+backspace uses mux scratch_tmux" \
		'command = "mux scratch_tmux"' "$(cat "$herdr_conf")"
	assert_contains "herdr describes the tmux popup" \
		'description = "scratch shell in a tmux popup"' "$(cat "$herdr_conf")"
else
	skip "terminal config assertions (no configs at $conf_src)"
fi

printf '\n%s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ]
[ "$fail" -eq 0 ]
