#!/bin/bash
# Git picker for the terminal, independent of herdr.
#
# Fork of ~/.config/herdr/scripts/git.sh. The picker only chooses: it prints
# "LAYOUT<TAB>COMMAND" and `picker-run.sh` presents the command with that
# layout. Everything goes to an overlay: the herdr popup placement redraws the
# whole window on each key, which makes a TUI unusable.
plan() {
  printf '%s\t%s\n' "$1" "$2"
}

key=$(printf "[g] lazygit\n[b] gitbutler (but tui)\n[z] lazygit + but tui + shell\n[j] jj\n[c] Code Review (tuicr)\n[h] hunk diff\n[m] Mergetool (ec)\n[p] prdash\n[d] gitdash" | fzf --prompt="Git > " --height=90% --reverse --border --header="Press key to execute" --expect=g --expect=b --expect=z --expect=j --expect=c --expect=h --expect=m --expect=p --expect=d)

pressed=$(echo "$key" | head -1)
selected=$(echo "$key" | tail -1)

case "$pressed" in
g) plan overlay lazygit ;;
b) plan overlay "but tui" ;;
# multipane group: PANE|PANE|... where each PANE is CMD[@SIZE:POSITION].
# lazygit keeps the left half; but tui sits top-right; the shell takes 30%
# of the height and 50% of the width, i.e. the bottom-right cell.
z) plan 'multi:VC overlay' 'lazygit|but tui@50:right|-@40:down' ;;
j) plan overlay jj ;;
c) plan overlay tuicr ;;
h) plan overlay "hunk diff" ;;
m) plan overlay ec ;;
p) plan overlay prdash ;;
d) plan overlay gitdash ;;
*)
  case "$selected" in
  *"lazygit + but tui + shell"*) plan 'multi:VC overlay' 'lazygit|but tui@50:right|-@40:down' ;;
  *lazygit) plan overlay lazygit ;;
  *gitbutler*) plan overlay "but tui" ;;
  *jj) plan overlay jj ;;
  *tuicr) plan overlay tuicr ;;
  *hunk*) plan overlay "hunk diff" ;;
  *ec*) plan overlay ec ;;
  *prdash) plan overlay prdash ;;
  *gitdash) plan overlay gitdash ;;
  esac
  ;;
esac
