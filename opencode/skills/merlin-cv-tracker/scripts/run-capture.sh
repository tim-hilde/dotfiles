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
# Pin the model so the daily cron run is reproducible regardless of opencode's
# interactive default; overridable via MERLIN_CV_MODEL.
MODEL="${MERLIN_CV_MODEL:-anthropic/claude-sonnet-4-6}"

PROMPT="Aktiviere den Skill 'merlin-cv-tracker' im capture-Modus und folge dem Ablauf exakt. \
Repo-Basis: /Users/tim/code/Merlin. Vault: /Users/tim/Zettelkasten. \
1) Fuehre scripts/commit-collector.sh aus (read-only) und bewahre die NDJSON-Ausgabe auf. \
Wenn leer: beende ohne Aenderung. \
2) Klassifiziere die neuen Commits gemaess Schema-Vertrag und haenge sie an die \
Monatsnotiz unter _career-log an. 3) ERST NACHDEM die Notiz geschrieben ist: pipe die \
NDJSON-Ausgabe aus Schritt 1 unveraendert in scripts/commit-confirm.sh, um die Commits \
als erledigt zu markieren. Rufe confirm nie vor dem Notiz-Write auf."

if opencode run --agent "$AGENT" --model "$MODEL" "$PROMPT" >> "$OUT_LOG" 2>> "$ERR_LOG"; then
  echo "[$(ts)] run-capture ok" >> "$OUT_LOG"
else
  code=$?
  echo "[$(ts)] run-capture FAILED (exit $code)" >> "$ERR_LOG"
  exit "$code"
fi
