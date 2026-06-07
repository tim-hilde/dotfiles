#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$SCRIPT_DIR/commit-collector.sh"
CONFIRM="$SCRIPT_DIR/commit-confirm.sh"
PASS=0; FAIL=0
check() { if [[ "$2" == "$3" ]]; then echo "ok - $1"; PASS=$((PASS+1)); else echo "FAIL - $1"; echo "  expected: $3"; echo "  actual:   $2"; FAIL=$((FAIL+1)); fi; }
contains() { if [[ "$2" == *"$3"* ]]; then echo "ok - $1"; PASS=$((PASS+1)); else echo "FAIL - $1 (missing: $3)"; FAIL=$((FAIL+1)); fi; }

# Helper: confirm every commit in an NDJSON stream (simulates the LLM having written
# the note, then acking the processed commits).
confirm_all() { # $1=ndjson  $2=vault
  printf '%s\n' "$1" | MERLIN_VAULT="$2" "$CONFIRM"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO_BASE="$TMP/repos"; VAULT="$TMP/vault"
mkdir -p "$REPO_BASE/demo" "$VAULT/_career-log"
git -C "$REPO_BASE/demo" init -q
git -C "$REPO_BASE/demo" config user.name "Tim Hildebrandt"
git -C "$REPO_BASE/demo" config user.email "tim@example.com"
echo a > "$REPO_BASE/demo/a.txt"
git -C "$REPO_BASE/demo" add a.txt
git -C "$REPO_BASE/demo" commit -q -m "feat(core): add a"

OUT="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "json mentions repo" "$OUT" '"repo":"demo"'
contains "json mentions subject" "$OUT" 'feat(core): add a'
contains "json has hash field" "$OUT" '"hash":'
# NDJSON contract: exactly one compact JSON object per line (consumer counts/streams by line).
check "single commit is one line" "$(printf '%s' "$OUT" | grep -c '^{')" "1"
check "line is valid json" "$(printf '%s' "$OUT" | jq -c .repo 2>/dev/null)" '"demo"'

# ROOT-CAUSE REGRESSION: collect is READ-ONLY. Running collect alone must NOT write
# state, so an aborted run (note never written) re-offers the same commits next time.
check "collect writes no state" "$([[ -f "$VAULT/_career-log/.merlin-cv-tracker-state.json" ]] && echo yes || echo no)" "no"
OUT_AGAIN="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "uncommitted commit is re-offered (no data loss)" "$OUT_AGAIN" 'feat(core): add a'

# Now CONFIRM the collected commits (simulates note written + ack), then collect again.
confirm_all "$OUT" "$VAULT"
check "state file written after confirm" "$([[ -f "$VAULT/_career-log/.merlin-cv-tracker-state.json" ]] && echo yes)" "yes"
OUT2="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
check "after confirm, commit no longer offered" "$(echo -n "$OUT2" | tr -d '[:space:]')" ""

echo b > "$REPO_BASE/demo/b.txt"
git -C "$REPO_BASE/demo" add b.txt
git -C "$REPO_BASE/demo" commit -q -m "feat(core): add b"
OUT3="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "third run has new commit" "$OUT3" 'feat(core): add b'
check "third run lacks old commit" "$(echo "$OUT3" | grep -c 'add a' || true)" "0"

confirm_all "$OUT3" "$VAULT"
HASHCOUNT="$(jq '.repos.demo.processed_hashes | length' "$VAULT/_career-log/.merlin-cv-tracker-state.json")"
check "two hashes recorded after both confirms" "$HASHCOUNT" "2"

# confirm is idempotent: re-confirming the same commit doesn't duplicate hashes.
confirm_all "$OUT3" "$VAULT"
HASHCOUNT2="$(jq '.repos.demo.processed_hashes | length' "$VAULT/_career-log/.merlin-cv-tracker-state.json")"
check "re-confirm does not duplicate" "$HASHCOUNT2" "2"

# --- merge exclusion + stat field ---
TMP2="$(mktemp -d)"; REPO_BASE2="$TMP2/repos"; VAULT2="$TMP2/vault"
mkdir -p "$REPO_BASE2/m" "$VAULT2/_career-log"
git -C "$REPO_BASE2/m" init -q -b main
git -C "$REPO_BASE2/m" config user.name "Tim Hildebrandt"
git -C "$REPO_BASE2/m" config user.email "tim@example.com"
echo base > "$REPO_BASE2/m/base.txt"; git -C "$REPO_BASE2/m" add .; git -C "$REPO_BASE2/m" commit -q -m "chore: base"
git -C "$REPO_BASE2/m" checkout -q -b feat/x
echo x > "$REPO_BASE2/m/x.txt"; git -C "$REPO_BASE2/m" add .; git -C "$REPO_BASE2/m" commit -q -m "feat(x): real work"
git -C "$REPO_BASE2/m" checkout -q main
git -C "$REPO_BASE2/m" merge -q --no-ff feat/x -m "Merge pull request #42 from org/feat/x"
OUTM="$(MERLIN_REPO_BASE="$REPO_BASE2" MERLIN_VAULT="$VAULT2" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "real commit present" "$OUTM" 'feat(x): real work'
check "merge commit absent" "$(echo "$OUTM" | grep -c 'Merge pull request' || true)" "0"
contains "json has stat field" "$OUTM" '"stat":'
# NDJSON: line count must equal object count (jq -s parses the whole stream into an array).
check "merge-test lines == object count" \
  "$(printf '%s\n' "$OUTM" | grep -c '^{')" \
  "$(printf '%s\n' "$OUTM" | jq -s 'length')"
rm -rf "$TMP2"

# I1: per-repo failure isolation. A broken ".git" (empty dir) must not abort the
# collect run; the good repo's commit is still emitted.
TMP3="$(mktemp -d)"; REPO_BASE3="$TMP3/repos"; VAULT3="$TMP3/vault"
mkdir -p "$REPO_BASE3/good" "$REPO_BASE3/bad/.git" "$VAULT3/_career-log"
git -C "$REPO_BASE3/good" init -q
git -C "$REPO_BASE3/good" config user.name "Tim Hildebrandt"
git -C "$REPO_BASE3/good" config user.email "tim@example.com"
echo g > "$REPO_BASE3/good/g.txt"; git -C "$REPO_BASE3/good" add .; git -C "$REPO_BASE3/good" commit -q -m "feat(good): survives bad repo"
OUTI="$(MERLIN_REPO_BASE="$REPO_BASE3" MERLIN_VAULT="$VAULT3" MERLIN_AUTHOR="Tim" "$COLLECTOR" 2>/dev/null)"
contains "good repo emitted despite broken sibling" "$OUTI" 'feat(good): survives bad repo'
rm -rf "$TMP3"

# M2.1: hash is exactly 40 lowercase hex chars (the invariant dedupe relies on).
TMP4="$(mktemp -d)"; REPO_BASE4="$TMP4/repos"; VAULT4="$TMP4/vault"
mkdir -p "$REPO_BASE4/h" "$VAULT4/_career-log"
git -C "$REPO_BASE4/h" init -q
git -C "$REPO_BASE4/h" config user.name "Tim Hildebrandt"
git -C "$REPO_BASE4/h" config user.email "tim@example.com"
echo h > "$REPO_BASE4/h/h.txt"; git -C "$REPO_BASE4/h" add .; git -C "$REPO_BASE4/h" commit -q -m "feat(h): hash check"
OUTH="$(MERLIN_REPO_BASE="$REPO_BASE4" MERLIN_VAULT="$VAULT4" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
FIRST_HASH="$(echo "$OUTH" | jq -r .hash | head -n1)"
check "hash is 40 chars" "${#FIRST_HASH}" "40"
check "hash is full 40-hex" "$([[ "$FIRST_HASH" =~ ^[0-9a-f]{40}$ ]] && echo yes)" "yes"

# M2.2: dedupe is driven by the HASH WATERMARK, not --since. After confirm, a second
# collect with a WIDE since window (commit still in candidate range) must NOT re-emit.
confirm_all "$OUTH" "$VAULT4"
OUTH2="$(MERLIN_REPO_BASE="$REPO_BASE4" MERLIN_VAULT="$VAULT4" MERLIN_AUTHOR="Tim" MERLIN_BOOTSTRAP_SINCE='1 year ago' "$COLLECTOR")"
check "wide since does not re-emit confirmed hash" "$(echo -n "$OUTH2" | tr -d '[:space:]')" ""
rm -rf "$TMP4"

echo; echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
