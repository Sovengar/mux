#!/bin/bash
# Editor / file-explorer picker for the terminal.
#
# Same shape as git-picker.sh: the picker only chooses. It prints
# "LAYOUT<TAB>COMMAND" and `picker-run.sh` presents the command with that
# layout. Full-screen TUIs open as an overlay.
#
# Menu:
#   e - $EDITOR (nvim by default), opened on the current directory so the
#       explorer sidepanel (snacks explorer) shows up, like `vault` does with
#       `nvim .`. Without the directory argument nvim opens an empty buffer and
#       no sidepanel.
#   y - yazi
editor="${EDITOR:-nvim}"

plan() {
  printf '%s\t%s\n' "$1" "$2"
}

key=$(
  printf '[e] editor (%s)\n[y] yazi' "$editor" |
    fzf --prompt="Edit > " --height=90% --reverse --border \
      --header="Press key to execute" --expect=e --expect=y
)

pressed=$(echo "$key" | head -1)
selected=$(echo "$key" | tail -1)

case "$pressed" in
e) plan overlay "$editor ." ;;
y) plan overlay yazi ;;
*)
  case "$selected" in
  *editor*) plan overlay "$editor ." ;;
  *yazi*) plan overlay yazi ;;
  esac
  ;;
esac
