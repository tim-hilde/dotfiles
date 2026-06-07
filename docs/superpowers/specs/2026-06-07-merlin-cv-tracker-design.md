# Merlin CV-Tätigkeits-Tracker — Design

**Datum:** 2026-06-07
**Status:** Approved (Brainstorming abgeschlossen)

## Problem

Tim arbeitet seit 2026 als Full-Stack Software Engineer bei Merlin und committet täglich
in mehrere lokale Repositories. Für seinen Lebenslauf (gepflegt in Obsidian) braucht er
eine systematische Erfassung seiner Tätigkeiten. Die Herausforderung:

- Tägliche Commits sind kleinteilig ("fix dial-attempt span numbering").
- Für den CV braucht es den **größeren Kontext** ("Observability für Call-Transfer-Routing
  aufgebaut") — ohne die konkrete Substanz zu verlieren.
- Das Ergebnis muss **CV-actionable** sein (deutsch, im Stil von `Berufliche Projekte.md`).
- **Langlebigkeit:** Auch in 6+ Monaten muss eine spätere Synthese die täglichen Notizen
  sinnvoll zusammenfassen und ggf. **neu** interpretieren können — ohne dass eine zu enge
  Tagesform-Einordnung von heute den Weg verbaut.

## Lösung: Zwei-Tier-Architektur

Trennung nach *Erfassung* (billig, automatisch, täglich) und *Synthese* (teuer, kuratiert,
on-demand).

```
Tier 1 (täglich, Cron, headless)          Tier 2 (on-demand, interaktiv)
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ opencode run "<skill prompt>"│          │ Skill-Aufruf im Chat         │
│  ├─ neue Commits (Hash-Diff)  │          │  ├─ liest alle Monats-Logs   │
│  │   alle Repos, Autor=Tim    │   ──►    │  ├─ clustert nach Thema      │
│  ├─ klassifiziert je Einheit: │  (liest) │  ├─ formuliert CV-Bullets    │
│  │   Thema·Kompetenz·Impact·  │          │  │   (Projekt→Rolle→Impact) │
│  │   Stack·Offene Deutung     │          │  └─ schreibt/aktualisiert    │
│  └─ Rohdaten wörtlich + append│          │     `Merlin Tätigkeiten.md`  │
└──────────────────────────────┘          └──────────────────────────────┘
   schreibt: _career-log/                     Tim portiert → Lebenslauf.md
   YYYY-MM Commit-Log.md
```

## Entscheidungen (aus Brainstorming)

| Frage | Entscheidung |
|-------|--------------|
| Tier-1-Ausführung | Vollautomatisch via `opencode run` headless |
| Tier-1-Ablage | Eine fortlaufende Notiz pro Monat |
| Klassifikations-Tiefe | Reich: Thema + Kompetenz + Impact + Stack |
| Tier-2-Ziel | Eigene Notiz `Merlin Tätigkeiten.md`, manueller Port in CV |
| Tier-2-Trigger | Manuell on-demand per Skill-Aufruf |
| Cron-Mechanismus | launchd (überlebt Reboot/Sleep, passt zum System) |

## Langlebigkeit by Design

Damit Tier 2 auch in 6 Monaten ehrlich neu interpretieren kann, erhält **jeder Tageseintrag
beide Ebenen** — die KI-Interpretation *und* die unveränderten Fakten:

1. **Rohdaten bleiben immer erhalten.** Unveränderte Commit-Subjects + PR-Nummern +
   `--stat`-Zahlen wörtlich. Tier 2 kann jederzeit zur Quelle zurück.
2. **Explizites `Offene Deutung`-Feld.** Tier 1 notiert *alternative Lesarten* statt eine
   einzige Einordnung festzuschreiben. Hält Türen für spätere Erzählungen offen.
3. **Stabiles, maschinen-parsbares Schema.** Feste Feldnamen, `type: career-log` im
   Frontmatter. Tier 2 iteriert zuverlässig über Dutzende Einträge, gruppiert nach
   Kompetenz, spannt Zeiträume.
4. **Tier-2-Lesevertrag.** Synthese arbeitet *primär aus `Rohdaten` + `Offene Deutung`*;
   die tägliche `Zusammenfassung` ist nur Einstiegshilfe. Nicht die Tagesform der KI von
   vor 6 Monaten bestimmt das Endergebnis.

## Komponenten

### 1. Skill `merlin-cv-tracker`

Pfad: `opencode/skills/merlin-cv-tracker/SKILL.md` (im dotfiles-Repo;
`~/.config/opencode` → `~/dotfiles/opencode` per Symlink).

**Pflicht-Frontmatter** (sonst wird der Skill nicht sauber surfaced/aktiviert — kritisch
für den headless-Lauf, der den Skill nur über Prompt-Text triggert):
```yaml
---
name: merlin-cv-tracker
description: >
  Erfasst und klassifiziert Tims Git-Commits in den Merlin-Repos für seinen Lebenslauf
  in Obsidian. Use when capturing daily commit activity for CV tracking (capture-Modus,
  via Cron) oder beim Zusammenfassen erfasster Tätigkeiten zu CV-Bullets (synthesize-Modus).
---
```

Enthält beide Modi in klar getrennten Abschnitten:
- **Capture-Modus (Tier 1):** Repo-Liste, Git-Range-Logik, Klassifikations-Schema als
  Vertrag, Append-Workflow.
- **Synthesize-Modus (Tier 2):** Lesevertrag, Cluster-Logik, CV-Stilregeln.

Plus geteilt: Repo-Liste, CV-Stilregeln (deutsch, actionable, `Aspekt: Verb + Impact`,
endend mit `Ergebnis:`), Pfade, Obsidian-CLI-Nutzung mit Datei-Append-Fallback.

### 2. Tier-1-Datenfluss (täglich)

- **Range & Idempotenz (Hash-Watermark, nicht Datum):** Identität eines Commits ist
  sein **Hash**, nicht das Datum. Datum-basiertes `--since` ist nicht idempotent
  (zieht den Grenztag erneut, dupliziert bei mehreren Läufen/Tag) — wird daher **nicht**
  als Dedupe-Mechanismus verwendet.
  - State-File `_career-log/.merlin-cv-tracker-state.json` hält **pro Repo**:
    `last_run_at` (ISO), `last_processed_at` (ISO, Commit-Zeit des jüngsten erfassten
    Commits), `processed_hashes` (Liste/Set voller SHA-1).
  - **Read-then-confirm-Split (gegen Datenverlust):** Sammeln (`commit-collector.sh`)
    ist **read-only** und schreibt KEINEN State. Der State wird erst durch einen
    separaten Schritt (`commit-confirm.sh`) geschrieben — und zwar **nachdem** die Notiz
    persistiert ist. Bricht der Lauf vor dem Notiz-Write ab, bleibt der State unverändert
    und die Commits werden beim nächsten Lauf erneut angeboten (statt verloren zu gehen,
    weil sie verfrüht als "processed" markiert wurden).
  - Ablauf:
    1. **Collect (read-only):** Kandidaten holen via
       `git log --author='Tim' --since=<last_processed_at minus 2 Tage Sicherheitsfenster>`
       (Datum nur *Vorfilter*, nicht Identität), gegen `processed_hashes` filtern, neue
       Commits als NDJSON ausgeben. Kein State-Write.
    2. LLM klassifiziert → schreibt die Notiz → verifiziert den Write.
    3. **Confirm (State-Write):** die NDJSON der verarbeiteten Commits in
       `commit-confirm.sh` pipen → Hashes pro Repo mergen (dedupe), `last_processed_at`
       (max Commit-Datum) und `last_run_at` fortschreiben, State **atomar** zurückschreiben
       (temp-Datei im State-Dir + rename). Idempotent: Re-Confirm dupliziert nicht.
  - `processed_hashes` wird pro Repo auf die letzten N (z.B. 2000) gekappt, um
    unbegrenztes Wachstum zu vermeiden; das Sicherheitsfenster (`--since`) hält die
    Kandidatenmenge klein genug, dass gekappte alte Hashes nicht erneut auftauchen.
  - **Bootstrap:** fehlt das State-File oder ein Repo-Eintrag → erster Lauf erfasst ab
    `--since='30 days ago'` (konfigurierbar), damit der initiale Lauf nicht die gesamte
    Historie zieht.
- **Filter & Gruppierung:**
  - `--author='Tim'` (deckt `Tim Hildebrandt` ab).
  - **Merge-Commits:** per `--no-merges` aus der Tätigkeits-Erfassung ausgeschlossen.
    Merge-Subjects (`Merge pull request #NNN from …`) werden **separat** geparst, nur um
    PR-Nummer ↔ Branch-Kontext zu gewinnen, und ausschließlich als Kontextfeld an die
    zugehörigen Einzelcommits gehängt — nie als eigene Tätigkeit gezählt.
  - **Dedupe-Identität bleibt der Commit-Hash.** Stehen Merge-Commit und seine
    PR-Einzelcommits beide im Log, werden nur die Einzelcommits als Tätigkeiten
    verarbeitet; der Merge liefert nur PR-Kontext.
  - **Cherry-picks/Rebases** (gleicher Inhalt, neuer Hash) werden als neue Hashes
    behandelt — bewusst akzeptiert (selten, und die Rohdaten machen die Dopplung
    nachvollziehbar). Kein zusätzlicher Patch-ID-Dedupe (YAGNI).
- **Lesen:** `git log` über alle Repos; pro neuem Commit `git show --stat` für LoC,
  und `--format` mit vollem Hash, ISO-Datum, Autor, Subject. Branch/PR aus Merge-Parsing.
- **Klassifikation pro logischer Einheit** (zusammengehörige Commits gebündelt, nicht
  stumpf 1:1):
  - **Thema** — Feature-Bereich (z.B. "Call-Transfer-Observability")
  - **Kompetenz** — z.B. Observability, Security, Testing, Frontend-Architektur
  - **Impact** — geschätzt, ehrlich; leer wenn nicht ableitbar
  - **Stack** — Python/TS/Langfuse/Docker…
  - **Offene Deutung** — alternative Lesarten
  - **Rohdaten** — pro Commit wörtlich und vollständig genug für spätere Rückverfolgung
    und Dedupe: `repo`, **voller Hash**, ISO-Datum, Autor, Subject, Branch/PR (falls aus
    Merge-Parsing bekannt), `--stat`-Kurzform (Dateien, +/− LoC). Subject/PR/LoC allein
    reichen bei mehreren Repos mit ähnlichen Commit-Messages nicht.
- **Ausgabe:** `obsidian append` an `_career-log/YYYY-MM Commit-Log.md`. Bei Monatswechsel
  neue Notiz aus Template-Frontmatter.
- **Leerer Tag:** kein Eintrag, sauberer Exit.

### 3. Tier-1-Notizformat (Schema-Vertrag)

Pfad: `~/Zettelkasten/_career-log/YYYY-MM Commit-Log.md`

```markdown
---
Links: "[[Berufliche Zukunftsplanung]]"
type: career-log
---
# Juni 2026 — Commit-Log

## 2026-06-03
### Call-Transfer-Observability (merlin-spricht)
- **Kompetenz**: Observability, MLOps
- **Stack**: Python, Langfuse
- **Zusammenfassung**: Per-Attempt-Tracing für Anruf-Weiterleitungen via Langfuse-Spans
- **Impact**: (geschätzt) Nachvollziehbarkeit von Transfer-Outcomes im Produktivbetrieb
- **Offene Deutung**: auch lesbar als "Reliability-Engineering" oder "Debugging-Infrastruktur"
> Rohdaten (nicht editieren) — 12 Commits, PR #202/#205:
> - `merlin-spricht` `a1b2c3d` 2026-06-03T14:22 — feat(transfer): emit per-attempt Langfuse span instead of trace metadata [feat/transfer-disconnect-reason] (transfer.py +48/−12)
> - `merlin-spricht` `e4f5a6b` 2026-06-03T13:10 — refactor(transfer): derive dial reason from attempts + harden classifier [feat/transfer-disconnect-reason] (classifier.py +90/−30)
> - `merlin-spricht` `0c1d2e3` 2026-06-02T17:55 — fix(transfer): attribute transfer outcome per commit, not collapsed onto youngest [PR #205] (routing.py +33/−8)
> - … (Gesamt: +340/−110 LoC über 7 Dateien)
```

**Rohdaten-Zeilenformat (Vertrag):**
`` `<repo>` `<short-hash>` <ISO-Datum> — <subject> [<branch|PR>] (<stat-kurzform>) ``
Der **volle Hash** wird zusätzlich im State-File geführt; in der Notiz genügt der
Short-Hash zur Lesbarkeit, da Repo+Short-Hash eindeutig rückverfolgbar ist.

### 4. Tier-2-Synthese-Notiz

Pfad: `~/Zettelkasten/_career-log/Merlin Tätigkeiten.md` (im erlaubten Unterordner —
der Vault-Root ist headless nicht beschreibbar, da opencode `external_directory` auf
Verzeichnis-Ebene prüft).
Exakter CV-Stil, Themen-Cluster über Wochen/Monate aggregiert:

```markdown
# Strukturierte Observability für einen Voicebot

## Verantwortung für Architektur und Umsetzung
- Tracing: Per-Attempt-Spans für Call-Transfer-Routing zur lückenlosen Nachvollziehbarkeit
- Qualitätssicherung: Evaluations- und Regressionstests gegen Halluzinationen im RAG-Pfad
- Ergebnis: Produktionsreife Observability über Voice- und Chat-Kanäle
```

Jeder Cluster trägt einen Quell-Verweis (Logs/Zeiträume), damit Herkunft jedes Bullets
nachvollziehbar bleibt.

### 5. Cron (launchd)

launchd startet mit **minimaler Umgebung** (kein Login-`PATH`, kein `cwd`). Alle
Pfade und Env-Variablen müssen daher explizit gesetzt werden.

**Wrapper-Script** `opencode/skills/merlin-cv-tracker/scripts/run-capture.sh`:
- `#!/usr/bin/env bash`, `set -euo pipefail`.
- Setzt explizit:
  - `export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"`
    (deckt `opencode`, `git`, `obsidian` auf Intel **und** Apple-Silicon ab).
  - `export HOME="/Users/tim"`.
- Verwendet **absolute Pfade** für Vault (`/Users/tim/Zettelkasten`) und Repo-Basis
  (`/Users/tim/code/Merlin`); reicht diese als Variablen an den Prompt weiter.
- Ruft:
  `opencode run --model <fix> --agent <fix> "<expliziter capture-Prompt mit Skill-Name + Modus + absoluten Pfaden>"`.
  Modell/Agent werden **fixiert**, damit der headless-Lauf reproduzierbar ist und nicht
  vom interaktiven Default abhängt.
- Loggt stdout/stderr mit Zeitstempel nach `~/Library/Logs/merlin-cv-tracker.out.log`
  bzw. `.err.log` (zusätzlich zur launchd-Umleitung, für lokale `tail`-Diagnose).
- Exit-Codes: 0 = ok (auch „nichts Neues"), ≠0 = Fehler → landet im Err-Log.

**`opencode run` headless-Verhalten:**
- Non-interaktiv; kein Skill-Flag — Skill wird über den Prompt-Text aktiviert (Modell ruft
  das `skill`-Tool selbst). Prompt nennt Skill-Name + `capture`-Modus eindeutig.
- **Permission-Prompts vermeiden:** Der Lauf darf nicht an Bestätigungen hängen. Der
  capture-Prompt nutzt `--agent build` (`*: allow`). ABER: Der Vault `~/Zettelkasten`
  liegt außerhalb des Projekt-cwd → opencode greift hier `external_directory`, das per
  Default `ask` (= headless auto-reject) ist. **Verifiziert in der Implementierung:** ohne
  explizite Allow-Regel wird der Notiz-Write abgelehnt (Lauf endet mit Exit 0, schreibt
  aber keine Notiz). Lösung in `~/dotfiles/opencode/opencode.json`:
  ```json
  "permission": { "external_directory": {
    "~/Zettelkasten/_career-log/**": "allow"
  }}
  ```
  Wichtig: opencode prüft `external_directory` auf **Verzeichnis-Ebene**. Ein File-Write
  direkt im Vault-Root wird daher trotz dateispezifischer Regel abgelehnt — deshalb liegen
  ALLE Artefakte (Tier-1-Logs, State, Tier-2-Notiz) im erlaubten Unterordner `_career-log/`,
  und Globs/Reads müssen absolute Pfade nutzen. Dank read-then-confirm bleibt der State bei
  einem abgelehnten Write unberührt — kein Datenverlust, der nächste Lauf bietet die Commits
  erneut an.

**launchd-Plist** `~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist`:
- `ProgramArguments`: absoluter Pfad zum Wrapper
  (`/Users/tim/dotfiles/opencode/skills/merlin-cv-tracker/scripts/run-capture.sh`).
- `WorkingDirectory`: `/Users/tim/dotfiles`.
- `EnvironmentVariables`: `PATH` (s.o.) + `HOME` — als zweite Absicherung neben dem Wrapper.
- `StandardOutPath`/`StandardErrorPath`: `~/Library/Logs/merlin-cv-tracker.{out,err}.log`.
- `StartCalendarInterval`: täglich 20:00. (`RunAtLoad` aus, um Doppelläufe beim
  Login zu vermeiden — Idempotenz fängt es trotzdem ab.)

**Manueller Testpfad (Erfolgskriterium):**
1. Wrapper direkt: `bash .../run-capture.sh` → erzeugt Eintrag, schreibt State, exit 0.
2. Zweiter Lauf sofort danach → keine Duplikate (Hash-Watermark greift).
3. Agent laden/triggern:
   `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist`
   dann `launchctl kickstart -k gui/$(id -u)/com.tim.merlin-cv-tracker`.
4. Logs prüfen: `tail ~/Library/Logs/merlin-cv-tracker.*.log`.

**Voraussetzung:** Obsidian läuft (für `obsidian` CLI). **Fallback im Skill:** wenn CLI
nicht erreichbar/headless nicht verfügbar, direkter atomarer Datei-Append an die
Monatsnotiz (gleiches Format), damit der Cron auch ohne laufendes Obsidian funktioniert.

## Repos (Stand 2026-06)

| Repo | Commits | Charakter |
|------|---------|-----------|
| merlin-spricht | 280 | Voice/RAG, Python |
| merlin-schreibt | 144 | Chat, TypeScript |
| merlin-dashboard | 128 | Frontend, TypeScript |
| scraping-infrastructure | 17 | Scraping, Python |
| merlin-services | 10 | Microservices |
| merlin-chunks | 5 | Azure Search Skill, Python |
| stackit-backend | 2 | DB-Schema, Python |

Basis-Pfad: `~/code/Merlin/`. Repo-Liste im Skill konfigurierbar (auto-discovery via
`find ~/code/Merlin -maxdepth 2 -name .git`).

## YAGNI — bewusst NICHT gebaut

- Keine DB / kein Embedding-Index — Markdown reicht.
- Keine automatische CV-Bearbeitung — `Lebenslauf.md` bleibt manuell.
- Kein wöchentlicher Tier-2-Cron — Synthese ist on-demand.

## Erfolgskriterien

1. Skill existiert mit beiden Modi und dokumentiertem Schema-Vertrag, **inkl. gültiger
   OpenCode-Frontmatter** (`name: merlin-cv-tracker` + `description: … Use when …`),
   verifiziert dadurch, dass der Skill sich per Prompt-Text aktivieren lässt.
2. Capture-Modus erzeugt einen validen Tageseintrag mit allen Pflichtfeldern inkl.
   wörtlicher Rohdaten (Repo, voller/Short-Hash, ISO-Datum, Subject, Branch/PR, `--stat`)
   — verifiziert an echten Commits.
3. Idempotenz (Hash-Watermark): zweiter Lauf erzeugt keine Duplikate; State-File wird
   atomar fortgeschrieben. Verifiziert durch zwei aufeinanderfolgende Läufe.
4. Merge-Commits erzeugen keine eigene Tätigkeit, liefern aber PR-Kontext an die
   zugehörigen Einzelcommits.
5. launchd-Agent ist installiert und über den manuellen Testpfad lauffähig
   (Wrapper direkt + `launchctl kickstart`), Logs landen unter `~/Library/Logs/`.
6. Synthesize-Modus liest die Logs (primär `Rohdaten` + `Offene Deutung`) und produziert
   CV-Stil-Bullets in `Merlin Tätigkeiten.md`.
