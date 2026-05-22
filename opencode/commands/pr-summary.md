---
description: Erstellt eine PR-Zusammenfassung vom angegebenen Branch gegen staging oder dev
model: anthropic/claude-sonnet-4-6
---

Erstelle eine PR-Zusammenfassung für den Branch $ARGUMENTS. Gehe so vor:

1. Führe `git fetch origin` aus.
2. Prüfe ob `origin/staging` oder `origin/dev` existiert — nimm den ersten, der vorhanden ist, als Target. Falls beide fehlen, frage den User.
3. Führe `git diff origin/<target>..origin/$ARGUMENTS -- . ':(exclude)*.lock'` aus.
4. Analysiere den Diff: Problem, Lösung, betroffene Bereiche.
5. Gib ausschließlich folgendes Markdown aus (kein Codeblock, keine Überschrift davor, kein erklärender Text):

```
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
```

Regeln:

- Titel im conventional-commit-Format (feat:, fix:, refactor:, chore:, docs:, test:, perf:, ci:), max 72 Zeichen.
- Änderungen thematisch gruppieren, nicht jede Datei einzeln.
- Pro Gruppe 2-3 Bullet Points.
- Jeder Paragraph/Bullet als eine durchgehende Zeile (keine manuellen Umbrüche).
- Keine leeren Sections.
- Keine Filler-Phrasen wie "this PR aims to...".
- Kein Codeblock-Wrapper um die Ausgabe.
- Keine "## PR Summary for..."-Überschrift.
