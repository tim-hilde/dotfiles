#!/usr/bin/env bash

# Fleet grid: shows every live opencode agent as a cell in a tiled popup
# (capture-pane snapshots refreshed ~0.7s). Cursor/numbers jump to an agent.
# Same truth-filtering as agent-fleet.sh / agent-switch.sh.

set -u

state_dir="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"
US=$'\x1f'

command -v tmux >/dev/null 2>&1 || exit 0

# Outer pass: resolve the real attached client (popup context can't), then
# reopen ourselves inside a display-popup. Flag and tty are passed as ARGS,
# not env: display-popup -E drops the caller's environment. #101: switch-client
# needs -c tty. Popup size is computed from the client dimensions so the grid
# uses as much screen as possible; display-popup adds a border on each side.
if [ "${1:-}" != "--inner" ]; then
  client_tty=$(tmux display -p '#{client_tty}' 2>/dev/null)
  read -r client_w client_h < <(tmux display -p '#{client_width} #{client_height}' 2>/dev/null)
  [[ "$client_w" =~ ^[0-9]+$ ]] || client_w=120
  [[ "$client_h" =~ ^[0-9]+$ ]] || client_h=40
  pw=$((client_w - 6))
  ph=$((client_h - 3))
  exec tmux display-popup -w "$pw" -h "$ph" -E "$0 --inner $client_tty"
fi

client_tty="${2:-}"
[ -d "$state_dir" ] || exit 0

icon_working=$'\uf04b'
icon_waiting=$'\uf04c'
icon_done=$'\uf00c'

c_reset=$'\033[0m'
c_bold=$'\033[1m'
c_red=$'\033[31m'
c_yellow=$'\033[33m'
c_green=$'\033[32m'

rows=()

while IFS="$US" read -r pane_id session_name window_name _; do
  f="$state_dir/${pane_id#%}.json"
  [ -f "$f" ] || continue

  IFS= read -r content <"$f" 2>/dev/null
  [ -n "$content" ] || continue

  [[ "$content" =~ \"pid\":([0-9]+) ]] || continue
  pid="${BASH_REMATCH[1]}"
  kill -0 "$pid" 2>/dev/null || continue

  [[ "$content" =~ \"state\":\"([a-z]+)\" ]] || continue
  state="${BASH_REMATCH[1]}"
  case "$state" in waiting | done | working) ;; *) continue ;; esac

  [[ "$content" =~ \"updatedAt\":([0-9]+) ]] || continue
  updated_at="${BASH_REMATCH[1]}"

  title=""
  [[ "$content" =~ \"title\":\"([^\"]*)\" ]] && title="${BASH_REMATCH[1]}"
  title="${title:-$window_name}"
  [ -n "$title" ] || title="(untitled)"

  project=""
  [[ "$content" =~ \"project\":\"([^\"]*)\" ]] && project="${BASH_REMATCH[1]}"

  case "$state" in
    waiting) prio=0 ;;
    done) prio=1 ;;
    working) prio=2 ;;
  esac

  rows+=("${session_name}"$'\t'"${prio}"$'\t'"${updated_at}"$'\t'"${state}"$'\t'"${title}"$'\t'"${project}"$'\t'"${pane_id}")
done < <(tmux list-panes -a -F "#{pane_id}${US}#{session_name}${US}#{window_name}${US}#{window_id}" 2>/dev/null)

if [ "${#rows[@]}" -eq 0 ]; then
  tmux display-message "No active agents"
  exit 0
fi

agents_pane=()
agents_state=()
agents_title=()
agents_project=()

sorted=$(mktemp)
trap 'rm -f "$sorted"' EXIT

printf '%s\n' "${rows[@]}" | sort -t $'\t' -k1,1 -k2,2n -k3,3nr >"$sorted"

while IFS=$'\t' read -r _ _ _ state title project pane_id; do
  agents_pane+=("$pane_id")
  agents_state+=("$state")
  agents_title+=("$title")
  agents_project+=("$project")
done <"$sorted"

N=${#agents_pane[@]}

stty -echo
printf '\e[?25l\e[2J'
cleanup() {
  stty echo
  printf '\e[?25h\e[H\e[2J'
}
trap 'cleanup' EXIT INT TERM

# Pick cols/rows to maximize cell area; relax min cell size in tiers when the
# screen is small, so a grid always fits every agent.
grid_dims() {
  local n=$1 w=$2 h=$3
  local tier min_w min_h
  local c r cw ch area best_area best_c best_cw found
  for tier in 0 1 2; do
    case $tier in
      0) min_w=28; min_h=6 ;;
      1) min_w=18; min_h=4 ;;
      2) min_w=10; min_h=2 ;;
    esac
    best_area=-1; best_c=1; best_cw=0; found=0
    for ((c = 1; c <= n; c++)); do
      r=$(((n + c - 1) / c))
      cw=$(((w - 2 - (c - 1)) / c))
      ch=$(((h - 2 - (r - 1)) / r))
      [ "$cw" -lt "$min_w" ] && continue
      [ "$ch" -lt "$min_h" ] && continue
      found=1
      area=$((cw * ch))
      if [ "$area" -gt "$best_area" ] || { [ "$area" -eq "$best_area" ] && [ "$cw" -gt "$best_cw" ]; }; then
        best_area=$area
        best_c=$c
        best_cw=$cw
      fi
    done
    [ "$found" -eq 1 ] && break
  done
  COLS=$best_c
  ROWS=$(((n + COLS - 1) / COLS))
  CELL_W=$(((w - 2 - (COLS - 1)) / COLS))
  CELL_H=$(((h - 2 - (ROWS - 1)) / ROWS))
  CONTENT_H=$((CELL_H - 1))
  [ "$CONTENT_H" -lt 1 ] && CONTENT_H=1
}

prev_cols=0
prev_rows=0

state_color() {
  case "$1" in
    working) printf '%s' "$c_yellow" ;;
    waiting) printf '%s' "$c_red" ;;
    done) printf '%s' "$c_green" ;;
  esac
}

