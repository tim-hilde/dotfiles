#!/usr/bin/env bash
set -euo pipefail

# launchd starts with a minimal environment — set everything explicitly so git,
# opencode, jq and obsidian resolve on both Intel and Apple-Silicon Homebrew paths.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/tim"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$HOME/Library/Logs"
mkdir -p "$LOG_DIR"
OUT_LOG="$LOG_DIR/merlin-cv-tracker.out.log"
ERR_LOG="$LOG_DIR/merlin-cv-tracker.err.log"

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
echo "[$(ts)] run-capture start (skill: $SKILL_DIR)" >> "$OUT_LOG"

# build is the primary agent with permission '*: allow', so no headless prompt stalls.
AGENT="${MERLIN_CV_AGENT:-build}"

PROMPT="Aktiviere den Skill 'merlin-cv-tracker' im capture-Modus. \
Repo-Basis: /Users/tim/code/Merlin. Vault: /Users/tim/Zettelkasten. \
Fuehre scripts/commit-collector.sh aus, klassifiziere die neuen Commits gemaess \
Schema-Vertrag und haenge sie an die Monatsnotiz unter _career-log an. \
Wenn keine neuen Commits, beende ohne Aenderung."

# Only pass --model when explicitly overridden; otherwise let opencode pick its default.
model_args=()
if [[ -n "${MERLIN_CV_MODEL:-}" ]]; then
  model_args=(--model "$MERLIN_CV_MODEL")
fi

if opencode run --agent "$AGENT" "${model_args[@]}" "$PROMPT" >> "$OUT_LOG" 2>> "$ERR_LOG"; then
  echo "[$(ts)] run-capture ok" >> "$OUT_LOG"
else
  code=$?
  echo "[$(ts)] run-capture FAILED (exit $code)" >> "$ERR_LOG"
  exit "$code"
fi
