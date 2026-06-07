#!/usr/bin/env bash
set -euo pipefail

MERLIN_REPO_BASE="${MERLIN_REPO_BASE:-/Users/tim/code/Merlin}"
MERLIN_VAULT="${MERLIN_VAULT:-/Users/tim/Zettelkasten}"
MERLIN_AUTHOR="${MERLIN_AUTHOR:-Tim}"
BOOTSTRAP_SINCE="${MERLIN_BOOTSTRAP_SINCE:-30 days ago}"
HASH_CAP="${MERLIN_HASH_CAP:-2000}"
STATE_DIR="$MERLIN_VAULT/_career-log"
STATE_FILE="$STATE_DIR/.merlin-cv-tracker-state.json"

mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE" ]] || echo '{"repos":{}}' > "$STATE_FILE"

now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
state="$(cat "$STATE_FILE")"

for d in "$MERLIN_REPO_BASE"/*/; do
  [[ -d "$d/.git" ]] || continue
  repo="$(basename "$d")"

  mapfile -t known < <(echo "$state" | jq -r --arg r "$repo" '.repos[$r].processed_hashes // [] | .[]')
  known_set=" ${known[*]:-} "

  last_proc="$(echo "$state" | jq -r --arg r "$repo" '.repos[$r].last_processed_at // ""')"
  if [[ -n "$last_proc" ]]; then
    parse_in="${last_proc/Z/+0000}"; parse_in="${parse_in%:*}${parse_in##*:}"
    # -v-2d MUST come before -f (BSD applies adjustments in arg order); output format is last.
    since="$(date -j -v-2d -f '%Y-%m-%dT%H:%M:%S%z' "$parse_in" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || echo "$BOOTSTRAP_SINCE")"
  else
    since="$BOOTSTRAP_SINCE"
  fi

  new_hashes=()
  max_iso=""
  while IFS=$'\x1f' read -r hash iso subject || [[ -n "$hash" ]]; do
    [[ -z "$hash" ]] && continue
    [[ "$known_set" == *" $hash "* ]] && continue
    stat="$(git -C "$d" show --shortstat --format='' "$hash" | grep -E 'changed' | head -n1 | sed 's/^ *//' || true)"
    jq -n --arg repo "$repo" --arg hash "$hash" --arg date "$iso" --arg subject "$subject" --arg stat "$stat" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject, stat:$stat}'
    new_hashes+=("$hash")
    [[ "$iso" > "$max_iso" ]] && max_iso="$iso"
  done < <(git -C "$d" log --no-merges --author="$MERLIN_AUTHOR" \
             --since="$since" --pretty=format:'%H%x1f%cI%x1f%s')

  if [[ ${#new_hashes[@]} -gt 0 ]]; then
    merged="$(printf '%s\n' "${known[@]:-}" "${new_hashes[@]}" | grep -v '^$' | tail -n "$HASH_CAP" | jq -R . | jq -s .)"
    state="$(echo "$state" | jq --arg r "$repo" --arg lp "${max_iso:-$last_proc}" --arg lr "$now_iso" --argjson hh "$merged" \
      '.repos[$r] = {processed_hashes:$hh, last_processed_at:$lp, last_run_at:$lr}')"
  fi
done

tmp="$(mktemp)"
echo "$state" > "$tmp"
mv "$tmp" "$STATE_FILE"
