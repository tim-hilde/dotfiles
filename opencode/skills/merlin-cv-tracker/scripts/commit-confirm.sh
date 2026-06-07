#!/usr/bin/env bash
set -euo pipefail

# Reads processed commits as NDJSON on stdin (the same objects commit-collector.sh
# emitted) and records their hashes in the state file. Run this ONLY AFTER the note
# has been persisted, so an aborted run never marks unwritten commits as processed.
#
# Per repo it updates: processed_hashes (deduped, capped) and last_processed_at
# (max committer date seen). Idempotent: re-confirming the same commits is a no-op.

MERLIN_VAULT="${MERLIN_VAULT:-/Users/tim/Zettelkasten}"
HASH_CAP="${MERLIN_HASH_CAP:-2000}"
STATE_DIR="$MERLIN_VAULT/_career-log"
STATE_FILE="$STATE_DIR/.merlin-cv-tracker-state.json"

mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE" ]] || echo '{"repos":{}}' > "$STATE_FILE"

now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Slurp stdin into a JSON array; empty/whitespace stdin yields []. Invalid lines abort.
incoming="$(jq -s '.' 2>/dev/null || true)"
[[ -z "$incoming" ]] && incoming='[]'

# Nothing to confirm -> leave state untouched (no spurious last_run bump).
count="$(echo "$incoming" | jq 'length')"
if [[ "$count" -eq 0 ]]; then
  exit 0
fi

state="$(cat "$STATE_FILE")"

# Merge incoming hashes into per-repo processed_hashes (deduped), advance
# last_processed_at to the max committer date, set last_run_at. All in one jq pass.
state="$(jq \
  --argjson incoming "$incoming" \
  --arg now "$now_iso" \
  --argjson cap "$HASH_CAP" '
  reduce ($incoming | group_by(.repo))[] as $g (.;
    ($g[0].repo) as $repo
    | (($g | map(.hash)) ) as $newh
    | (($g | map(.date) | max)) as $maxd
    | (.repos[$repo].processed_hashes // []) as $oldh
    | (($oldh + $newh) | unique) as $allh
    | .repos[$repo] = {
        processed_hashes: ($allh | .[-($cap):]),
        last_processed_at: ([(.repos[$repo].last_processed_at // ""), $maxd] | max),
        last_run_at: $now
      }
  )
' <<<"$state")"

# Temp must share the filesystem with the target so mv is an atomic rename, not
# copy+unlink; mktemp under $TMPDIR would make the mv cross-device on iCloud/network vaults.
tmp="$(mktemp "$STATE_DIR/.merlin-cv-tracker-state.XXXXXX")"
echo "$state" > "$tmp"
mv "$tmp" "$STATE_FILE"
