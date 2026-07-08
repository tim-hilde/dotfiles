#!/usr/bin/env bash

# Agent picker for tmux: lists opencode agents across all LIVE panes and
# switches to the one you pick. Same truth-filtering as agent-fleet.sh (a
# pane's snapshot only counts if the pane still exists AND its opencode pid
# is still alive), so crashed/stale sessions never show up.
#
# Sort: tmux session first (alphabetical), then work status within each
# session (waiting -> done -> working), then most recently updated.
#
# There is no separate, unselectable "header" row - a bold session name is
# printed as a left-hand prefix on that session's first row, and blank-
# padded to the same width on subsequent rows in the group. Every visible
# row is therefore a real, selectable entry, so arrow-key navigation can
# never land on something that isn't a jump target: no fzf-side
# skip/block/redirect logic is needed. (An earlier design used a genuine
# separator row plus a fzf keybind to skip or redirect off it; that bind
# could not be reliably verified to fire on a real Enter/arrow keypress in
# this tmux popup pty, so this simpler structural fix replaces it.)

state_dir="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"
US=$'\x1f' # unit separator: safe delimiter for tmux format fields

command -v tmux >/dev/null 2>&1 || exit 0
command -v fzf >/dev/null 2>&1 || exit 0
[ -d "$state_dir" ] || exit 0

# display-popup's -h doesn't accept a #() shell expression - it needs a
# literal number at bind time, so a fixed popup height was always either
# too tall (whitespace below a short list) or too short. This script runs
# itself twice: the outer pass builds the FULL row data once (not just a
# count - the inner pass used to redo that same scan from scratch, doubling
# every state-file read and pid check), sizes the popup from the row count,
# and hands the already-built data to the inner pass via a temp file so it
# only has to sort/render/pick, not re-scan every tmux pane again.
if [ -z "$AGENT_SWITCH_INNER" ]; then
  # The window the user is actually sitting in when the shortcut fires -
  # excluded below so the picker never offers to "switch" to where you
  # already are.
  current_window=$(tmux display -p '#{window_id}' 2>/dev/null)

  raw_rows=()

  while IFS="$US" read -r pane_id session_name window_name window_id; do
    [ "$window_id" = "$current_window" ] && continue

    f="$state_dir/${pane_id#%}.json"
    [ -f "$f" ] || continue

    # `read` reports failure at EOF even when it successfully read content
    # if the file has no trailing newline (true here - the plugin writes
    # JSON.stringify output as-is), so its exit code can't gate this; check
    # the content itself instead.
    IFS= read -r content <"$f" 2>/dev/null
    [ -n "$content" ] || continue

    # bash's own =~ (no subprocess) instead of four `sed` spawns per file -
    # sed forking per pane, times every live pane, was the main cost here.
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

  if [ "${#raw_rows[@]}" -eq 0 ]; then
    tmux display-popup -E -h 4 -w 80 "echo 'No active agents'; sleep 1"
    exit 0
  fi

  # +2 for tmux's own popup border (measured empirically - requesting -h N
  # always leaves exactly N-2 usable lines inside) + 2 for fzf's own chrome
  # (--info=hidden collapses its match-count line, but it still needs more
  # than just the bare prompt row - confirmed by user testing: +3 total
  # clipped the last row, +5 left one blank row spare, so +4 is exact).
  count=${#raw_rows[@]}
  popup_height=$((count + 4))
  [ "$popup_height" -lt 6 ] && popup_height=6
  [ "$popup_height" -gt 24 ] && popup_height=24

  data_file=$(mktemp)
  printf '%s\n' "${raw_rows[@]}" >"$data_file"

  # A plain "VAR=1 tmux display-popup ..." only sets VAR for the tmux CLI
  # invocation, not for the process display-popup spawns inside the popup -
  # that needs tmux's own -e flag.
  tmux display-popup -E -e AGENT_SWITCH_INNER=1 -e AGENT_SWITCH_DATA="$data_file" \
    -h "$popup_height" -w 80 "$0"
  rm -f "$data_file"
  exit 0
fi

icon_working=$'\uf04b'
icon_waiting=$'\uf04c'
icon_done=$'\uf00c'

c_reset=$'\033[0m'
c_bold=$'\033[1m'
c_red=$'\033[31m'
c_yellow=$'\033[33m'
c_green=$'\033[32m'

term_width=$(tput cols 2>/dev/null)
[[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80
usable_width=$((term_width - 4))
[ "$usable_width" -lt 20 ] && usable_width=20

raw_rows=()
[ -n "$AGENT_SWITCH_DATA" ] && [ -f "$AGENT_SWITCH_DATA" ] && mapfile -t raw_rows <"$AGENT_SWITCH_DATA"

if [ "${#raw_rows[@]}" -eq 0 ]; then
  echo "No active agents"
  read -r -n 1 -s -t 5
  exit 0
fi

sorted_file=$(mktemp)
trap 'rm -f "$sorted_file" "$fzf_input"' EXIT

printf '%s\n' "${raw_rows[@]}" | sort -t $'\t' -k1,1 -k2,2n -k3,3nr >"$sorted_file"

# Left column width: the longest session name, capped so one long name
# doesn't push the title column (and everyone else's rows) far to the
# right - names over the cap get truncated with "..." instead.
max_session_len=12
prefix_width=0
while IFS=$'\t' read -r sess _; do
  [ "${#sess}" -gt "$prefix_width" ] && prefix_width="${#sess}"
done <"$sorted_file"
[ "$prefix_width" -gt "$max_session_len" ] && prefix_width="$max_session_len"
prefix_width=$((prefix_width + 2))

fzf_input=$(mktemp)
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

  # A long AI-generated title could otherwise push the row wider than the
  # popup, forcing pad to its 2-char floor and letting the whole line (with
  # the status now past the visible edge) wrap or get mangled by the
  # terminal - truncate the title itself before that can happen.
  title_shown="$title"
  max_title_len=$((usable_width - prefix_width - ${#plain_status} - 2))
  if [ "$max_title_len" -gt 3 ] && [ "${#title_shown}" -gt "$max_title_len" ]; then
    title_shown="${title_shown:0:$((max_title_len - 3))}..."
  fi

  plain_name="$(printf '%*s' "$prefix_width" '')${title_shown}"
  pad=$((usable_width - ${#plain_name} - ${#plain_status}))
  [ "$pad" -lt 2 ] && pad=2

  display="${prefix}${title_shown}$(printf '%*s' "$pad" '')${status}"
  printf '%s\t%s\n' "$display" "$pane_id" >>"$fzf_input"
done <"$sorted_file"

# Matches the outer popup_height's margin (count+4, minus the 2 lines tmux's
# border eats) so fzf's own requested height and the space the surrounding
# popup actually gives it agree - otherwise fzf just renders within a
# smaller viewport than the popup provides, still clipping the last rows.
rows=${#raw_rows[@]}
height=$((rows + 2))

{
  esc=$'\033'
  echo "DEBUG term_width=$term_width usable_width=$usable_width prefix_width=$prefix_width"
  cut -f1 "$fzf_input" | sed -E "s/${esc}\[[0-9;]*m//g" | while IFS= read -r l; do
    printf 'DEBUG [len=%d] %s|\n' "${#l}" "$l"
  done
} >> /tmp/agent_switch_debug.log 2>&1

selection=$(fzf --delimiter=$'\t' --with-nth=1 --no-sort --exact --ansi --cycle \
  --info=hidden --height="$height" --reverse \
  <"$fzf_input")

[ -n "$selection" ] || exit 0

pane="${selection##*$'\t'}"
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
