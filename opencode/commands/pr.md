---
description: Erstellt eine PR-Zusammenfassung und öffnet einen GitHub PR gegen staging oder dev
agent: build
model: anthropic/claude-sonnet-4-6
---

Erstelle einen GitHub Pull Request für den Branch `$ARGUMENTS`. Gehe so vor:

1. Führe `git fetch origin` aus.
2. Prüfe ob `origin/staging` oder `origin/dev` existiert — nimm den ersten, der vorhanden ist, als Target. Falls beide fehlen, frage den User. Verwende **niemals** `main` als Target.
3. Führe `git diff origin/<target>..origin/$ARGUMENTS -- . ':(exclude)*.lock'` aus.
4. Analysiere den Diff: Problem, Lösung, betroffene Bereiche.
5. Erstelle daraus folgende PR-Beschreibung (kein Codeblock-Wrapper, keine erklärenden Texte davor oder danach):

<conventional-commit-title>

## Summary
Eine prägnante Zusammenfassung: Problem und Lösung.

## Impact
Auswirkungen, Seiteneffekte, Breaking Changes.

## Changes

### <Themenbereich>
- Was wurde geändert und warum

### <Themenbereich>
- ...

6. Führe dann aus:
   `gh pr create --base <target> --head $ARGUMENTS --title "<conventional-commit-title>" --body "<pr-beschreibung>"`

Regeln:

- Titel im conventional-commit-Format (feat:, fix:, refactor:, chore:, docs:, test:, perf:, ci:), max 72 Zeichen.
- Änderungen thematisch gruppieren, nicht jede Datei einzeln.
- Pro Gruppe 2-3 Bullet Points.
- Jeder Paragraph/Bullet als eine durchgehende Zeile (keine manuellen Umbrüche).
- Auf Englisch.
- Keine leeren Sections.
- Keine Filler-Phrasen wie "this PR aims to...".
- Falls `$ARGUMENTS` leer ist oder der Branch nicht existiert, brich ab und melde einen Fehler.
- Falls der Diff leer ist, melde dass es keine Änderungen gibt und erstelle keinen PR.
