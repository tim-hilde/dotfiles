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
- Tier-2-Notiz: `_career-log/Merlin Tätigkeiten.md` (im erlaubten Unterordner, nicht im Vault-Root).
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
   `bash <skill-dir>/scripts/commit-collector.sh > /tmp/merlin-collect.ndjson`
   Gibt NDJSON aus, **global chronologisch sortiert (ältester zuerst)**, eine kompakte
   Zeile pro Commit (`repo, hash, date, subject, stat`). Schreibe die Ausgabe in die
   Datei oben, damit du sie verlässlich weiterverarbeiten kannst. Leere Ausgabe → nichts
   Neues → sauberer Exit, KEIN Notiz-Write, KEIN confirm.
   - Zähle die Commits: `wc -l < /tmp/merlin-collect.ndjson`. Merke dir diese Zahl N.

2. **Tag-weise verarbeiten (gegen Auslassung).** Gruppiere die NDJSON nach `date[0:10]`
   (Kalendertag). Arbeite die Tage in chronologischer Reihenfolge ab — **ältester Tag
   zuerst**. Innerhalb eines Tages nach logischen Einheiten bündeln (zusammengehörige
   Commits eines Themas, NICHT 1:1). So bleibt jede Teilmenge klein genug, dass kein
   Commit verloren geht.
   - Praktisch: `jq -r '.date[0:10]' /tmp/merlin-collect.ndjson | sort -u` liefert die
     Tagesliste; pro Tag mit `jq -c 'select(.date[0:10]=="<TAG>")'` filtern.

3. Pro Einheit einen Eintrag im Schema-Vertrag (unten) erzeugen. **JEDER Commit aus der
   collect-Ausgabe MUSS in genau einer Einheit als Rohdaten-Zeile auftauchen** — keine
   Auslassung, keine Dopplung.

4. An `_career-log/YYYY-MM Commit-Log.md` anhängen. **Die `##`-Tagesüberschriften müssen
   chronologisch aufsteigend sein.** Commits eines Tages stehen unter diesem Tag.
   Monatszuordnung: ein Commit gehört in die Notiz seines eigenen Monats (`date[0:7]`),
   nicht in den Monat der "Einheit". Existiert die Monatsnotiz nicht, mit Frontmatter-
   Header anlegen.

5. **Vollständigkeit verifizieren (PFLICHT vor confirm):** Zähle die Rohdaten-Zeilen, die
   du in die Notiz(en) geschrieben hast (Zeilen, die mit `> - \`` beginnen). Diese Zahl
   MUSS exakt N (aus Schritt 1) sein. Stimmt sie nicht: ergänze die fehlenden Commits,
   bis sie stimmt. Erst dann weiter.

6. **Confirm** (erst jetzt, State-Write): NUR die Commits confirmen, die tatsächlich in
   der Notiz stehen. Im Normalfall (Vollständigkeit ok) ist das die komplette collect-
   Ausgabe:
   `cat /tmp/merlin-collect.ndjson | bash <skill-dir>/scripts/commit-confirm.sh`
   Falls du (ausnahmsweise) nicht alle schreiben konntest: confirme nur die geschriebenen,
   indem du die NDJSON auf deren Hashes filterst. Idempotent, atomar. Nicht-confirmte
   Commits werden beim nächsten Lauf erneut angeboten — kein Verlust.

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
`_career-log/Merlin Tätigkeiten.md` aktualisieren.

### Lesevertrag

- **Primärquelle sind `Rohdaten` + `Offene Deutung`** jedes Eintrags. Die tägliche
  `Zusammenfassung` ist nur Einstiegshilfe — sie darf das Endergebnis nicht determinieren.
- Alle Monats-Logs lesen (oder den vom Prompt genannten Zeitraum).
- **Immer ABSOLUTE Pfade verwenden** (`/Users/tim/Zettelkasten/_career-log/*.md`), nie
  vault-relative Globs. Grund: ein relativer Glob `_career-log/*.md` löst gegen das
  Vault-Root `/Users/tim/Zettelkasten/*` auf und wird headless abgelehnt; der absolute
  Pfad fällt unter die `_career-log/**`-Allow-Regel.
- Über Tage/Wochen/Monate hinweg nach **Thema/Kompetenz** clustern, nicht nach Tag.

### Ausgabeformat (CV-Stil)

Der Stil ist hier vollständig spezifiziert — **lies KEINE externe Vorlage** (z.B.
`Berufliche Projekte.md`); die liegt außerhalb der erlaubten Pfade und wird headless
abgelehnt. Konkretes Muster:

```markdown
# <Projekt-/Themen-Titel>

## <Rolle, z.B. Verantwortung für Architektur und Umsetzung>
- <Aspekt>: <Aktiv-Verb + konkrete Tätigkeit + Wirkung>
- <Aspekt>: <…>
- Ergebnis: <messbarer/qualitativer Outcome>
```

Referenz für den Ton (aus Tims bestehendem CV, hier eingebettet — nicht extern lesen):

```markdown
# End-to-End Entwicklung von RAG-Systemen
## Verantwortung für Architektur und Umsetzung
- Retrieval-Optimierung: Steigerung der Antwortpräzision durch hybride Suchstrategien, Re-Ranking und Advanced Prompting
- MLOps & Observability: Etablierung von Evaluations-Pipelines und Tracing zur Qualitätssicherung im Produktivbetrieb
- Ergebnis: Produktivsetzung eines internen Expertensystems mit signifikanter Reduktion von Recherchezeiten
```

Regeln:
- Deutsch, actionable, Muster `Aspekt: Verb + Impact`, jeder Block endet mit `Ergebnis:`.
- Jeder Cluster bekommt am Ende einen kleinen Quell-Verweis (Zeitraum + welche Repos/Logs),
  damit die Herkunft nachvollziehbar bleibt, z.B.:
  `> Quelle: _career-log/2026-05 … 2026-06, merlin-spricht/merlin-dashboard`
- `_career-log/Merlin Tätigkeiten.md` ist die kuratierte Quelle der Wahrheit.
  `Lebenslauf.md` wird NICHT automatisch verändert — Tim portiert manuell.

### Schreiben

- Ziel ist der absolute Pfad `/Users/tim/Zettelkasten/_career-log/Merlin Tätigkeiten.md`.
  Der Unterordner `_career-log/` ist headless beschreibbar; der Vault-Root NICHT (opencode
  prüft external_directory auf Verzeichnis-Ebene). Direkter Datei-Write mit ABSOLUTEM Pfad.
- Bestehende Cluster aktualisieren statt zu duplizieren, wenn das Thema schon existiert.
