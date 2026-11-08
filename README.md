# mux

One entrypoint for terminal multiplexer actions. `mux` resolves the backend it
runs under (herdr, tuios, tmux, kitty, wezterm) and a layout (pane, tab, popup,
overlay), then presents a command in it.

```sh
mux --layout pane --direction right -- htop
mux split down
mux scratch
```

## Install

```sh
make install
```

That is the whole install: it puts a symlink at `~/.local/bin/mux` pointing at
the `mux` in this repo, so edits here are live and there is nothing to rebuild.
Use `mux` from `PATH` — you never need to `cd` into this directory, and no
script should reference the checkout path.

`BINDIR` overrides the target directory:

```sh
make install BINDIR="$HOME/bin"
```

Some terminal configs name a helper directly instead of going through `mux`
(a kitty keymap that runs `split.sh`, for example). Those need the directory on
a stable path:

```sh
make install-lib     # ~/.local/lib/mux -> this repo
```

Both symlinks come off with `make uninstall`.

## Verbs

```
mux new_tab              new tab in the focused pane directory
mux close_pane           close the focused pane
mux zoom [on|off|toggle] maximise the focused pane
mux split right|down|left|up
                         new shell pane on that side
mux multi [options] --pane CMD[@SIZE:POSITION[:TARGET]] ...
                         open a multi-pane group as one tab
mux scratch              scratch shell overlay
mux scratch_tmux         scratch shell in a native tmux popup
mux launch APP [args...] run an app in the layer it wants
mux verbs                list them
```

`mux launch` presents a picker, then the chosen app: `git`, `edit`, `projects`,
`browser`, `vault`, `tsk`, `dbx`, `actions`.

## Layout

Everything is flat in this directory: `mux` is the facade and the `*.sh` helpers
sit next to it. The facade looks for helpers in its own directory after
resolving symlinks, so the folder is portable as a whole and `MUX_LIB_DIR`
still overrides it.

| File | Role |
| --- | --- |
| `mux` | facade: option parsing, backend resolution, verb dispatch |
| `identity.sh` | recovers the enclosing pane (`MUX_PANE_CWD`, pane id) |
| `pane-env.sh` | gives a keymap-launched command a mux identity, then an overlay |
| `picker-run.sh` | runs a picker in an overlay and presents the choice |
| `split.sh`, `zoom.sh`, `close-pane.sh`, `new-tab.sh` | one pane action each |
| `multi.sh` | multi-pane group as a single tab |
| `scratch.sh` | scratch shell |
| `browser.sh`, `vault.sh`, `editor-explorer.sh`, `git-picker.sh` | apps behind `mux launch` |

## Tests

```sh
make test    # behaviour tests
make lint    # shellcheck
make check   # parse only
```

The suites are hermetic: they unset `MUX_IN_POPUP` and fake `tmux`/`herdr` on
`PATH`. Two scenarios (tmux client selection by pane tty) need a real terminal
on stdin and report `skip` without one.

A few assertions also check the author's terminal configs, which are not part of
this repo; those report `skip` unless the configs exist under `CHEZMOI_SRC`
(default `~/.local/share/chezmoi/home`).

## Requirements

- POSIX `sh` for the facade, `bash` for most helpers
- `jq` for the herdr backend
- `tmux >= 3.2` for popups, `fzf` for the pickers
