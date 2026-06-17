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

# Populate DISPLAY_LINES and PANE_IDS arrays in tmux list-panes order.
DISPLAY_LINES=()
PANE_IDS=()
build_entries() {
  local pane f state title project pid row
  while IFS= read -r pane; do
    [ -n "$pane" ] || continue
    f="$STATE_DIR/${pane#%}.json"
    [ -f "$f" ] || continue
    row="$(jq -r '[.state, .title, .project, .pid] | @tsv' "$f" 2>/dev/null)" || continue
    IFS=$'\t' read -r state title project pid <<< "$row"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then continue; fi
    [ -n "$title" ] || title="(kein Titel)"
    DISPLAY_LINES+=("$(printf '%s  %s — %s' "$(icon_for "$state")" "$project" "$title")")
    PANE_IDS+=("$pane")
  done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)
}

main() {
  build_live
  cleanup_stale
  build_entries

  if [ "${1:-}" = "--list" ]; then
    for line in "${DISPLAY_LINES[@]}"; do printf '%s\n' "$line"; done
    return 0
  fi

  if [ "${#DISPLAY_LINES[@]}" -eq 0 ]; then
    gum style --foreground 244 "Keine laufenden opencode-Instanzen."
    sleep 1
    return 0
  fi

  local selected idx pane sess win
  selected="$(printf '%s\n' "${DISPLAY_LINES[@]}" | gum filter \
    --no-strip-ansi --no-sort --height 50 \
    --placeholder 'opencode …' --prompt '🤖  ')" || return 0
  [ -n "$selected" ] || return 0

  # Find index of selected line to look up corresponding pane id.
  pane=""
  for idx in "${!DISPLAY_LINES[@]}"; do
    if [ "${DISPLAY_LINES[$idx]}" = "$selected" ]; then
      pane="${PANE_IDS[$idx]}"
      break
    fi
  done
  [ -n "$pane" ] || return 0

  IFS=$'\t' read -r sess win < <(
    tmux display-message -p -t "$pane" '#{session_name}'$'\t''#{window_index}'
  )
  tmux switch-client -t "$sess"
  tmux select-window -t "${sess}:${win}"
  tmux select-pane -t "$pane"
}

main "$@"
