#!/usr/bin/env bash
# ~/.local/bin/gh-notifs-count

cache_file="/tmp/gh-notifs-count"
cache_ttl=60  # Sekunden

# gh vorhanden?
if ! command -v gh &>/dev/null; then
  exit 0
fi

# Cache verwenden, wenn frisch genug
if [[ -f "$cache_file" && $(($(date +%s) - $(stat -c %Y "$cache_file"))) -lt $cache_ttl ]]; then
  count=$(<"$cache_file")
else
  # Neue Abfrage
  count=$(gh api notifications --jq 'length' 2>/dev/null || echo 0)
  echo "$count" > "$cache_file"
fi

# Nur anzeigen, wenn >0
if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
  # Gib alles aus, was tmux sehen soll
  echo "#[fg=#{@thm_overlay_0}]│ #[fg=#{@thm_yellow}] $count"
fi
