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
    tmux new-pane -t "$current_window" -x 40 -y 3 -X 5 -Y 3 -S "fg=#cba6f7" \
      "echo 'No active agents'; sleep 1"
    exit 0
  fi

  # new-pane -y N gives exactly N usable interior lines (verified: no border
  # rows are subtracted, unlike display-popup which ate 2), so height is just
  # count + 2 (one fzf prompt row + one spare) - the same interior the old
  # popup_height of count+4 produced after tmux's 2-line popup border.
  count=${#raw_rows[@]}
  pane_h=$((count + 2))
  [ "$pane_h" -lt 4 ] && pane_h=4
  [ "$pane_h" -gt 22 ] && pane_h=22
  pane_w=80

  # new-pane takes an absolute X/Y, not a percentage like display-popup's
  # auto-centre, so centre it in the window ourselves.
  read -r win_w win_h < <(tmux display -p -t "$current_window" '#{window_width} #{window_height}' 2>/dev/null)
  [[ "$win_w" =~ ^[0-9]+$ ]] || win_w=$pane_w
  [[ "$win_h" =~ ^[0-9]+$ ]] || win_h=$((pane_h + 4))
  [ "$pane_w" -gt "$win_w" ] && pane_w=$win_w
  pos_x=$(((win_w - pane_w) / 2)); [ "$pos_x" -lt 0 ] && pos_x=0
  pos_y=$(((win_h - pane_h) / 2)); [ "$pos_y" -lt 0 ] && pos_y=0

  data_file=$(mktemp)
  printf '%s\n' "${raw_rows[@]}" >"$data_file"

  # A floating pane (tmux 3.7+) instead of display-popup: the popup overlay
  # compositing path flickers when a 60fps opentui pane (opencode) redraws
  # behind it - a tmux 3.7 regression; floating panes use a different render
  # path that doesn't. new-pane is non-blocking so the inner pass removes the
  # data file itself; no -d, so the pane becomes active and fzf gets the keys.
  # (-e sets env for the spawned process, like display-popup's -e did.)
  tmux new-pane -t "$current_window" \
    -x "$pane_w" -y "$pane_h" -X "$pos_x" -Y "$pos_y" -S "fg=#cba6f7" \
    -e AGENT_SWITCH_INNER=1 -e AGENT_SWITCH_DATA="$data_file" "$0"
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
# A floating pane's `tput cols` reports its full interior width (display-popup
# used to eat 2 columns for its border, so the old margin was -4). fzf still
# takes 1 column on the left for its pointer gutter, so -2 lands the status one
# cell short of the right edge without tripping fzf's line-wrap/".." truncation
# (measured: -1 wraps and mangles the status, -2 is the tight fit).
usable_width=$((term_width - 2))
[ "$usable_width" -lt 20 ] && usable_width=20

raw_rows=()
[ -n "$AGENT_SWITCH_DATA" ] && [ -f "$AGENT_SWITCH_DATA" ] && mapfile -t raw_rows <"$AGENT_SWITCH_DATA"

if [ "${#raw_rows[@]}" -eq 0 ]; then
  echo "No active agents"
  read -r -n 1 -s -t 5
  exit 0
fi

# new-pane is non-blocking, so the outer pass exits before the picker is
# done and can't clean up its data file - the inner pass owns it now.
sorted_file=$(mktemp)
trap 'rm -f "$sorted_file" "$fzf_input" "$AGENT_SWITCH_DATA"' EXIT

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

  # fzf's own width math (go-runewidth) treats our Nerd Font icons - Private
  # Use Area codepoints - as "ambiguous width" and renders them as 2 columns,
  # while bash's ${#...} and the terminal both count them as 1. Padding
  # against fzf's inflated width keeps a real row from tripping its own
  # right-edge truncation (its "..") and eating into the status text.
  status_width=$((${#plain_status} + 1))

  # A long AI-generated title could otherwise push the row wider than the
  # popup, forcing pad to its 2-char floor and letting the whole line (with
  # the status now past the visible edge) wrap or get mangled by the
  # terminal - truncate the title itself before that can happen.
  title_shown="$title"
  max_title_len=$((usable_width - prefix_width - status_width - 2))
  if [ "$max_title_len" -gt 3 ] && [ "${#title_shown}" -gt "$max_title_len" ]; then
    title_shown="${title_shown:0:$((max_title_len - 3))}..."
  fi

  plain_name="$(printf '%*s' "$prefix_width" '')${title_shown}"
  pad=$((usable_width - ${#plain_name} - status_width))
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

# Catppuccin Mocha hex values (mirrors the @thm_* vars tmux.conf uses for the
# status bar) - fzf runs as its own process so it can't read tmux's #{@thm_*}
# format variables, only literal colors.
fzf_colors="bg:#1e1e2e,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4"
fzf_colors+=",pointer:#cba6f7,border:#6c7086,prompt:#89b4fa"

selection=$(fzf --delimiter=$'\t' --with-nth=1 --no-sort --exact --ansi --cycle \
  --info=hidden --height="$height" --reverse --color="$fzf_colors" \
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
