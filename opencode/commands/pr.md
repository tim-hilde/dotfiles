---
description: Erstellt eine PR-Zusammenfassung und öffnet einen GitHub PR gegen staging oder dev
agent: build
model: anthropic/claude-sonnet-4-6
---

Erstelle einen GitHub Pull Request für den Branch `$ARGUMENTS`. Gehe so vor:

## Setup

1. Falls `$ARGUMENTS` leer ist oder der Branch nicht existiert, brich ab und melde einen Fehler.
2. Führe `git fetch origin` aus.
3. Prüfe ob `origin/staging` oder `origin/dev` existiert — nimm den ersten, der vorhanden ist, als Target. Falls beide fehlen, frage den User. Verwende **niemals** `main` als Target.
4. Falls der Diff leer ist, melde dass es keine Änderungen gibt und erstelle keinen PR.

## Diff

```bash
git diff origin/<target>..origin/$ARGUMENTS -- . ':(exclude)*.lock'
```

Lock-Files (`*.lock`, `package-lock.json`, `yarn.lock`, `Gemfile.lock`) immer ausschließen.

## Analyse

Bevor du schreibst, kläre mental:

- **Welches Problem** löst dieser PR?
- **Welche Lösung** wurde implementiert?
- **Welche Bereiche/Dateien** wurden geändert, und warum?
- **Seiteneffekte**, Breaking Changes, oder wichtige technische Details?

## PR-Beschreibung

Schreibe die Beschreibung in dieser Struktur (auf Englisch):

```
<conventional-commit-title>

## Summary
One concise paragraph: what problem was solved, what solution was implemented.

## Impact
One concise paragraph: what this changes for users/the system; any side effects, migration notes, or breaking changes worth flagging.

## Changes

### <Logical Group / Feature Area>
- Bullet describing what changed and why
- Bullet for relevant technical detail

### <Next Logical Group>
- ...
```

## Regeln

- Titel im conventional-commit-Format (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `perf:`, `ci:`), max 72 Zeichen.
- Änderungen thematisch gruppieren — nicht jede Datei einzeln auflisten.
- Pro Gruppe 2–3 Bullet Points. Offensichtliches weglassen. Lieber *warum* als *was*.
- Jeder Paragraph/Bullet als eine durchgehende Zeile — keine manuellen Zeilenumbrüche.
- Keine leeren Sections.
- Keine Filler-Phrasen wie "this PR aims to..." oder "we have updated...".

## Qualitäts-Check (vor dem Erstellen)

- [ ] Titel folgt conventional commits und ist ≤72 Zeichen
- [ ] Lock-Files und generierte Dateien wurden ignoriert
- [ ] Jede Change-Gruppe hat eine aussagekräftige Überschrift
- [ ] Bullets erklären *warum*, nicht nur *was*
- [ ] Keine leeren Sections
- [ ] Keine manuellen Zeilenumbrüche innerhalb von Paragraphen/Bullets

## PR erstellen

```bash
gh pr create --base <target> --head $ARGUMENTS --title "<conventional-commit-title>" --body "<pr-beschreibung>"
