---
name: merlin-cv-tracker
description: >
  Erfasst und klassifiziert Tims Git-Commits in den Merlin-Repos für seinen
  Lebenslauf in Obsidian. Use when capturing daily commit activity for CV
  tracking (capture-Modus, via Cron) oder beim Zusammenfassen erfasster
  Tätigkeiten zu CV-Bullets (synthesize-Modus).
---

# Merlin CV-Tracker

Zwei Modi. Der Aufruf-Prompt nennt den Modus explizit (`capture` oder `synthesize`).

## Gemeinsame Konstanten

- Repo-Basis: `/Users/tim/code/Merlin` (alle Unterordner mit `.git`).
- Vault: `/Users/tim/Zettelkasten`.
- Tier-1-Log: `_career-log/YYYY-MM Commit-Log.md`.
- State: `_career-log/.merlin-cv-tracker-state.json` (vom Collector verwaltet — NIE manuell editieren).
- Tier-2-Notiz: `Merlin Tätigkeiten.md`.
- Collector: `scripts/commit-collector.sh` (relativ zu diesem Skill).

## Capture-Modus (Tier 1)

Ziel: neue Commits klassifizieren und an die Monatsnotiz anhängen. **Determinismus
liegt in den Skripten** — du klassifizierst nur.

**Kritische Reihenfolge (kein Datenverlust):** `collect` ist read-only und schreibt
KEINEN State. Erst NACHDEM die Notiz persistiert ist, rufst du `confirm` auf, um die
verarbeiteten Commits als erledigt zu markieren. Brichst du vor dem Notiz-Write ab,
bleibt der State unverändert und dieselben Commits werden beim nächsten Lauf erneut
angeboten.

### Ablauf

1. **Collect** (read-only):
   `bash <skill-dir>/scripts/commit-collector.sh`
   Gibt NDJSON aus (eine kompakte Zeile pro Commit: `repo, hash, date, subject, stat`).
   **Bewahre diese exakte Ausgabe** für Schritt 5 auf. Leere Ausgabe → nichts Neues →
   sauberer Exit, KEIN Notiz-Write, KEIN confirm.
2. Die Commits nach **logischer Einheit** bündeln (zusammengehörige Commits eines
   Themas/Feature-Bereichs), NICHT 1:1 pro Commit.
3. Pro Einheit einen Eintrag im Schema-Vertrag (unten) erzeugen.
4. An `_career-log/YYYY-MM Commit-Log.md` anhängen (Monat aus dem jüngsten Commit-Datum).
   Existiert die Monatsnotiz nicht, mit Frontmatter-Header anlegen.
   **Verifiziere, dass die Notiz wirklich geschrieben wurde, bevor du fortfährst.**
5. **Confirm** (erst jetzt, State-Write): die in Schritt 1 erhaltene NDJSON-Ausgabe
   unverändert in `confirm` pipen:
   `printf '%s\n' "<NDJSON aus Schritt 1>" | bash <skill-dir>/scripts/commit-confirm.sh`
   Das markiert genau die verarbeiteten Commits als erledigt (idempotent, atomar).
   Confirme NUR die Commits, die tatsächlich in der Notiz gelandet sind.

### Schema-Vertrag (Pflichtfelder pro Einheit)

```markdown
## <ISO-Datum des jüngsten Commits der Einheit>
### <Thema> (<repo>)
- **Kompetenz**: <z.B. Observability, Security, Testing, Frontend-Architektur>
- **Stack**: <z.B. Python, TypeScript, Langfuse, Docker>
- **Zusammenfassung**: <1 Satz, was fachlich passiert ist>
- **Impact**: <geschätzt, ehrlich; "(geschätzt) …" oder weglassen wenn nicht ableitbar>
- **Offene Deutung**: <alternative Lesart(en) für spätere Synthese>
> Rohdaten (nicht editieren) — <n> Commits<, PR #… falls aus Subject erkennbar>:
> - `<repo>` `<short-hash>` <ISO-Datum> — <subject> [<branch|PR falls bekannt>] (<stat-kurzform>)
> - …
```

Regeln:
- **Rohdaten wörtlich.** Subject unverändert übernehmen. Short-Hash = erste 7 Zeichen
  des `hash`-Felds. `stat`-Feld als Kurzform übernehmen.
- PR-/Branch-Kontext nur eintragen, wenn aus einem Merge-Subject oder Branch-Präfix
  ableitbar; sonst weglassen — nicht erfinden.
- **Impact niemals erfinden.** Im Zweifel weglassen.
- Keine Kommentare/Narration außerhalb des Schemas.

### Monatsnotiz-Header (beim ersten Anlegen)

```markdown
---
Links: "[[Berufliche Zukunftsplanung]]"
type: career-log
---
# <Monat Jahr> — Commit-Log
```

### Schreiben (CLI + Fallback)

- Bevorzugt: `obsidian append path="_career-log/<YYYY-MM> Commit-Log.md" content="…"`.
- Fallback (Obsidian nicht erreichbar / headless): atomarer Datei-Append an
  `/Users/tim/Zettelkasten/_career-log/<YYYY-MM> Commit-Log.md` (Datei ggf. mit Header anlegen).

## Synthesize-Modus (Tier 2)

Ziel: aus den erfassten Monats-Logs CV-taugliche Themen-Cluster bauen und
`Merlin Tätigkeiten.md` aktualisieren.

### Lesevertrag

- **Primärquelle sind `Rohdaten` + `Offene Deutung`** jedes Eintrags. Die tägliche
  `Zusammenfassung` ist nur Einstiegshilfe — sie darf das Endergebnis nicht determinieren.
- Alle `_career-log/*.md` lesen (oder den vom Prompt genannten Zeitraum).
- Über Tage/Wochen/Monate hinweg nach **Thema/Kompetenz** clustern, nicht nach Tag.

### Ausgabeformat (CV-Stil, exakt wie `Berufliche Projekte.md`)

```markdown
# <Projekt-/Themen-Titel>

## <Rolle, z.B. Verantwortung für Architektur und Umsetzung>
- <Aspekt>: <Aktiv-Verb + konkrete Tätigkeit + Wirkung>
- <Aspekt>: <…>
- Ergebnis: <messbarer/qualitativer Outcome>
```

Regeln:
- Deutsch, actionable, Muster `Aspekt: Verb + Impact`, jeder Block endet mit `Ergebnis:`.
- Jeder Cluster bekommt am Ende einen kleinen Quell-Verweis (Zeitraum + welche Repos/Logs),
  damit die Herkunft nachvollziehbar bleibt, z.B.:
  `> Quelle: _career-log/2026-05 … 2026-06, merlin-spricht/merlin-dashboard`
- `Merlin Tätigkeiten.md` ist die kuratierte Quelle der Wahrheit. `Lebenslauf.md` wird
  NICHT automatisch verändert — Tim portiert manuell.

### Schreiben

- Bevorzugt `obsidian` CLI auf `Merlin Tätigkeiten.md`; sonst Datei-Write im Vault-Root.
- Bestehende Cluster aktualisieren statt zu duplizieren, wenn das Thema schon existiert.
