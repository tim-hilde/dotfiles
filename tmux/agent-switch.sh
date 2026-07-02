#!/usr/bin/env bash

# Agent picker for tmux: lists opencode agents across all LIVE panes and
# switches to the one you pick. Same truth-filtering as agent-fleet.sh (a
# pane's snapshot only counts if the pane still exists AND its opencode pid
# is still alive), so crashed/stale sessions never show up.
#
# Sort: work status first (waiting -> done -> working), then most recently
# updated within each status. Two columns: name (title + dimmed session in
# parens) on the left, status right-aligned to the popup's actual width.
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

# Right-align the status column to the popup's actual width (its own pty,
# sized from the -w/-h the keybind passed to display-popup), minus a small
# margin for gum's own selection indicator/padding.
term_width=$(tput cols 2>/dev/null)
[[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80
usable_width=$((term_width - 4))
[ "$usable_width" -lt 20 ] && usable_width=20

final_lines=()

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
    waiting) prio=0; plain_status="${icon_waiting} waiting"; status="${c_red}${plain_status}${c_reset}" ;;
    done) prio=1; plain_status="${icon_done} done"; status="${c_green}${plain_status}${c_reset}" ;;
    working) prio=2; plain_status="${icon_working} working"; status="${c_yellow}${plain_status}${c_reset}" ;;
    *) continue ;;
  esac

  title="${title:-$window_name}"
  [ -n "$title" ] || title="(untitled)"

  plain_name="${title} (${session_name})"
  pad=$((usable_width - ${#plain_name} - ${#plain_status}))
  [ "$pad" -lt 2 ] && pad=2

  display="${title} ${c_gray}(${session_name})${c_reset}$(printf '%*s' "$pad" '')${status}"
  final_lines+=("${prio}"$'\t'"${updated_at}"$'\t'"${display}"$'\t'"${pane_id}")
done < <(tmux list-panes -a -F "#{pane_id}${US}#{session_name}${US}#{window_name}" 2>/dev/null)

if [ "${#final_lines[@]}" -eq 0 ]; then
  gum style --foreground 240 --padding "1 2" "No active agents"
  read -r -n 1 -s -t 5
  exit 0
fi

sorted_file=$(mktemp)
trap 'rm -f "$sorted_file"' EXIT

printf '%s\n' "${final_lines[@]}" | sort -t $'\t' -k1,1n -k2,2nr > "$sorted_file"

# Cap the list viewport to the entry count (plus a little headroom) so gum
# doesn't reserve a fixed block of blank rows for short lists.
rows=${#final_lines[@]}
height=$((rows < 12 ? rows + 1 : 12))

selection=$(cut -f3 "$sorted_file" |
  gum filter --no-fuzzy-sort --no-strip-ansi --height "$height" \
    --prompt '🤖 ' --placeholder 'Pick an agent')

[ -n "$selection" ] || exit 0

# gum strips ANSI codes from the value it returns even with --no-strip-ansi
# (that flag only affects how it reads/renders stdin), so matching the raw
# selection against the still-colored sorted_file never hits. Strip the same
# codes from sorted_file before comparing.
esc=$'\033'
pane=$(sed -E "s/${esc}\[[0-9;]*m//g" "$sorted_file" | grep -F -- "$selection" | head -1 | cut -f4)
[ -n "$pane" ] || exit 0

session=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
[ -n "$session" ] || exit 0

# switch-client without -c doesn't reliably target the client that actually
# opened this popup; resolving its tty explicitly and passing -c fixes that.
client_tty=$(tmux display -p '#{client_tty}' 2>/dev/null)
if [ -n "$client_tty" ]; then
  tmux switch-client -c "$client_tty" -t "$session"
else
  tmux switch-client -t "$session"
fi
tmux select-window -t "$pane"
tmux select-pane -t "$pane"
