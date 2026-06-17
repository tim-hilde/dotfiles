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

# Separator between visible text and hidden pane id (stripped by gum, stays in raw line)
SEP=$'\x01'

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

# Output lines to gum: project headers + session lines, sorted by
# status (waiting→working→done) then project.
# Each session line embeds the pane id after SEP for routing.
# Header lines have no SEP and will be ignored on selection.
build_gum_input() {
  local pane f state title project pid row rank
  local tmp
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
      # Project header — no SEP, not selectable as a session
      printf '%s%s%s\n' "$C_HEAD" "$project" "$C_RST"
      prev_project="$project"
    fi
    # Session line: indent + icon + title + SEP + pane (pane id hidden after SEP)
    printf '  %s  %s%s%s\n' "$(icon_for "$state")" "$title" "$SEP" "$pane"
  done < <(sort -t$'\t' -k1,1n -k2,2 "$tmp")
  rm -f "$tmp"
}

main() {
  build_live
  cleanup_stale

  local gum_input
  gum_input="$(build_gum_input)"

  if [ "${1:-}" = "--list" ]; then
    printf '%s\n' "$gum_input"
    return 0
  fi

  if [ -z "$gum_input" ]; then
    gum style --foreground 244 "Keine laufenden opencode-Instanzen."
    sleep 1
    return 0
  fi

  local selected pane sess win
  # Loop so header selections are silently skipped
  while true; do
    selected="$(printf '%s\n' "$gum_input" | gum filter \
      --no-strip-ansi --no-sort --height 50 \
      --placeholder 'opencode …' --prompt '🤖  ')" || return 0
    [ -n "$selected" ] || return 0
    # Extract pane id: everything after SEP in the raw selected string.
    # gum strips ANSI but preserves \x01, so SEP is still present.
    pane="${selected##*$'\x01'}"
    [ -n "$pane" ] && [ "$pane" != "$selected" ] && break
    # No SEP found = header line selected, let user pick again
  done

  IFS=$'\t' read -r sess win < <(
    tmux display-message -p -t "$pane" '#{session_name}'$'\t''#{window_index}'
  )
  tmux switch-client -t "$sess"
  tmux select-window -t "${sess}:${win}"
  tmux select-pane -t "$pane"
}

main "$@"
