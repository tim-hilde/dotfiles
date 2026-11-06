#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/state"

cat >"$tmp/bin/tmux" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  display) printf '%%1\n' ;;
  list-panes) printf '%%1\x1fsess\x1fwin\x1f%%1\n%%2\x1fsess\x1fwin2\x1f%%2\n' ;;
esac
STUB
chmod +x "$tmp/bin/tmux"

printf '{"pane":"%%1","state":"done","title":"Current","project":"demo","pid":%s,"updatedAt":1}\n' "$$" >"$tmp/state/1.json"
printf '{"pane":"%%2","state":"working","title":"Other","project":"demo","pid":%s,"updatedAt":2}\n' "$$" >"$tmp/state/2.json"

out=$(OC_TMUX_STATE_DIR="$tmp/state" PATH="$tmp/bin:/usr/bin:/bin" \
  "$script_dir/agent-switch.sh" --list 80 %1)

pane=$(printf '%s\n' "$out" | awk -F'\t' 'NR==1 {print $2}')
[ "$pane" = "%2" ] || { echo "expected pane %2, got $pane"; exit 1; }
printf '%s\n' "$out" | grep -q 'Other' || { echo "missing title"; exit 1; }
printf '%s\n' "$out" | grep -q 'Current' && { echo "current window leaked"; exit 1; }
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "1" ] || { echo "expected one row"; exit 1; }

mkdir -p "$tmp/empty-state"
out=$(OC_TMUX_STATE_DIR="$tmp/empty-state" PATH="$tmp/bin:/usr/bin:/bin" \
  "$script_dir/agent-switch.sh" --list 80 %1)
[ -z "$out" ] || { echo "expected empty output"; exit 1; }

cat >"$tmp/bin/fzf-tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FZF_ARGS_FILE"
exit 0
STUB
chmod +x "$tmp/bin/fzf-tmux"

FZF_ARGS_FILE="$tmp/args" OC_TMUX_STATE_DIR="$tmp/state" \
  PATH="$tmp/bin:/usr/bin:/bin" "$script_dir/agent-switch.sh" >/dev/null

grep -qx -- '--track' "$tmp/args" || { echo "missing --track"; exit 1; }
grep -qx -- '--id-nth=2' "$tmp/args" || { echo "missing --id-nth=2"; exit 1; }
grep -q 'every(1):reload:' "$tmp/args" || { echo "missing every(1):reload"; exit 1; }
grep -q 'load:transform:' "$tmp/args" || { echo "missing load:transform"; exit 1; }
! grep -qx -- '--listen' "$tmp/args" || { echo "unexpected --listen"; exit 1; }

echo PASS
