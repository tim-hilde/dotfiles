#!/usr/bin/env bash

# Agent picker for tmux: lists opencode agents across all LIVE panes and
# switches to the one you pick. Same truth-filtering as agent-fleet.sh.
# Sort: tmux session (alphabetical) -> work status (waiting/done/working)
# -> most recently updated. fzf-tmux handles the popup.

state_dir="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"
US=$'\x1f'
script_path=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

command -v tmux >/dev/null 2>&1 || exit 0
[ -d "$state_dir" ] || exit 0

icon_working=$'\uf04b'
icon_waiting=$'\uf04c'
icon_done=$'\uf00c'

c_reset=$'\033[0m'
c_bold=$'\033[1m'
c_red=$'\033[31m'
c_yellow=$'\033[33m'
c_green=$'\033[32m'

build_list() {
  local -a raw_rows=()
  local f content pid state updated_at title prio
  local pane_id session_name window_name window_id
  local sorted_file max_session_len prefix_width usable_width last_session
  local sess prefix status plain_status sess_shown status_width title_shown
  local max_title_len plain_name pad

  while IFS="$US" read -r pane_id session_name window_name window_id; do
    [ "$window_id" = "$current_window" ] && continue

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

    case "$state" in
      waiting) prio=0 ;;
      done) prio=1 ;;
      working) prio=2 ;;
    esac

    raw_rows+=("${session_name}"$'\t'"${prio}"$'\t'"${updated_at}"$'\t'"${title}"$'\t'"${state}"$'\t'"${pane_id}")
  done < <(tmux list-panes -a -F "#{pane_id}${US}#{session_name}${US}#{window_name}${US}#{window_id}" 2>/dev/null)

  [ "${#raw_rows[@]}" -eq 0 ] && return 0

  sorted_file=$(mktemp)
  printf '%s\n' "${raw_rows[@]}" | sort -t $'\t' -k1,1 -k2,2n -k3,3nr >"$sorted_file"

  max_session_len=18
  prefix_width=0
  while IFS=$'\t' read -r sess _; do
    [ "${#sess}" -gt "$prefix_width" ] && prefix_width="${#sess}"
  done <"$sorted_file"
  [ "$prefix_width" -gt "$max_session_len" ] && prefix_width="$max_session_len"
  prefix_width=$((prefix_width + 2))

  usable_width=$((term_width - 6))
  [ "$usable_width" -lt 20 ] && usable_width=20

  last_session=""
  while IFS=$'\t' read -r sess _ _ title state pane_id; do
    case "$state" in
      waiting) plain_status="${icon_waiting} waiting"; status="${c_red}${plain_status}${c_reset}" ;;
      done) plain_status="${icon_done} done"; status="${c_green}${plain_status}${c_reset}" ;;
      working) plain_status="${icon_working} working"; status="${c_yellow}${plain_status}${c_reset}" ;;
    esac

    if [ "$sess" != "$last_session" ]; then
      sess_shown="$sess"
      [ "${#sess_shown}" -gt "$max_session_len" ] && sess_shown="${sess_shown:0:$((max_session_len - 3))}..."
      prefix="${c_bold}${sess_shown}${c_reset}$(printf '%*s' "$((prefix_width - ${#sess_shown}))" '')"
      last_session="$sess"
    else
      prefix="$(printf '%*s' "$prefix_width" '')"
    fi

    status_width=$((${#plain_status}))
    title_shown="$title"
    max_title_len=$((usable_width - prefix_width - status_width - 2))
    if [ "$max_title_len" -gt 3 ] && [ "${#title_shown}" -gt "$max_title_len" ]; then
      title_shown="${title_shown:0:$((max_title_len - 3))}..."
    fi

    plain_name="$(printf '%*s' "$prefix_width" '')${title_shown}"
    pad=$((usable_width - ${#plain_name} - status_width))
    [ "$pad" -lt 2 ] && pad=2

    printf '%s\t%s\n' "${prefix}${title_shown}$(printf '%*s' "$pad" '')${status}" "$pane_id"
  done <"$sorted_file"

  rm -f "$sorted_file"
}

if [ "${1:-}" = "--list" ]; then
  term_width="${2:-80}"
  current_window="${3:-}"
  build_list
  exit 0
fi

command -v fzf-tmux >/dev/null 2>&1 || exit 0

# --jump <pane>: switch to a pane without opening the picker (used by
# ctrl-space inside fzf for preview-only jumps that leave the popup open).
if [ "$1" = "--jump" ] && [ -n "$2" ]; then
  pane="$2"
  session=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
  [ -n "$session" ] || exit 0
  client_tty=$(tmux display -p '#{client_tty}' 2>/dev/null)
  if [ -n "$client_tty" ]; then
    tmux switch-client -c "$client_tty" -t "$session"
  else
    tmux switch-client -t "$session"
  fi
  tmux select-window -t "$pane"
  tmux select-pane -t "$pane"
  exit 0
fi

term_width=$(tput cols 2>/dev/null)
[[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80

current_window=$(tmux display -p '#{window_id}' 2>/dev/null)

fzf_input=$(mktemp)
listfile=$(mktemp)
lastfile=$(mktemp)
trap 'rm -f "$fzf_input" "$listfile" "$lastfile"' EXIT

build_list >"$fzf_input"
cp "$fzf_input" "$lastfile"

if [ ! -s "$fzf_input" ]; then
  tmux display-message "No active agents"
  exit 0
fi

rows=$(wc -l <"$fzf_input" | tr -d ' ')
height=$((rows + 4))
[ "$height" -lt 4 ] && height=4

selection=$(fzf-tmux -p -w 80 -h "$height" -- \
  --track --id-nth=2 \
  --delimiter=$'\t' --with-nth=1 \
  --no-sort --exact --ansi \
  --info=hidden --reverse --cycle \
  --height="$height" \
  --border=rounded \
  --color='bg:#1e1e2e,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,pointer:#cba6f7,label:#cba6f7,border:#cba6f7,separator:#6D7085,prompt:#89b4fa' \
  --bind 'ctrl-space:execute-silent(~/.config/tmux/agent-switch.sh --jump {2}),tab:down,btab:up' \
  --bind "every(1):transform:$script_path --list $term_width $current_window > $listfile; if ! cmp -s $listfile $lastfile; then cp $listfile $lastfile; echo \"reload(cat $lastfile)\"; fi" \
  --bind 'load:transform:[ "$FZF_TOTAL_COUNT" -eq 0 ] && echo abort' \
  <"$fzf_input")

[ -n "$selection" ] || exit 0

pane="${selection##*$'\t'}"
[ -n "$pane" ] || exit 0

session=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
[ -n "$session" ] || exit 0

client_tty=$(tmux display -p '#{client_tty}' 2>/dev/null)
if [ -n "$client_tty" ]; then
  tmux switch-client -c "$client_tty" -t "$session"
else
  tmux switch-client -t "$session"
fi
tmux select-window -t "$pane"
tmux select-pane -t "$pane"
