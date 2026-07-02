#!/usr/bin/env bash

# Structured data provider for the Hammerspoon menubar agent-fleet module.
# Sibling to agent-fleet.sh (tmux status bar counter): same live-pane +
# pid-liveness filtering as that script, but emits one TSV record per live
# agent instead of a rendered glyph counter.

state_dir="${OC_TMUX_STATE_DIR:-$HOME/.cache/opencode-tmux}"

[ -d "$state_dir" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

# Live pane ids come as "%124"; the plugin names files by the bare id ("124").
while IFS=' ' read -r pane session window pane_idx; do
  f="$state_dir/${pane#%}.json"
  [ -f "$f" ] || continue
  # Skip snapshots whose opencode process is gone: a crashed agent leaves a
  # stale "working" file even while its pane lives on.
  pid=$(sed -n 's/.*"pid":\([0-9]*\).*/\1/p' "$f")
  kill -0 "$pid" 2>/dev/null || continue
  state=$(sed -n 's/.*"state":"\([a-z]*\)".*/\1/p' "$f")
  title=$(sed -n 's/.*"title":"\([^"]*\)".*/\1/p' "$f")
  project=$(sed -n 's/.*"project":"\([^"]*\)".*/\1/p' "$f")
  updated_at=$(sed -n 's/.*"updatedAt":\([0-9]*\).*/\1/p' "$f")
  printf '%s\t%s\t%s:%s.%s\t%s\t%s\t%s\t%s\n' \
    "$state" "$pane" "$session" "$window" "$pane_idx" "$session" "$project" "$title" "$updated_at"
done < <(tmux list-panes -a -F '#{pane_id} #{session_name} #{window_index} #{pane_index}' 2>/dev/null)
