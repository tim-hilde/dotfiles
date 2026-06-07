#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$SCRIPT_DIR/commit-collector.sh"
PASS=0; FAIL=0
check() { if [[ "$2" == "$3" ]]; then echo "ok - $1"; PASS=$((PASS+1)); else echo "FAIL - $1"; echo "  expected: $3"; echo "  actual:   $2"; FAIL=$((FAIL+1)); fi; }
contains() { if [[ "$2" == *"$3"* ]]; then echo "ok - $1"; PASS=$((PASS+1)); else echo "FAIL - $1 (missing: $3)"; FAIL=$((FAIL+1)); fi; }

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
contains "json mentions repo" "$OUT" '"repo": "demo"'
contains "json mentions subject" "$OUT" 'feat(core): add a'
contains "json has hash field" "$OUT" '"hash":'

OUT2="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
check "second run is empty" "$(echo -n "$OUT2" | tr -d '[:space:]')" ""

echo b > "$REPO_BASE/demo/b.txt"
git -C "$REPO_BASE/demo" add b.txt
git -C "$REPO_BASE/demo" commit -q -m "feat(core): add b"
OUT3="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "third run has new commit" "$OUT3" 'feat(core): add b'
check "third run lacks old commit" "$(echo "$OUT3" | grep -c 'add a' || true)" "0"

check "state file written" "$([[ -f "$VAULT/_career-log/.merlin-cv-tracker-state.json" ]] && echo yes)" "yes"
HASHCOUNT="$(jq '.repos.demo.processed_hashes | length' "$VAULT/_career-log/.merlin-cv-tracker-state.json")"
check "two hashes recorded" "$HASHCOUNT" "2"

echo; echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
