# merlin-cv-tracker

Zweistufiger Skill: täglich Commits klassifizieren (Tier 1, Cron) und on-demand
zu CV-Bullets synthetisieren (Tier 2).

## Komponenten
- `SKILL.md` — beide Modi (capture/synthesize).
- `scripts/commit-collector.sh` — read-only Commit-Sammlung (Hash-Watermark, NDJSON).
- `scripts/commit-confirm.sh` — schreibt verarbeitete Hashes in den State (nach Notiz-Write).
- `scripts/run-capture.sh` — launchd-Wrapper (Modell gepinnt: `anthropic/claude-sonnet-4-6`).
- `com.tim.merlin-cv-tracker.plist` — Cron-Definition (täglich 20:00).

## Voraussetzung: Vault-Schreibrechte
Der headless-Lauf schreibt nach `~/Zettelkasten` (außerhalb des Projekt-cwd). opencode
behandelt das als `external_directory` und blockiert es per Default (`ask` = headless
auto-reject). In `~/dotfiles/opencode/opencode.json` ist daher freigegeben:
```json
"permission": { "external_directory": {
  "~/Zettelkasten/_career-log/**": "allow"
}}
```
Ohne diese Regel läuft der Wrapper mit Exit 0 durch, schreibt aber keine Notiz
(der State bleibt dank read-then-confirm trotzdem unberührt — keine Commits gehen verloren).

## Collector-Tests
```bash
bash scripts/test-commit-collector.sh
```

## launchd installieren (Symlink — Repo-Datei bleibt Quelle der Wahrheit)
```bash
ln -sf "$PWD/com.tim.merlin-cv-tracker.plist" ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist
launchctl print gui/$(id -u)/com.tim.merlin-cv-tracker | grep 'state ='
```
Plist im Repo geändert? → `launchctl bootout gui/$(id -u)/com.tim.merlin-cv-tracker` dann erneut `bootstrap`.
Falls launchd den Symlink je ablehnt: statt `ln -sf` ein `cp` verwenden.

## Manueller Testpfad
```bash
# 1. Wrapper direkt
bash scripts/run-capture.sh
# 2. zweiter Lauf -> keine Duplikate (Hash-Watermark)
bash scripts/run-capture.sh
# 3. Cron sofort triggern
launchctl kickstart -k gui/$(id -u)/com.tim.merlin-cv-tracker
# 4. Logs
tail ~/Library/Logs/merlin-cv-tracker.out.log ~/Library/Logs/merlin-cv-tracker.err.log
```

## Synthese (Tier 2) on-demand
Im Chat: "Aktiviere merlin-cv-tracker im synthesize-Modus für die letzten 2 Monate."

## Deinstallieren
```bash
launchctl bootout gui/$(id -u)/com.tim.merlin-cv-tracker
rm ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist
```
