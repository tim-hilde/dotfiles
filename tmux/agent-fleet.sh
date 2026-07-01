#!/usr/bin/env bash

# Compact fleet counter for the tmux status bar: tallies opencode agents by
# state across LIVE panes only. The tmux-status.js plugin writes a per-pane
# snapshot to $state_dir/<pane>.json but only removes it on a clean exit, so
# crashed sessions leave stale files behind. Keying off tmux's live pane list
# ignores those by construction.

state_dir="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"

[ -d "$state_dir" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

working=0
waiting=0
done_count=0

# Live pane ids come as "%124"; the plugin names files by the bare id ("124").
while IFS= read -r pane; do
  f="$state_dir/${pane#%}.json"
  [ -f "$f" ] || continue
  # Skip snapshots whose opencode process is gone: a crashed agent leaves a
  # stale "working" file even while its pane lives on, which would over-count.
  pid=$(sed -n 's/.*"pid":\([0-9]*\).*/\1/p' "$f")
  kill -0 "$pid" 2>/dev/null || continue
  state=$(sed -n 's/.*"state":"\([a-z]*\)".*/\1/p' "$f")
  case "$state" in
    working) working=$((working + 1)) ;;
    waiting) waiting=$((waiting + 1)) ;;
    done) done_count=$((done_count + 1)) ;;
  esac
done < <(tmux list-panes -a -F '#{pane_id}' 2>/dev/null)

# Nerd Font glyphs (fa-play / fa-pause / fa-check), written as explicit
# codepoints so they can't be silently lost as plain spaces again.
icon_working=$'\uf04b'
icon_waiting=$'\uf04c'
icon_done=$'\uf00c'

out=""
[ "$working" -gt 0 ] && out="${out}#[fg=#{@thm_yellow}] ${icon_working} ${working} "
[ "$waiting" -gt 0 ] && out="${out}#[fg=#{@thm_red}] ${icon_waiting} ${waiting} "
[ "$done_count" -gt 0 ] && out="${out}#[fg=#{@thm_green}] ${icon_done} ${done_count} "

[ -n "$out" ] && printf '%s#[fg=#{@thm_overlay_0}]│ ' "$out"
