#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/agent-fleet-list.sh"
PASS=0; FAIL=0
check() { if [[ "$2" == "$3" ]]; then echo "ok - $1"; PASS=$((PASS+1)); else echo "FAIL - $1"; echo "  expected: $3"; echo "  actual:   $2"; FAIL=$((FAIL+1)); fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STATE_DIR="$TMP/state"
mkdir -p "$STATE_DIR"

ALIVE_PID=$$
printf '{"pane":"%%101","state":"working","title":"Fix login bug","project":"dotfiles","pid":%s,"updatedAt":1700000001}' "$ALIVE_PID" > "$STATE_DIR/101.json"
printf '{"pane":"%%102","state":"waiting","title":"Needs approval","project":"merlin","pid":%s,"updatedAt":1700000002}' "$ALIVE_PID" > "$STATE_DIR/102.json"
printf '{"pane":"%%999","state":"working","title":"Ghost session","project":"old-project","pid":%s,"updatedAt":1700000003}' "$ALIVE_PID" > "$STATE_DIR/999.json"
printf '{"pane":"%%103","state":"working","title":"Crashed agent","project":"dotfiles","pid":999999,"updatedAt":1700000004}' > "$STATE_DIR/103.json"

mkdir -p "$TMP/bin"
cat > "$TMP/bin/tmux" <<'TMUXSTUB'
#!/usr/bin/env bash
if [[ "$1" == "list-panes" ]]; then
  printf '%s\n' "%101 dotfiles 1 1" "%102 merlin 2 1" "%103 dotfiles 3 1"
fi
TMUXSTUB
chmod +x "$TMP/bin/tmux"

OUT="$(OC_TMUX_STATE_DIR="$STATE_DIR" PATH="$TMP/bin:$PATH" "$SCRIPT")"

check "two live records emitted" "$(printf '%s\n' "$OUT" | grep -c .)" "2"

expected1=$'working\t%101\tdotfiles:1.1\tdotfiles\tdotfiles\tFix login bug\t1700000001'
expected2=$'waiting\t%102\tmerlin:2.1\tmerlin\tmerlin\tNeeds approval\t1700000002'
check "working record correct" "$(printf '%s\n' "$OUT" | sed -n '1p')" "$expected1"
check "waiting record correct" "$(printf '%s\n' "$OUT" | sed -n '2p')" "$expected2"
check "stale pane (absent from tmux live list) excluded" "$(printf '%s\n' "$OUT" | grep -c 'Ghost session')" "0"
check "dead-pid pane excluded" "$(printf '%s\n' "$OUT" | grep -c 'Crashed agent')" "0"

MISSING_OUT="$(OC_TMUX_STATE_DIR="$TMP/nope" PATH="$TMP/bin:$PATH" "$SCRIPT")"
check "missing state dir produces no output" "$MISSING_OUT" ""

echo; echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
