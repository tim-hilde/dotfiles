#!/usr/bin/env bash

cache_file="/tmp/gh-notifs-count"
cache_ttl=60  # Sekunden

# gh vorhanden?
if ! command -v gh &>/dev/null; then
  exit 0
fi

# Hilfsfunktion: Datei-Timestamp (macOS vs Linux)
get_mtime() {
  if stat --version &>/dev/null; then
    # GNU stat (Linux)
    stat -c %Y "$1"
  else
    # BSD stat (macOS)
    stat -f %m "$1"
  fi
}

# Cache verwenden, wenn frisch genug
if [[ -f "$cache_file" ]]; then
  mtime=$(get_mtime "$cache_file")
  age=$(( $(date +%s) - mtime ))
else
  age=$((cache_ttl + 1))
fi

if [[ $age -ge $cache_ttl ]]; then
  # Neue Abfrage
  count=$(gh api notifications --jq 'length' 2>/dev/null || echo 0)
  echo "$count" > "$cache_file"
else
  count=$(<"$cache_file")
fi

# Nur anzeigen, wenn >0
if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
  echo "#[fg=#{@thm_yellow}] $count #[fg=#{@thm_overlay_0}]│ "
fi
