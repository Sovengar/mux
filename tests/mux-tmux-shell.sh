#!/bin/sh
# Behaviour tests for the pane tmux wrapper (scripts/mux-tmux-shell).
# Run: sh tests/mux-tmux-shell.sh
set -eu

# The wrapper and the terminal configs stay in the chezmoi repo: they are not
# mux code, so this repo only asserts that they still point at mux.
conf_src=${CHEZMOI_SRC:-$HOME/.local/share/chezmoi/home}
wrapper=${MUX_TMUX_SHELL:-$conf_src/dot_local/scripts/executable_mux-tmux-shell}
herdr_conf=$conf_src/dot_config/herdr/config.toml
kitty_conf=$conf_src/dot_config/kitty/kitty.conf

# The wrapper ships with the author's dotfiles, not with mux, so a plain clone
# has nothing to test here.
if [ ! -f "$wrapper" ]; then
	printf 'skip - mux-tmux-shell wrapper not found (set MUX_TMUX_SHELL)\n'
	exit 0
fi

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
	*) no "$1" "missing: $2" ;;
	esac
}

# A shell that records that the wrapper fell through to it.
shell=$work/fake-shell
cat >"$shell" <<'EOF'
#!/bin/sh
printf 'fallback %s\n' "$*"
EOF
chmod +x "$shell"

# A tmux that must not be reached when the wrapper falls through.
bin=$work/bin
mkdir -p "$bin"
cat >"$bin/tmux" <<'EOF'
#!/bin/sh
printf 'tmux %s\n' "$*"
EOF
chmod +x "$bin/tmux"

# Scenario 1: no tty -> real shell, no tmux.
out=$(SHELL=$shell PATH=$bin:$PATH sh "$wrapper" -l </dev/null) || true
assert_eq "no tty falls through to the shell" "fallback -l" "$out"

# Scenario 2: already inside tmux -> real shell, no nested client.
out=$(TMUX=/tmp/tmux-test,1,0 SHELL=$shell PATH=$bin:$PATH sh "$wrapper" </dev/null) || true
assert_eq "inside tmux falls through to the shell" "fallback " "$out"

# Scenario 3: the wrapper starts a client with a per-pane session that dies on
# detach, and hides the tmux status line.
assert_contains "creates a session per pane" 'session="pane-$$"' "$(cat "$wrapper")"
assert_contains "session dies with its client" "destroy-unattached on" "$(cat "$wrapper")"
assert_contains "status line hidden" "status off" "$(cat "$wrapper")"

# Acceptances: only kitty wires its windows to the wrapper. Herdr panes run a
# plain shell so Herdr can resolve the pane cwd from the foreground process.
# Skipped on a checkout with no terminal configs.
if [ -f "$herdr_conf" ] && [ -f "$kitty_conf" ]; then
	assert_contains "herdr panes run a plain shell" \
		'default_shell = "fish"' "$(cat "$herdr_conf")"
	case $(cat "$herdr_conf") in
	*mux-tmux-shell*) no "herdr does not wrap panes in a tmux client" "default_shell still names the wrapper" ;;
	*) ok "herdr does not wrap panes in a tmux client" ;;
	esac
	assert_contains "kitty uses the wrapper as shell" \
		"shell $HOME/.local/scripts/mux-tmux-shell" "$(cat "$kitty_conf")"
else
	printf 'skip - terminal config assertions (no configs at %s)\n' "$conf_src"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
