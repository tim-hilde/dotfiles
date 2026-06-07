#!/usr/bin/env bash
set -euo pipefail

# READ-ONLY collector. Emits new commits (not yet in the state file) as NDJSON.
# It deliberately does NOT write state — that is commit-confirm.sh's job, run only
# AFTER the note has been persisted. This read-then-confirm split prevents data loss:
# if a run aborts before the note is written, no commit is marked processed, so the
# same commits are re-offered on the next run.

MERLIN_REPO_BASE="${MERLIN_REPO_BASE:-/Users/tim/code/Merlin}"
MERLIN_VAULT="${MERLIN_VAULT:-/Users/tim/Zettelkasten}"
MERLIN_AUTHOR="${MERLIN_AUTHOR:-Tim}"
BOOTSTRAP_SINCE="${MERLIN_BOOTSTRAP_SINCE:-30 days ago}"
STATE_FILE="$MERLIN_VAULT/_career-log/.merlin-cv-tracker-state.json"

if [[ -f "$STATE_FILE" ]]; then
  state="$(cat "$STATE_FILE")"
else
  state='{"repos":{}}'
fi

# Emits new-commit JSON for a single repo. Read-only: never mutates state.
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
    # last_processed_at is only a perf PREFILTER, never the dedupe identity — that is
    # processed_hashes. Invariant: the --since window must stay WIDE ENOUGH that any
    # commit not yet in processed_hashes still falls inside it. The -2d backdate plus a
    # stable BOOTSTRAP_SINCE guarantees this for daily runs; a commit is only ever missed
    # if it falls out of BOTH the window AND the hash cap (impossible at cap 2000/daily).
    local parse_in="${last_proc/Z/+0000}"; parse_in="${parse_in%:*}${parse_in##*:}"
    # -v-2d MUST come before -f (BSD applies adjustments in arg order); output format is last.
    since="$(date -j -v-2d -f '%Y-%m-%dT%H:%M:%S%z' "$parse_in" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || echo "$BOOTSTRAP_SINCE")"
  else
    since="$BOOTSTRAP_SINCE"
  fi

  local hash iso subject stat
  while IFS=$'\x1f' read -r hash iso subject || [[ -n "$hash" ]]; do
    [[ -z "$hash" ]] && continue
    # Hashes are full 40-hex and space-delimited in known_set, so a substring
    # test is an exact membership test; it would break with abbreviated %h hashes.
    [[ "$known_set" == *" $hash "* ]] && continue
    # git/grep exit nonzero when shortstat is empty (empty/mode-only commit); stat is best-effort.
    stat="$(git -C "$d" show --shortstat --format='' "$hash" | grep -E 'changed' | head -n1 | sed 's/^ *//' || true)"
    # -c: one compact object per line (NDJSON) so the consumer can count/stream reliably.
    jq -c -n --arg repo "$repo" --arg hash "$hash" --arg date "$iso" --arg subject "$subject" --arg stat "$stat" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject, stat:$stat}'
  done < <(git -C "$d" log --no-merges --author="$MERLIN_AUTHOR" \
             --since="$since" --pretty=format:'%H%x1f%cI%x1f%s')
}

collect_all() {
  for d in "$MERLIN_REPO_BASE"/*/; do
    [[ -d "$d/.git" ]] || continue
    # Isolate per-repo failure: a corrupt/locked git in one repo must not abort the
    # whole collect (set -e), else other repos' new commits would be silently dropped.
    if ! process_repo "$d"; then
      echo "merlin-cv-tracker: skipped repo $(basename "$d") after error" >&2
      continue
    fi
  done
}

# Sort the combined NDJSON globally oldest-first by ISO date so the LLM processes
# commits in chronological order (not repo-by-repo). jq -s reads the whole stream;
# sort_by(.date) on ISO-8601 strings is a correct chronological sort within a fixed
# offset, and the -c output stays one compact object per line.
collect_all | jq -c -s 'sort_by(.date) | .[]'
