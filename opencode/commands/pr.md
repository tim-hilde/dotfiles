---
description: Erstellt einen GitHub PR und arbeitet das Codex-Review bis zum Approve ab
agent: build
---

Erstelle einen GitHub Pull Request für `$ARGUMENTS`.

Gehe so vor:

## Setup

1. Falls `$ARGUMENTS` leer ist, nicht aus dem Kontext klar ersichtlich ist oder der Branch nicht existiert, brich ab und melde einen Fehler.
2. Führe `git fetch origin` aus.
3. Prüfe ob `origin/staging` oder `origin/dev` existiert — nimm den ersten, der vorhanden ist, als Target. Falls beide fehlen, frage den User. `main` nur verwenden, wenn explizit angegeben.
4. Falls der Diff leer ist, melde dass es keine Änderungen gibt und erstelle keinen PR.

## Diff

```bash
git diff origin/<target>...origin/$ARGUMENTS -- . ':(exclude)*.lock'
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
- Keine Signatur/Footer anhängen (z.B. "Generated with...", "🤖", "Co-Authored-By"). Der Body enthält ausschließlich Title, Summary, Impact, Changes.

## Qualitäts-Check (vor dem Erstellen)

- [ ] Titel folgt conventional commits und ist ≤72 Zeichen
- [ ] Lock-Files und generierte Dateien wurden ignoriert
- [ ] Jede Change-Gruppe hat eine aussagekräftige Überschrift
- [ ] Bullets erklären *warum*, nicht nur *was*
- [ ] Keine leeren Sections
- [ ] Keine manuellen Zeilenumbrüche innerhalb von Paragraphen/Bullets
- [ ] Keine Signatur/Footer im Body (z.B. "Generated with...", "🤖", "Co-Authored-By")

## PR erstellen

```bash
gh pr create --base <target> --head $ARGUMENTS --title "<conventional-commit-title>" --body "<pr-beschreibung>"
```

Anschließend den PR im Browser öffnen

## Codex-Review abarbeiten (nur Merlin-Digital-Solutions)

1. Prüfe mit `gh repo view --json owner --jq .owner.login`, ob das Repo zur Organisation `Merlin-Digital-Solutions` gehört. Falls nicht, bist du fertig: Dort läuft kein `codex-review.yml`, und es kommt kein Review.
2. Ermittle die PR-Nummer (`gh pr view $ARGUMENTS --json number --jq .number`) und den gepushten Commit (`git rev-parse origin/$ARGUMENTS`) als `<SHA>`.
3. Führe die Schleife unten aus, höchstens 5 Runden.

### Schleife

1. Warte auf das Review. Führe das Skript im Vordergrund aus, mit einem Shell-Timeout von 2700000 ms:

   ```bash
   bash ~/.config/opencode/skills/pr-summary/scripts/wait-review.sh <PR-NUMBER> 40 <SHA>
   ```

   - Exit 0: Das Review steht auf stdout.
   - Exit 1: Kein Review nach 40 Minuten. Lies `gh pr checks <PR-NUMBER>`, melde den Stand des Jobs `review` und brich ab.
   - Exit 2: Der PR ist ein Draft, und `codex-review.yml` überspringt Drafts. Gib den PR nicht selbst frei, sondern melde das und brich ab.
2. Die Runde ist blockiert, wenn `Required Changes` nicht `None.` ist oder das `Verdict` nicht Approve lautet. Ist sie nicht blockiert, bist du fertig.
3. Bewerte jeden blockierenden Befund mit dem Skill `receiving-code-review`. Ist ein Befund fachlich falsch, behebe ihn nicht. Brich ab und lege dem User den Befund mit deiner Begründung vor, denn Codex prüft jeden Push neu und würde denselben Befund wieder melden.
4. Wechsle in den Checkout, in dem `$ARGUMENTS` ausgecheckt ist (`git worktree list`). Gibt es keinen, lege einen Worktree an: `git worktree add ../worktrees/$ARGUMENTS $ARGUMENTS`. Bringe den Branch mit `git pull --ff-only` auf den Stand von `origin/$ARGUMENTS`, denn ein Bot kann Commits nachgeschoben haben.
5. Behebe die `Required Changes`. Sind sie leer, aber das Verdict lautet nicht Approve, behebe die `Important Suggestions`, auf die sich das Verdict stützt.
6. Führe die Tests des Projekts aus (Befehl aus `AGENTS.md` oder `CLAUDE.md`, sonst aus `package.json`, `Makefile`, `pyproject.toml` usw.). Committe erst, wenn sie grün sind.
7. Committe auf Englisch im Conventional-Commit-Format und pushe ohne Force. Setze `<SHA>` auf den neuen Commit (`git rev-parse HEAD`) und beginne die nächste Runde.

Ist auch die 5. Runde blockiert, brich ab und melde die offenen Blocker.

### Abschlussbericht

- Verdict des letzten Reviews und Anzahl der Runden
- Was in welchen Commits behoben wurde
- Offene `Important Suggestions` und `Minor Suggestions`, die du nicht behoben hast
- Zurückgewiesene Befunde mit Begründung
