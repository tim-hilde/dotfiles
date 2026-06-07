#!/usr/bin/env bash
set -euo pipefail

MERLIN_REPO_BASE="${MERLIN_REPO_BASE:-/Users/tim/code/Merlin}"
MERLIN_VAULT="${MERLIN_VAULT:-/Users/tim/Zettelkasten}"
MERLIN_AUTHOR="${MERLIN_AUTHOR:-Tim}"
BOOTSTRAP_SINCE="${MERLIN_BOOTSTRAP_SINCE:-30 days ago}"

emit_repo() {
  local repo_path="$1" repo_name="$2"
  while IFS=$'\x1f' read -r hash iso subject || [[ -n "$hash" ]]; do
    [[ -z "$hash" ]] && continue
    jq -n --arg repo "$repo_name" --arg hash "$hash" --arg date "$iso" --arg subject "$subject" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject}'
  done < <(git -C "$repo_path" log --no-merges --author="$MERLIN_AUTHOR" \
             --since="$BOOTSTRAP_SINCE" --pretty=format:'%H%x1f%cI%x1f%s')
}

for d in "$MERLIN_REPO_BASE"/*/; do
  [[ -d "$d/.git" ]] || continue
  emit_repo "$d" "$(basename "$d")"
done
