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

PROMPT="Aktiviere den Skill 'merlin-cv-tracker' im capture-Modus und folge dem Ablauf EXAKT \
(alle Schritte im SKILL.md). Repo-Basis: /Users/tim/code/Merlin. Vault: /Users/tim/Zettelkasten. \
1) commit-collector.sh nach /tmp/merlin-collect.ndjson schreiben; N = Zeilenzahl. Leer -> Ende. \
2) NDJSON nach Kalendertag gruppieren und Tage AELTESTER ZUERST abarbeiten. \
3) Jeden Commit klassifizieren - KEINE Auslassung: jeder Commit MUSS als Rohdaten-Zeile in \
genau einer Einheit erscheinen. 4) An die Monatsnotiz(en) unter _career-log anhaengen, \
Tagesueberschriften chronologisch aufsteigend, Commit in die Notiz SEINES Monats. \
5) PFLICHT: die geschriebenen Rohdaten-Commit-Zeilen zaehlen; muss exakt N sein, sonst \
fehlende ergaenzen. 6) ERST DANN /tmp/merlin-collect.ndjson in commit-confirm.sh pipen. \
Confirm nie vor dem Notiz-Write, und nur Commits, die wirklich in der Notiz stehen."

if opencode run --agent "$AGENT" --model "$MODEL" "$PROMPT" >> "$OUT_LOG" 2>> "$ERR_LOG"; then
  echo "[$(ts)] run-capture ok" >> "$OUT_LOG"
else
  code=$?
  echo "[$(ts)] run-capture FAILED (exit $code)" >> "$ERR_LOG"
  exit "$code"
fi
