#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
[ -n "${CURL_FIXTURE:-}" ] && [ -f "$CURL_FIXTURE" ] && cat "$CURL_FIXTURE" && exit 0
exit 22
STUB
chmod +x "$tmp/bin/curl"

run() {
  GH_STATUS_CACHE="$tmp/cache" CURL_FIXTURE="${CURL_FIXTURE:-}" \
    PATH="$tmp/bin:/usr/bin:/bin" "$script_dir/github-status.sh"
}

fixture() {
  printf '{"status":{"indicator":"%s"}}' "$1" >"$tmp/fixture.json"
  CURL_FIXTURE="$tmp/fixture.json"
}

assert_color() {
  local indicator="$1" color="$2" out
  fixture "$indicator"
  rm -f "$tmp/cache"
  out=$(run)
  printf '%s' "$out" | grep -q "thm_$color" || {
    echo "expected $color for $indicator, got: $out"
    exit 1
  }
}

assert_color minor yellow
assert_color major peach
assert_color critical red
assert_color weird overlay_1

fixture none
rm -f "$tmp/cache"
out=$(run)
[ -z "$out" ] || { echo "expected no output for none, got: $out"; exit 1; }

fixture minor
rm -f "$tmp/cache"
run >/dev/null
CURL_FIXTURE="$tmp/missing.json"
out=$(run)
printf '%s' "$out" | grep -q "thm_yellow" || {
  echo "expected cached yellow, got: $out"
  exit 1
}

printf 'major\n' >"$tmp/cache"
touch -t 202001010000 "$tmp/cache"
CURL_FIXTURE="$tmp/missing.json"
out=$(run)
printf '%s' "$out" | grep -q "thm_peach" || {
  echo "expected stale peach, got: $out"
  exit 1
}

printf 'none\n' >"$tmp/cache"
touch -t 202001010000 "$tmp/cache"
out=$(run)
[ -z "$out" ] || { echo "expected no output, got: $out"; exit 1; }

echo PASS
