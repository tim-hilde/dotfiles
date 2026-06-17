#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"

# Nerd Font glyphs
ICON_WAITING=$'\uf059'   # question circle
ICON_WORKING=$'\uf110'   # spinner
ICON_DONE=$'\uf058'      # check circle

# ANSI colors (24x palette)
C_WAIT=$'\033[38;5;216m'
C_WORK=$'\033[38;5;111m'
C_DONE=$'\033[38;5;114m'
C_DIM=$'\033[2;90m'
C_RST=$'\033[0m'

icon_for() {
  case "$1" in
    waiting) printf '%s%s%s' "$C_WAIT" "$ICON_WAITING" "$C_RST" ;;
    working) printf '%s%s%s' "$C_WORK" "$ICON_WORKING" "$C_RST" ;;
    *)       printf '%s%s%s' "$C_DONE" "$ICON_DONE" "$C_RST" ;;
  esac
}

# Build the set of currently-live pane ids.
declare -A LIVE=()
build_live() {
  local p
  while IFS= read -r p; do
    [ -n "$p" ] && LIVE["$p"]=1
  done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)
}

# Remove state files whose pane is gone or whose pid is dead.
cleanup_stale() {
  shopt -s nullglob
  local f pane pid
  for f in "$STATE_DIR"/*.json; do
    if ! pane="$(jq -r '.pane // empty' "$f" 2>/dev/null)"; then
      rm -f "$f"; continue
    fi
    pid="$(jq -r '.pid // empty' "$f" 2>/dev/null || true)"
    if [ -z "$pane" ] || [ -z "${LIVE[$pane]:-}" ] || [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f"
    fi
  done
}

# Emit one render line per live opencode pane, in tmux list-panes order.
# Each line ends with a dim, ANSI-wrapped pane id used as the routing token.
build_entries() {
  local pane f state title project pid
  while IFS= read -r pane; do
    [ -n "$pane" ] || continue
    f="$STATE_DIR/${pane#%}.json"
    [ -f "$f" ] || continue
    local row
    row="$(jq -r '[.state, .title, .project, .pid] | @tsv' "$f" 2>/dev/null)" || continue
    IFS=$'\t' read -r state title project pid <<< "$row"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then continue; fi
    [ -n "$title" ] || title="(kein Titel)"
    printf '%s  %s — %s  %s%s%s\n' \
      "$(icon_for "$state")" "$project" "$title" "$C_DIM" "$pane" "$C_RST"
  done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)
}

main() {
  build_live
  cleanup_stale
  local entries
  entries="$(build_entries)"

  if [ "${1:-}" = "--list" ]; then
    [ -n "$entries" ] && printf '%s\n' "$entries"
    return 0
  fi

  if [ -z "$entries" ]; then
    gum style --foreground 244 "Keine laufenden opencode-Instanzen."
    sleep 1
    return 0
  fi

  local selected
  selected="$(printf '%s\n' "$entries" | gum filter \
    --no-strip-ansi --no-sort --height 50 \
    --placeholder 'opencode …' --prompt '🤖  ')" || return 0
  [ -n "$selected" ] || return 0

  # Strip ANSI, take the last whitespace token = pane id.
  local clean pane sess win
  clean="$(printf '%s' "$selected" | sed -E 's/\x1b\[[0-9;]*m//g')"
  pane="$(printf '%s' "$clean" | grep -oE '%[0-9]+$')"
  [ -n "$pane" ] || return 0

  IFS=$'\t' read -r sess win < <(
    tmux display-message -p -t "$pane" '#{session_name}'$'\t''#{window_index}'
  )
  tmux switch-client -t "$sess"
  tmux select-window -t "${sess}:${win}"
  tmux select-pane -t "$pane"
}

main "$@"
