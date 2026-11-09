#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_LOG:-/dev/null}"
[ -n "${CURL_FIXTURE:-}" ] && [ -f "$CURL_FIXTURE" ] && cat "$CURL_FIXTURE" && exit 0
exit 22
STUB
chmod +x "$tmp/bin/curl"

log_calls() {
  [ -f "$tmp/curl.log" ] && wc -l <"$tmp/curl.log" | tr -d ' '
}

run() {
  GH_STATUS_CACHE="$tmp/cache" CURL_FIXTURE="${CURL_FIXTURE:-}" CURL_LOG="$tmp/curl.log" \
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
assert_color under_maintenance overlay_1
assert_color Major2 overlay_1

fixture none
rm -f "$tmp/cache"
out=$(run)
[ -z "$out" ] || { echo "expected no output for none, got: $out"; exit 1; }

rm -f "$tmp/cache"
CURL_FIXTURE="$tmp/missing.json"
out=$(run)
[ -z "$out" ] || { echo "expected no output without cache, got: $out"; exit 1; }

fixture minor
rm -f "$tmp/cache" "$tmp/curl.log"
run >/dev/null
CURL_FIXTURE="$tmp/missing.json"
out=$(run)
printf '%s' "$out" | grep -q "thm_yellow" || {
  echo "expected cached yellow, got: $out"
  exit 1
}
[ "$(log_calls)" = "1" ] || {
  echo "expected one request with a fresh cache, got: $(log_calls)"
  exit 1
}
grep -q 'https://www.githubstatus.com/api/v2/status.json' "$tmp/curl.log" || {
  echo "unexpected status URL"
  exit 1
}
grep -q -- '--max-time 5' "$tmp/curl.log" || {
  echo "missing --max-time 5"
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
