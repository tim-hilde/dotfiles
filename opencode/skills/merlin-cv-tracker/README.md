# merlin-cv-tracker

Zweistufiger Skill: täglich Commits klassifizieren (Tier 1, Cron) und on-demand
zu CV-Bullets synthetisieren (Tier 2).

## Komponenten
- `SKILL.md` — beide Modi (capture/synthesize).
- `scripts/commit-collector.sh` — deterministische Commit-Sammlung (Hash-Watermark).
- `scripts/run-capture.sh` — launchd-Wrapper.
- `com.tim.merlin-cv-tracker.plist` — Cron-Definition (täglich 20:00).

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
