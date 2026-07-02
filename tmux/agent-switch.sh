#!/usr/bin/env bash

# Agent picker for tmux: lists opencode agents across all LIVE panes and
# switches to the one you pick. Same truth-filtering as agent-fleet.sh (a
# pane's snapshot only counts if the pane still exists AND its opencode pid
# is still alive), so crashed/stale sessions never show up.
#
# Sort: work status first (waiting -> done -> working), then most recently
# updated within each status. Session name is shown, dimmed, in parens so
# you keep that context without it driving the grouping.
#
# The pane id is needed to jump after selection, but gum has no --with-nth
# to hide a field from display (unlike fzf), so it's kept out of the piped
# text entirely and looked up afterwards from a temp mapping file instead.

state_dir="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"
US=$'\x1f' # unit separator: safe delimiter for tmux format fields

command -v tmux >/dev/null 2>&1 || exit 0
command -v gum >/dev/null 2>&1 || exit 0
[ -d "$state_dir" ] || exit 0

icon_working=$'\uf04b'
icon_waiting=$'\uf04c'
icon_done=$'\uf00c'

c_reset=$'\033[0m'
c_red=$'\033[31m'
c_yellow=$'\033[33m'
c_green=$'\033[32m'
c_gray=$'\033[90m'

raw_lines=()

while IFS="$US" read -r pane_id session_name window_name; do
  f="$state_dir/${pane_id#%}.json"
  [ -f "$f" ] || continue

  pid=$(sed -n 's/.*"pid":\([0-9]*\).*/\1/p' "$f")
  kill -0 "$pid" 2>/dev/null || continue

  state=$(sed -n 's/.*"state":"\([a-z]*\)".*/\1/p' "$f")
  title=$(sed -n 's/.*"title":"\([^"]*\)".*/\1/p' "$f")
  updated_at=$(sed -n 's/.*"updatedAt":\([0-9]*\).*/\1/p' "$f")
  [ -n "$updated_at" ] || continue

  case "$state" in
    waiting) prio=0; status="${c_red}${icon_waiting} waiting${c_reset}" ;;
    done) prio=1; status="${c_green}${icon_done} done${c_reset}" ;;
    working) prio=2; status="${c_yellow}${icon_working} working${c_reset}" ;;
    *) continue ;;
  esac

  title="${title:-$window_name}"
  [ -n "$title" ] || title="(untitled)"

  display="${title}  ${c_gray}(${session_name})${c_reset}  ${status}"

  raw_lines+=("${prio}"$'\t'"${updated_at}"$'\t'"${display}"$'\t'"${pane_id}")
done < <(tmux list-panes -a -F "#{pane_id}${US}#{session_name}${US}#{window_name}" 2>/dev/null)

if [ "${#raw_lines[@]}" -eq 0 ]; then
  gum style --foreground 240 --padding "1 2" "No active agents"
  read -r -n 1 -s -t 5
  exit 0
fi

sorted_file=$(mktemp)
trap 'rm -f "$sorted_file"' EXIT

printf '%s\n' "${raw_lines[@]}" | sort -t $'\t' -k1,1n -k2,2nr > "$sorted_file"

# Cap the list viewport to the entry count (plus a little headroom) so gum
# doesn't reserve a fixed block of blank rows for short lists.
rows=${#raw_lines[@]}
height=$((rows < 12 ? rows + 1 : 12))

selection=$(cut -f3 "$sorted_file" |
  gum filter --no-fuzzy-sort --no-strip-ansi --height "$height" \
    --prompt '🤖 ' --placeholder 'Pick an agent')

[ -n "$selection" ] || exit 0

pane=$(grep -F -- "$selection" "$sorted_file" | head -1 | cut -f4)
[ -n "$pane" ] || exit 0

session=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
[ -n "$session" ] || exit 0

tmux switch-client -t "$session"
tmux select-window -t "$pane"
tmux select-pane -t "$pane"
