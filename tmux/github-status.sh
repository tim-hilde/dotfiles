#!/usr/bin/env bash

cache_file="${GH_STATUS_CACHE:-/tmp/gh-status-indicator}"
cache_ttl=60

command -v curl >/dev/null 2>&1 || exit 0

get_mtime() {
  if stat --version &>/dev/null; then
    stat -c %Y "$1"
  else
    stat -f %m "$1"
  fi
}

cached=""
[ -f "$cache_file" ] && cached=$(<"$cache_file")

if [[ -n "$cached" ]]; then
  age=$(( $(date +%s) - $(get_mtime "$cache_file") ))
else
  age=$((cache_ttl + 1))
fi

if [[ $age -ge $cache_ttl ]]; then
  indicator=$(curl -fsS --max-time 5 https://www.githubstatus.com/api/v2/status.json 2>/dev/null \
    | sed -n 's/.*"indicator":[[:space:]]*"\([a-z]*\)".*/\1/p')
  if [[ -n "$indicator" ]]; then
    printf '%s\n' "$indicator" > "$cache_file"
  else
    indicator=$cached
  fi
else
  indicator=$cached
fi

case "$indicator" in
  ""|none) exit 0 ;;
  minor) color=@thm_yellow ;;
  major) color=@thm_peach ;;
  critical) color=@thm_red ;;
  *) color=@thm_overlay_1 ;;
esac

printf '#[range=user|ghstatus]#[fg=#{%s}]● #[norange]#[fg=#{@thm_overlay_0}]│ ' "$color"
