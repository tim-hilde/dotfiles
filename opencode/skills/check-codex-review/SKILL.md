---
name: check-codex-review
description: Use it when the user wants to wait for, check, or fetch the automated Codex
  review of a pull request in the Merlin-Digital-Solutions GitHub organization, or
  asks to check PR comments until the PR is approved.

---

# Codex-Review abarbeiten (nur Merlin-Digital-Solutions)

1. Prüfe mit `gh repo view --json owner --jq .owner.login`, ob das Repo zur Organisation `Merlin-Digital-Solutions` gehört. Falls nicht, bist du fertig: Dort läuft kein `codex-review.yml`, und es kommt kein Review.
2. Ermittle die PR-Nummer (`gh pr view $ARGUMENTS --json number --jq .number`) und den gepushten Commit (`git rev-parse origin/$ARGUMENTS`) als `<SHA>`.
3. Führe die Schleife unten aus, höchstens 5 Runden.

## Schleife

1. Warte auf das Review. Führe das Skript im Vordergrund aus, mit einem Shell-Timeout von 2700000 ms:

   ```bash
   bash ~/.config/opencode/skills/check-codex-review/scripts/wait-review.sh <PR-NUMBER> 40 <SHA>
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

Sollten die Reviews immer weiter auf Edge Cases der Implementierung verweisen, brich ab und hinterfrage, ob der gewählte Ansatz der richtige ist und ob es eine Alternative gibt. Besprich das mit dem User.

## Abschlussbericht

- Verdict des letzten Reviews und Anzahl der Runden
- Was in welchen Commits behoben wurde
- Offene `Important Suggestions` und `Minor Suggestions`, die du nicht behoben hast
- Zurückgewiesene Befunde mit Begründung
