#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"

# Nerd Font glyphs
ICON_WAITING=$'\uf059'   # question circle
ICON_WORKING=$'\uf110'   # spinner
ICON_DONE=$'\uf058'      # check circle

# ANSI colors
C_WAIT=$'\033[38;5;216m'
C_WORK=$'\033[38;5;111m'
C_DONE=$'\033[38;5;114m'
C_HEAD=$'\033[1;38;5;147m'  # bold lavender for project headers
C_RST=$'\033[0m'

icon_for() {
  case "$1" in
    waiting) printf '%s%s%s' "$C_WAIT" "$ICON_WAITING" "$C_RST" ;;
    working) printf '%s%s%s' "$C_WORK" "$ICON_WORKING" "$C_RST" ;;
    *)       printf '%s%s%s' "$C_DONE" "$ICON_DONE" "$C_RST" ;;
  esac
}

strip_ansi() {
  printf '%s' "$1" | sed -E 's/\x1b\[[0-9;]*m//g'
}

state_rank() {
  case "$1" in
    waiting) echo 0 ;;
    working) echo 1 ;;
    *)       echo 2 ;;
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

# Parallel arrays in display order:
#   MENU_LINES[i]  – the (ANSI-styled) line shown in gum
#   PANE_MAP[i]    – pane id for a session line, or "" for a project header
MENU_LINES=()
PANE_MAP=()
build_menu() {
  local pane f state title project pid row rank tmp
  tmp="$(mktemp)"
  while IFS= read -r pane; do
    [ -n "$pane" ] || continue
    f="$STATE_DIR/${pane#%}.json"
    [ -f "$f" ] || continue
    row="$(jq -r '[.state, .title, .project, .pid] | @tsv' "$f" 2>/dev/null)" || continue
    IFS=$'\t' read -r state title project pid <<< "$row"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then continue; fi
    [ -n "$title" ] || title="(kein Titel)"
    rank="$(state_rank "$state")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$rank" "$project" "$pane" "$state" "$title" >> "$tmp"
  done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null || true)

  local prev_project=""
  while IFS=$'\t' read -r _ project pane state title; do
    if [ "$project" != "$prev_project" ]; then
      MENU_LINES+=("$(printf '%s%s%s' "$C_HEAD" "$project" "$C_RST")")
      PANE_MAP+=("")            # header: not selectable
      prev_project="$project"
    fi
    MENU_LINES+=("$(printf '  %s  %s' "$(icon_for "$state")" "$title")")
    PANE_MAP+=("$pane")
  done < <(sort -t$'\t' -k1,1n -k2,2 "$tmp")
  rm -f "$tmp"
}

# Resolve a gum selection (ANSI may be stripped by gum) back to a pane id.
# Echoes the pane id, or nothing for a header / no match.
resolve_pane() {
  local sel sel_s i
  sel="$1"
  sel_s="$(strip_ansi "$sel")"
  for i in "${!MENU_LINES[@]}"; do
    if [ "$(strip_ansi "${MENU_LINES[$i]}")" = "$sel_s" ]; then
      printf '%s' "${PANE_MAP[$i]}"
      return 0
    fi
  done
}

main() {
  build_live
  cleanup_stale
  build_menu

  if [ "${1:-}" = "--list" ]; then
    [ "${#MENU_LINES[@]}" -gt 0 ] && printf '%s\n' "${MENU_LINES[@]}"
    return 0
  fi

  if [ "${#MENU_LINES[@]}" -eq 0 ]; then
    gum style --foreground 244 "Keine laufenden opencode-Instanzen."
    sleep 1
    return 0
  fi

  local selected pane sess win
  # Re-prompt if a header (no pane) is selected.
  while true; do
    selected="$(printf '%s\n' "${MENU_LINES[@]}" | gum filter \
      --no-strip-ansi --no-sort --height 50 \
      --placeholder 'opencode …' --prompt '🤖  ')" || return 0
    [ -n "$selected" ] || return 0
    pane="$(resolve_pane "$selected")"
    [ -n "$pane" ] && break
  done

  IFS=$'\t' read -r sess win < <(
    tmux display-message -p -t "$pane" '#{session_name}'$'\t''#{window_index}'
  )
  tmux switch-client -t "$sess"
  tmux select-window -t "${sess}:${win}"
  tmux select-pane -t "$pane"
}

main "$@"