state_icon() {
  case "$1" in
    working) printf '%s' "$icon_working" ;;
    waiting) printf '%s' "$icon_waiting" ;;
    done) printf '%s' "$icon_done" ;;
  esac
}

# x/y are 1-based; header is one colored line, content is plain truncated text.
draw_cell() {
  local idx=$1 x=$2 y=$3
  local state="${agents_state[$idx]}"
  local title="${agents_title[$idx]}"
  local project="${agents_project[$idx]}"
  local pane="${agents_pane[$idx]}"

  local selmark=" "
  [ "$idx" = "$selected" ] && selmark="▸"

  local icon state_color_code
  icon=$(state_icon "$state")
  state_color_code=$(state_color "$state")

  local num=$((idx + 1))
  local plain="${selmark} ${num} ${icon} ${state}"
  local colored="${c_bold}${selmark}${c_reset} ${num} ${state_color_code}${icon} ${state}${c_reset}"

  local rest="$project: $title"
  local max_rest=$((CELL_W - ${#plain} - 1))
  [ "$max_rest" -lt 1 ] && max_rest=1
  if [ "${#rest}" -gt "$max_rest" ]; then
    rest="${rest:0:$((max_rest - 1))}…"
  fi

  plain="$plain $rest"
  local pad=$((CELL_W - ${#plain}))
  [ "$pad" -lt 0 ] && pad=0

  printf '\e[%d;%dH%s %s%s' "$y" "$x" "$colored" "$rest" "$(printf '%*s' "$pad" '')"

  local -a lines=()
  local line
  while IFS= read -r line; do lines+=("$line"); done \
    < <(tmux capture-pane -p -t "$pane" 2>/dev/null)
  local start=$(( ${#lines[@]} - CONTENT_H ))
  [ "$start" -lt 0 ] && start=0

  local j
  for ((j = 0; j < CONTENT_H; j++)); do
    line="${lines[$((start + j))]:-}"
    line="${line:0:CELL_W}"
    local lpad=$((CELL_W - ${#line}))
    [ "$lpad" -lt 0 ] && lpad=0
    printf '\e[%d;%dH%s%s' "$((y + 1 + j))" "$x" "$line" "$(printf '%*s' "$lpad" '')"
  done
}

jump_to() {
  local idx=$1
  local pane="${agents_pane[$idx]}"
  local session
  session=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
  [ -n "$session" ] || exit 0
  if [ -n "$client_tty" ]; then
    tmux switch-client -c "$client_tty" -t "$session"
  else
    tmux switch-client -t "$session"
  fi
  tmux select-window -t "$pane"
  tmux select-pane -t "$pane"
  exit 0
}

selected=0

while :; do
  term_w=$(tput cols 2>/dev/null); term_w=${term_w:-80}
  term_h=$(tput lines 2>/dev/null); term_h=${term_h:-24}
  [[ "$term_w" =~ ^[0-9]+$ ]] || term_w=80
  [[ "$term_h" =~ ^[0-9]+$ ]] || term_h=24

  grid_dims "$N" "$term_w" "$term_h"

  if [ "$COLS" != "$prev_cols" ] || [ "$ROWS" != "$prev_rows" ]; then
    printf '\e[2J'
    prev_cols=$COLS
    prev_rows=$ROWS
  fi

  for ((i = 0; i < N; i++)); do
    row=$((i / COLS))
    col=$((i % COLS))
    x=$((2 + col * (CELL_W + 1)))
    y=$((2 + row * (CELL_H + 1)))
    draw_cell "$i" "$x" "$y"
  done

  if [ "$selected" -ge "$N" ]; then selected=$((N - 1)); fi

  key=""
  read -r -t 0.7 -n1 key
  rc=$?
  [ "$rc" -gt 128 ] && continue
  [ "$rc" -ne 0 ] && break

  case "$key" in
    q | Q) break ;;
    $'\n' | $'\r') jump_to "$selected" ;;
    $'\x1b')
      a=""; b=""
      read -r -t 0.05 -n1 a || a=""
      [ -z "$a" ] && break
      read -r -t 0.05 -n1 b || b=""
      case "$a$b" in
        '[A') selected=$(((selected - COLS + N) % N)) ;;
        '[B') selected=$(((selected + COLS) % N)) ;;
        '[C') selected=$(((selected + 1) % N)) ;;
        '[D') selected=$(((selected - 1 + N) % N)) ;;
      esac
      ;;
    [0-9])
      n=${key#0}
      [ "$key" = "0" ] && n=10
      [ "$n" -le "$N" ] && jump_to $((n - 1))
      ;;
  esac
done

exit 0
