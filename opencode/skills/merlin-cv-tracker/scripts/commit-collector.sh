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

# Processes a single repo dir. Emits commit JSON to stdout and, on success,
# updates the global $state. A failure returns nonzero BEFORE the final $state
# assignment, so $state is left unchanged for that repo (failure isolation).
process_repo() {
  local d="$1"
  local repo; repo="$(basename "$d")"

  local known
  mapfile -t known < <(echo "$state" | jq -r --arg r "$repo" '.repos[$r].processed_hashes // [] | .[]')
  # set -u errors when expanding an empty array; :- substitutes empty string instead.
  local known_set=" ${known[*]:-} "

  local last_proc
  last_proc="$(echo "$state" | jq -r --arg r "$repo" '.repos[$r].last_processed_at // ""')"
  local since
  if [[ -n "$last_proc" ]]; then
    local parse_in="${last_proc/Z/+0000}"; parse_in="${parse_in%:*}${parse_in##*:}"
    # -v-2d MUST come before -f (BSD applies adjustments in arg order); output format is last.
    since="$(date -j -v-2d -f '%Y-%m-%dT%H:%M:%S%z' "$parse_in" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || echo "$BOOTSTRAP_SINCE")"
  else
    since="$BOOTSTRAP_SINCE"
  fi

  local new_hashes=()
  local max_iso=""
  local hash iso subject stat
  while IFS=$'\x1f' read -r hash iso subject || [[ -n "$hash" ]]; do
    [[ -z "$hash" ]] && continue
    # Hashes are full 40-hex and space-delimited in known_set, so a substring
    # test is an exact membership test; it would break with abbreviated %h hashes.
    [[ "$known_set" == *" $hash "* ]] && continue
    # git/grep exit nonzero when shortstat is empty (empty/mode-only commit); stat is best-effort.
    stat="$(git -C "$d" show --shortstat --format='' "$hash" | grep -E 'changed' | head -n1 | sed 's/^ *//' || true)"
    jq -n --arg repo "$repo" --arg hash "$hash" --arg date "$iso" --arg subject "$subject" --arg stat "$stat" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject, stat:$stat}'
    new_hashes+=("$hash")
    [[ "$iso" > "$max_iso" ]] && max_iso="$iso"
  done < <(git -C "$d" log --no-merges --author="$MERLIN_AUTHOR" \
             --since="$since" --pretty=format:'%H%x1f%cI%x1f%s')

  if [[ ${#new_hashes[@]} -gt 0 ]]; then
    local merged
    # ${known[@]:-} guard: set -u errors expanding an empty array; :- defeats that.
    merged="$(printf '%s\n' "${known[@]:-}" "${new_hashes[@]}" | grep -v '^$' | tail -n "$HASH_CAP" | jq -R . | jq -s .)"
    state="$(echo "$state" | jq --arg r "$repo" --arg lp "${max_iso:-$last_proc}" --arg lr "$now_iso" --argjson hh "$merged" \
      '.repos[$r] = {processed_hashes:$hh, last_processed_at:$lp, last_run_at:$lr}')"
  fi
}

for d in "$MERLIN_REPO_BASE"/*/; do
  [[ -d "$d/.git" ]] || continue
  # Isolate per-repo failure: a corrupt/locked git in one repo must not abort the
  # run (set -e), else no state persists and all repos' commits are lost.
  if ! process_repo "$d"; then
    echo "merlin-cv-tracker: skipped repo $(basename "$d") after error" >&2
    continue
  fi
done

# Temp must share the filesystem with the target so mv is an atomic rename, not
# copy+unlink; mktemp under $TMPDIR would make the mv cross-device on iCloud/network vaults.
tmp="$(mktemp "$STATE_DIR/.merlin-cv-tracker-state.XXXXXX")"
echo "$state" > "$tmp"
mv "$tmp" "$STATE_FILE"
