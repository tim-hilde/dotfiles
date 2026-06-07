# Merlin CV-Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein zweistufiger OpenCode-Skill, der täglich (headless via launchd) Tims Git-Commits in den Merlin-Repos klassifiziert und in eine Obsidian-Monatsnotiz schreibt (Tier 1), und on-demand daraus CV-Bullets synthetisiert (Tier 2).

**Architektur:** Die *deterministische* Mechanik (Git-Range, Hash-Watermark, State-File, Markdown-Append) lebt in einem getesteten Bash-Helper (`commit-collector.sh`), nicht im LLM-Prompt. Das LLM macht nur die *unscharfe* Aufgabe (Klassifikation/Synthese), gesteuert durch `SKILL.md`. Ein Wrapper-Script verbindet beides für den Cron. So sind Idempotenz, Dedupe und Rohdaten-Vollständigkeit reproduzierbar testbar.

**Tech Stack:** Bash (Helper + Wrapper), `git`, `jq` (State-JSON), OpenCode Skill-Markdown, launchd (Plist), Obsidian CLI mit Datei-Append-Fallback.

---

## File Structure

| Datei | Verantwortung |
|-------|---------------|
| `opencode/skills/merlin-cv-tracker/SKILL.md` | Skill mit Frontmatter + beide Modi (capture/synthesize), Klassifikations- & Stil-Vertrag |
| `opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh` | Read-only: neue Commits pro Repo via Hash-Watermark sammeln, als NDJSON ausgeben (KEIN State-Write) |
| `opencode/skills/merlin-cv-tracker/scripts/commit-confirm.sh` | Schreibt verarbeitete Commit-Hashes atomar in den State — erst NACH dem Notiz-Write (read-then-confirm, gegen Datenverlust) |
| `opencode/skills/merlin-cv-tracker/scripts/run-capture.sh` | launchd-Wrapper: Env/PATH setzen, Collector laufen lassen, `opencode run` mit capture-Prompt aufrufen, loggen |
| `opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh` | Bash-Tests für den Collector (temp-Repos, Idempotenz, Merge-Filter, Bootstrap) |
| `opencode/skills/merlin-cv-tracker/com.tim.merlin-cv-tracker.plist` | launchd-Definition (täglich 20:00), via **Symlink** in `~/Library/LaunchAgents/` aktiviert (Repo bleibt Quelle der Wahrheit; Kopie nur als Fallback) |
| `opencode/skills/merlin-cv-tracker/README.md` | Kurz-Doku: Installation des Agents, manueller Testpfad |

**Vault-Artefakte (zur Laufzeit erzeugt, nicht im Repo):**
- `~/Zettelkasten/_career-log/YYYY-MM Commit-Log.md`
- `~/Zettelkasten/_career-log/.merlin-cv-tracker-state.json`
- `~/Zettelkasten/Merlin Tätigkeiten.md`

**Konventionen:** `repo-basis = /Users/tim/code/Merlin`, `vault = /Users/tim/Zettelkasten`. Diese sind im Collector als überschreibbare Defaults (`${MERLIN_REPO_BASE:-...}`, `${MERLIN_VAULT:-...}`), damit Tests sie auf temp-Dirs zeigen können.

---

## Task 1: Collector-Gerüst + JSON-Ausgabe für einen einzelnen Commit

**Files:**
- Create: `opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh`
- Test: `opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`

- [ ] **Step 1: Write the failing test**

Datei `test-commit-collector.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTOR="$SCRIPT_DIR/commit-collector.sh"
PASS=0; FAIL=0
check() { # $1=name $2=actual $3=expected
  if [[ "$2" == "$3" ]]; then echo "ok - $1"; PASS=$((PASS+1));
  else echo "FAIL - $1"; echo "  expected: $3"; echo "  actual:   $2"; FAIL=$((FAIL+1)); fi
}
contains() { # $1=name $2=haystack $3=needle
  if [[ "$2" == *"$3"* ]]; then echo "ok - $1"; PASS=$((PASS+1));
  else echo "FAIL - $1 (missing: $3)"; FAIL=$((FAIL+1)); fi
}

# --- fixture: a temp repo base with one repo, one commit by Tim ---
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
REPO_BASE="$TMP/repos"; VAULT="$TMP/vault"
mkdir -p "$REPO_BASE/demo" "$VAULT/_career-log"
git -C "$REPO_BASE/demo" init -q
git -C "$REPO_BASE/demo" config user.name "Tim Hildebrandt"
git -C "$REPO_BASE/demo" config user.email "tim@example.com"
echo a > "$REPO_BASE/demo/a.txt"
git -C "$REPO_BASE/demo" add a.txt
git -C "$REPO_BASE/demo" commit -q -m "feat(core): add a"

# --- test: collector emits JSON containing the repo, subject, and a full hash ---
OUT="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "json mentions repo" "$OUT" '"repo": "demo"'
contains "json mentions subject" "$OUT" 'feat(core): add a'
contains "json has 40-char hash field" "$OUT" '"hash":'

echo; echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`
Expected: FAIL — `commit-collector.sh` existiert nicht / kein Output.

- [ ] **Step 3: Write minimal implementation**

Datei `commit-collector.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

MERLIN_REPO_BASE="${MERLIN_REPO_BASE:-/Users/tim/code/Merlin}"
MERLIN_VAULT="${MERLIN_VAULT:-/Users/tim/Zettelkasten}"
MERLIN_AUTHOR="${MERLIN_AUTHOR:-Tim}"
STATE_FILE="$MERLIN_VAULT/_career-log/.merlin-cv-tracker-state.json"
BOOTSTRAP_SINCE="${MERLIN_BOOTSTRAP_SINCE:-30 days ago}"

emit_repo() {
  local repo_path="$1" repo_name="$2"
  # one JSON object per new commit, newline-delimited
  while IFS=$'\x1f' read -r hash iso subject; do
    [[ -z "$hash" ]] && continue
    jq -n --arg repo "$repo_name" --arg hash "$hash" \
          --arg date "$iso" --arg subject "$subject" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject}'
  done < <(git -C "$repo_path" log --no-merges --author="$MERLIN_AUTHOR" \
             --since="$BOOTSTRAP_SINCE" \
             --pretty=format:'%H%x1f%cI%x1f%s')
}

for d in "$MERLIN_REPO_BASE"/*/; do
  [[ -d "$d/.git" ]] || continue
  emit_repo "$d" "$(basename "$d")"
done
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`
Expected: PASS — 3 ok, FAIL=0.

- [ ] **Step 5: Commit**

```bash
chmod +x opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh
git add opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh \
        opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh
git commit -m "feat(cv-tracker): commit-collector emits per-commit JSON"
```

---

## Task 2: Hash-Watermark — Idempotenz über State-File

**Files:**
- Modify: `opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh`
- Modify: `opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`

- [ ] **Step 1: Write the failing test**

Hänge vor der Schlusszeile (`echo; echo "PASS=..."`) an:

```bash
# --- test: second run yields NO new commits (hash watermark) ---
OUT2="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
check "second run is empty" "$(echo -n "$OUT2" | tr -d '[:space:]')" ""

# --- test: a brand-new commit IS picked up on the next run ---
echo b > "$REPO_BASE/demo/b.txt"
git -C "$REPO_BASE/demo" add b.txt
git -C "$REPO_BASE/demo" commit -q -m "feat(core): add b"
OUT3="$(MERLIN_REPO_BASE="$REPO_BASE" MERLIN_VAULT="$VAULT" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "third run has new commit" "$OUT3" 'feat(core): add b'
check "third run lacks old commit" "$(echo "$OUT3" | grep -c 'add a' || true)" "0"

# --- test: state file exists and records processed hashes for the repo ---
check "state file written" "$([[ -f "$VAULT/_career-log/.merlin-cv-tracker-state.json" ]] && echo yes)" "yes"
HASHCOUNT="$(jq '.repos.demo.processed_hashes | length' "$VAULT/_career-log/.merlin-cv-tracker-state.json")"
check "two hashes recorded" "$HASHCOUNT" "2"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`
Expected: FAIL — "second run is empty" schlägt fehl (Collector kennt noch keinen State, emittiert erneut).

- [ ] **Step 3: Write minimal implementation**

Ersetze `commit-collector.sh` vollständig:

```bash
#!/usr/bin/env bash
set -euo pipefail

MERLIN_REPO_BASE="${MERLIN_REPO_BASE:-/Users/tim/code/Merlin}"
MERLIN_VAULT="${MERLIN_VAULT:-/Users/tim/Zettelkasten}"
MERLIN_AUTHOR="${MERLIN_AUTHOR:-Tim}"
BOOTSTRAP_SINCE="${MERLIN_BOOTSTRAP_SINCE:-30 days ago}"
HASH_CAP="${MERLIN_HASH_CAP:-2000}"
STATE_DIR="$MERLIN_VAULT/_career-log"
STATE_FILE="$STATE_DIR/.merlin-cv-tracker-state.json"

mkdir -p "$STATE_DIR"
[[ -f "$STATE_FILE" ]] || echo '{"repos":{}}' > "$STATE_FILE"

now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
state="$(cat "$STATE_FILE")"

for d in "$MERLIN_REPO_BASE"/*/; do
  [[ -d "$d/.git" ]] || continue
  repo="$(basename "$d")"

  # known hashes for this repo (empty if first time)
  mapfile -t known < <(echo "$state" | jq -r --arg r "$repo" \
    '.repos[$r].processed_hashes // [] | .[]')
  known_set=" ${known[*]} "

  # candidate window: from last_processed minus 2-day safety, else bootstrap
  last_proc="$(echo "$state" | jq -r --arg r "$repo" '.repos[$r].last_processed_at // ""')"
  # NOTE: BSD/macOS `date` syntax (-j -f -v). Do NOT rewrite to GNU date — this targets macOS.
  if [[ -n "$last_proc" ]]; then
    # git's %cI emits an offset like +02:00, not Z; strip ':' from offset for -f parsing.
    parse_in="${last_proc/Z/+0000}"; parse_in="${parse_in%:*}${parse_in##*:}"
    # -v-2d MUST come before -f (BSD applies adjustments in arg order); output format is last.
    since="$(date -j -v-2d -f '%Y-%m-%dT%H:%M:%S%z' "$parse_in" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null \
             || echo "$BOOTSTRAP_SINCE")"
  else
    since="$BOOTSTRAP_SINCE"
  fi

  new_hashes=()
  max_iso=""
  while IFS=$'\x1f' read -r hash iso subject; do
    [[ -z "$hash" ]] && continue
    [[ "$known_set" == *" $hash "* ]] && continue
    jq -n --arg repo "$repo" --arg hash "$hash" --arg date "$iso" --arg subject "$subject" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject}'
    new_hashes+=("$hash")
    [[ "$iso" > "$max_iso" ]] && max_iso="$iso"
  done < <(git -C "$d" log --no-merges --author="$MERLIN_AUTHOR" \
             --since="$since" --pretty=format:'%H%x1f%cI%x1f%s')

  if [[ ${#new_hashes[@]} -gt 0 ]]; then
    merged="$(printf '%s\n' "${known[@]}" "${new_hashes[@]}" | grep -v '^$' \
               | tail -n "$HASH_CAP" | jq -R . | jq -s .)"
    state="$(echo "$state" | jq \
      --arg r "$repo" --arg lp "${max_iso:-$last_proc}" --arg lr "$now_iso" \
      --argjson hh "$merged" \
      '.repos[$r] = {processed_hashes:$hh, last_processed_at:$lp, last_run_at:$lr}')"
  fi
done

# atomic write
tmp="$(mktemp)"
echo "$state" > "$tmp"
mv "$tmp" "$STATE_FILE"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`
Expected: PASS — alle Checks ok, FAIL=0.

- [ ] **Step 5: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh \
        opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh
git commit -m "feat(cv-tracker): hash-watermark idempotency via atomic state file"
```

---

## Task 3: Merge-Filter, Branch/PR-Kontext & --stat in der Ausgabe

**Files:**
- Modify: `opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh`
- Modify: `opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`

- [ ] **Step 1: Write the failing test**

Vor der Schlusszeile anhängen:

```bash
# --- test: merge commits never appear as activities ---
TMP2="$(mktemp -d)"; REPO_BASE2="$TMP2/repos"; VAULT2="$TMP2/vault"
mkdir -p "$REPO_BASE2/m" "$VAULT2/_career-log"
git -C "$REPO_BASE2/m" init -q -b main
git -C "$REPO_BASE2/m" config user.name "Tim Hildebrandt"
git -C "$REPO_BASE2/m" config user.email "tim@example.com"
echo base > "$REPO_BASE2/m/base.txt"; git -C "$REPO_BASE2/m" add .; git -C "$REPO_BASE2/m" commit -q -m "chore: base"
git -C "$REPO_BASE2/m" checkout -q -b feat/x
echo x > "$REPO_BASE2/m/x.txt"; git -C "$REPO_BASE2/m" add .; git -C "$REPO_BASE2/m" commit -q -m "feat(x): real work"
git -C "$REPO_BASE2/m" checkout -q main
git -C "$REPO_BASE2/m" merge -q --no-ff feat/x -m "Merge pull request #42 from org/feat/x"
OUTM="$(MERLIN_REPO_BASE="$REPO_BASE2" MERLIN_VAULT="$VAULT2" MERLIN_AUTHOR="Tim" "$COLLECTOR")"
contains "real commit present" "$OUTM" 'feat(x): real work'
check "merge commit absent" "$(echo "$OUTM" | grep -c 'Merge pull request' || true)" "0"

# --- test: output carries stat (loc) and a files field ---
contains "json has stat field" "$OUTM" '"stat":'
rm -rf "$TMP2"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`
Expected: FAIL — "json has stat field" fehlt (Collector liefert noch kein `stat`). Merge-Check ist dank `--no-merges` schon grün, `stat` nicht.

- [ ] **Step 3: Write minimal implementation**

In `commit-collector.sh` die `jq -n …`-Emission im Loop ersetzen durch eine Variante mit `--stat`-Kurzform:

```bash
    # Summary line only (e.g. "3 files changed, 48 insertions(+), 12 deletions(-)").
    # --shortstat prints exactly that line and nothing else.
    stat="$(git -C "$d" show --shortstat --format='' "$hash" | grep -E 'changed' | head -n1 | sed 's/^ *//')"
    jq -n --arg repo "$repo" --arg hash "$hash" --arg date "$iso" \
          --arg subject "$subject" --arg stat "$stat" \
      '{repo:$repo, hash:$hash, date:$date, subject:$subject, stat:$stat}'
```

(Die Merge-Ausgrenzung ist bereits durch `--no-merges` im `git log` erfüllt — kein Codeänderung nötig. Branch/PR-Anreicherung erfolgt im LLM-Schritt aus dem Merge-Subject; der Collector liefert die Fakten, das Subject trägt `feat(...)`-Präfixe, die das LLM clustert.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh`
Expected: PASS — alle Checks ok, FAIL=0.

- [ ] **Step 5: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh \
        opencode/skills/merlin-cv-tracker/scripts/test-commit-collector.sh
git commit -m "feat(cv-tracker): exclude merges, add --stat to commit JSON"
```

---

## Task 4: SKILL.md — Frontmatter + Capture-Modus (Klassifikationsvertrag)

**Files:**
- Create: `opencode/skills/merlin-cv-tracker/SKILL.md`

- [ ] **Step 1: Write the failing test (frontmatter validation)**

Es gibt kein Test-Framework für Markdown; wir verifizieren die Pflicht-Frontmatter mit einem Grep-Check. Lege ihn als Schritt fest:

Run (Expected: FAIL, Datei fehlt):
```bash
grep -q '^name: merlin-cv-tracker$' opencode/skills/merlin-cv-tracker/SKILL.md \
  && grep -q 'Use when' opencode/skills/merlin-cv-tracker/SKILL.md \
  && echo FRONTMATTER_OK
```

- [ ] **Step 2: Write SKILL.md (capture half)**

```markdown
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
liegt im Collector** — du klassifizierst nur.

### Ablauf

1. Collector ausführen:
   `bash <skill-dir>/scripts/commit-collector.sh`
   Er gibt newline-getrennte JSON-Objekte aus (`repo, hash, date, subject, stat`)
   und schreibt den State selbst fort. Leere Ausgabe → nichts Neues → sauberer Exit,
   keine Notiz-Änderung.
2. Die Commits nach **logischer Einheit** bündeln (zusammengehörige Commits eines
   Themas/Feature-Bereichs), NICHT 1:1 pro Commit.
3. Pro Einheit einen Eintrag im Schema-Vertrag (unten) erzeugen.
4. An `_career-log/YYYY-MM Commit-Log.md` anhängen (Monat aus dem jüngsten Commit-Datum).
   Existiert die Monatsnotiz nicht, mit Frontmatter-Header anlegen.

### Schema-Vertrag (Pflichtfelder pro Einheit)

\`\`\`markdown
## <ISO-Datum des jüngsten Commits der Einheit>
### <Thema> (<repo>)
- **Kompetenz**: <z.B. Observability, Security, Testing, Frontend-Architektur>
- **Stack**: <z.B. Python, TypeScript, Langfuse, Docker>
- **Zusammenfassung**: <1 Satz, was fachlich passiert ist>
- **Impact**: <geschätzt, ehrlich; "(geschätzt) …" oder weglassen wenn nicht ableitbar>
- **Offene Deutung**: <alternative Lesart(en) für spätere Synthese>
> Rohdaten (nicht editieren) — <n> Commits<, PR #… falls aus Subject erkennbar>:
> - \`<repo>\` \`<short-hash>\` <ISO-Datum> — <subject> [<branch|PR falls bekannt>] (<stat-kurzform>)
> - …
\`\`\`

Regeln:
- **Rohdaten wörtlich.** Subject unverändert übernehmen. Short-Hash = erste 7 Zeichen
  des `hash`-Felds. `stat`-Feld als Kurzform übernehmen.
- PR-/Branch-Kontext nur eintragen, wenn aus einem Merge-Subject oder Branch-Präfix
  ableitbar; sonst weglassen — nicht erfinden.
- **Impact niemals erfinden.** Im Zweifel weglassen.
- Keine Kommentare/Narration außerhalb des Schemas.

### Monatsnotiz-Header (beim ersten Anlegen)

\`\`\`markdown
---
Links: "[[Berufliche Zukunftsplanung]]"
type: career-log
---
# <Monat Jahr> — Commit-Log
\`\`\`

### Schreiben (CLI + Fallback)

- Bevorzugt: `obsidian append path="_career-log/<YYYY-MM> Commit-Log.md" content="…"`.
- Fallback (Obsidian nicht erreichbar / headless): atomarer Datei-Append an
  `/Users/tim/Zettelkasten/_career-log/<YYYY-MM> Commit-Log.md` (Datei ggf. mit Header anlegen).
```

- [ ] **Step 3: Run frontmatter check to verify it passes**

Run:
```bash
grep -q '^name: merlin-cv-tracker$' opencode/skills/merlin-cv-tracker/SKILL.md \
  && grep -q 'Use when' opencode/skills/merlin-cv-tracker/SKILL.md \
  && echo FRONTMATTER_OK
```
Expected: `FRONTMATTER_OK`

- [ ] **Step 4: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/SKILL.md
git commit -m "feat(cv-tracker): SKILL.md frontmatter + capture-mode contract"
```

---

## Task 5: SKILL.md — Synthesize-Modus (Tier-2-Lesevertrag + CV-Stil)

**Files:**
- Modify: `opencode/skills/merlin-cv-tracker/SKILL.md`

- [ ] **Step 1: Append the synthesize section**

Ans Ende von `SKILL.md` anhängen:

```markdown

## Synthesize-Modus (Tier 2)

Ziel: aus den erfassten Monats-Logs CV-taugliche Themen-Cluster bauen und
`Merlin Tätigkeiten.md` aktualisieren.

### Lesevertrag

- **Primärquelle sind `Rohdaten` + `Offene Deutung`** jedes Eintrags. Die tägliche
  `Zusammenfassung` ist nur Einstiegshilfe — sie darf das Endergebnis nicht determinieren.
- Alle `_career-log/*.md` lesen (oder den vom Prompt genannten Zeitraum).
- Über Tage/Wochen/Monate hinweg nach **Thema/Kompetenz** clustern, nicht nach Tag.

### Ausgabeformat (CV-Stil, exakt wie `Berufliche Projekte.md`)

\`\`\`markdown
# <Projekt-/Themen-Titel>

## <Rolle, z.B. Verantwortung für Architektur und Umsetzung>
- <Aspekt>: <Aktiv-Verb + konkrete Tätigkeit + Wirkung>
- <Aspekt>: <…>
- Ergebnis: <messbarer/qualitativer Outcome>
\`\`\`

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
```

- [ ] **Step 2: Verify both modes are present**

Run:
```bash
grep -q '## Capture-Modus' opencode/skills/merlin-cv-tracker/SKILL.md \
  && grep -q '## Synthesize-Modus' opencode/skills/merlin-cv-tracker/SKILL.md \
  && grep -q 'Ergebnis:' opencode/skills/merlin-cv-tracker/SKILL.md \
  && echo BOTH_MODES_OK
```
Expected: `BOTH_MODES_OK`

- [ ] **Step 3: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/SKILL.md
git commit -m "feat(cv-tracker): synthesize-mode read-contract + CV style"
```

---

## Task 6: launchd-Wrapper-Script

**Files:**
- Create: `opencode/skills/merlin-cv-tracker/scripts/run-capture.sh`

- [ ] **Step 1: Write the failing test (shellcheck + dry structure)**

Run (Expected: FAIL, Datei fehlt):
```bash
test -f opencode/skills/merlin-cv-tracker/scripts/run-capture.sh \
  && bash -n opencode/skills/merlin-cv-tracker/scripts/run-capture.sh \
  && echo WRAPPER_OK
```

- [ ] **Step 2: Write the wrapper**

Datei `run-capture.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# launchd starts with a minimal environment — set everything explicitly.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME="/Users/tim"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$HOME/Library/Logs"
mkdir -p "$LOG_DIR"
OUT_LOG="$LOG_DIR/merlin-cv-tracker.out.log"
ERR_LOG="$LOG_DIR/merlin-cv-tracker.err.log"

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
echo "[$(ts)] run-capture start" >> "$OUT_LOG"

# Fixed model/agent for reproducible headless runs.
MODEL="${MERLIN_CV_MODEL:-anthropic/claude-opus-4-8}"
AGENT="${MERLIN_CV_AGENT:-build}"

PROMPT="Aktiviere den Skill 'merlin-cv-tracker' im capture-Modus. \
Repo-Basis: /Users/tim/code/Merlin. Vault: /Users/tim/Zettelkasten. \
Führe scripts/commit-collector.sh aus, klassifiziere die neuen Commits gemäß \
Schema-Vertrag und hänge sie an die Monatsnotiz unter _career-log an. \
Wenn keine neuen Commits, beende ohne Änderung."

if opencode run --model "$MODEL" --agent "$AGENT" "$PROMPT" \
      >> "$OUT_LOG" 2>> "$ERR_LOG"; then
  echo "[$(ts)] run-capture ok" >> "$OUT_LOG"
else
  code=$?
  echo "[$(ts)] run-capture FAILED (exit $code)" >> "$ERR_LOG"
  exit "$code"
fi
```

- [ ] **Step 3: Run check to verify it passes**

Run:
```bash
chmod +x opencode/skills/merlin-cv-tracker/scripts/run-capture.sh
test -f opencode/skills/merlin-cv-tracker/scripts/run-capture.sh \
  && bash -n opencode/skills/merlin-cv-tracker/scripts/run-capture.sh \
  && echo WRAPPER_OK
```
Expected: `WRAPPER_OK`

- [ ] **Step 4: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/scripts/run-capture.sh
git commit -m "feat(cv-tracker): launchd wrapper with explicit env + logging"
```

---

## Task 7: launchd-Plist

**Files:**
- Create: `opencode/skills/merlin-cv-tracker/com.tim.merlin-cv-tracker.plist`

- [ ] **Step 1: Write the failing test (plutil validation)**

Run (Expected: FAIL, Datei fehlt):
```bash
plutil -lint opencode/skills/merlin-cv-tracker/com.tim.merlin-cv-tracker.plist
```

- [ ] **Step 2: Write the plist**

Datei `com.tim.merlin-cv-tracker.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.tim.merlin-cv-tracker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/tim/dotfiles/opencode/skills/merlin-cv-tracker/scripts/run-capture.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>/Users/tim/dotfiles</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>/Users/tim</string>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/tim/Library/Logs/merlin-cv-tracker.out.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/tim/Library/Logs/merlin-cv-tracker.err.log</string>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>20</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

- [ ] **Step 3: Run validation to verify it passes**

Run: `plutil -lint opencode/skills/merlin-cv-tracker/com.tim.merlin-cv-tracker.plist`
Expected: `… OK`

- [ ] **Step 4: Aktivieren via Symlink + Registrierung verifizieren**

launchd-Symlink-Kompatibilität wurde auf diesem System vorab bestätigt (bootstrap RC=0,
Job registriert, kickstart RC=0). Aktivierung daher per **Symlink** (konsistent mit
`~/.config/opencode`-Stil — Repo-Datei ist die aktive Definition):

```bash
ln -sf /Users/tim/dotfiles/opencode/skills/merlin-cv-tracker/com.tim.merlin-cv-tracker.plist \
       "$HOME/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist"
launchctl bootout gui/$(id -u)/com.tim.merlin-cv-tracker 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist"
launchctl print gui/$(id -u)/com.tim.merlin-cv-tracker | grep -q 'state = ' && echo SYMLINK_REGISTERED_OK
```
Expected: `SYMLINK_REGISTERED_OK`

**Fallback (nur falls obiges fehlschlägt):** statt Symlink kopieren —
`cp .../com.tim.merlin-cv-tracker.plist "$HOME/Library/LaunchAgents/"` — und README
entsprechend anpassen.

- [ ] **Step 5: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/com.tim.merlin-cv-tracker.plist
git commit -m "feat(cv-tracker): launchd plist (daily 20:00), symlink-activated"
```

---

## Task 8: README mit Installations- & Testpfad

**Files:**
- Create: `opencode/skills/merlin-cv-tracker/README.md`

- [ ] **Step 1: Write the README**

```markdown
# merlin-cv-tracker

Zweistufiger Skill: täglich Commits klassifizieren (Tier 1, Cron) und on-demand
zu CV-Bullets synthetisieren (Tier 2).

## Komponenten
- `SKILL.md` — beide Modi (capture/synthesize).
- `scripts/commit-collector.sh` — deterministische Commit-Sammlung (Hash-Watermark).
- `scripts/run-capture.sh` — launchd-Wrapper.
- `com.tim.merlin-cv-tracker.plist` — Cron-Definition.

## Collector-Tests
\`\`\`bash
bash scripts/test-commit-collector.sh
\`\`\`

## launchd installieren (Symlink — Repo-Datei bleibt Quelle der Wahrheit)
\`\`\`bash
ln -sf "$PWD/com.tim.merlin-cv-tracker.plist" ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist
\`\`\`
Plist im Repo geändert? → `launchctl bootout …` dann `bootstrap …` (Symlink bleibt bestehen).
Falls launchd den Symlink je ablehnt: stattdessen `cp` statt `ln -sf`.

## Manueller Testpfad
\`\`\`bash
# 1. Wrapper direkt
bash scripts/run-capture.sh
# 2. zweiter Lauf -> keine Duplikate (Hash-Watermark)
bash scripts/run-capture.sh
# 3. Cron sofort triggern
launchctl kickstart -k gui/$(id -u)/com.tim.merlin-cv-tracker
# 4. Logs
tail ~/Library/Logs/merlin-cv-tracker.out.log ~/Library/Logs/merlin-cv-tracker.err.log
\`\`\`

## Synthese (Tier 2) on-demand
Im Chat: "Aktiviere merlin-cv-tracker im synthesize-Modus für die letzten 2 Monate."

## Deinstallieren
\`\`\`bash
launchctl bootout gui/$(id -u)/com.tim.merlin-cv-tracker
rm ~/Library/LaunchAgents/com.tim.merlin-cv-tracker.plist
\`\`\`
```

- [ ] **Step 2: Commit**

```bash
git add opencode/skills/merlin-cv-tracker/README.md
git commit -m "docs(cv-tracker): README with install + manual test path"
```

---

## Task 9: End-to-End-Verifikation an echten Repos (capture)

**Files:** keine — Verifikationslauf.

- [ ] **Step 1: Collector gegen echte Repos, in eine temp-Vault**

Run:
```bash
TMPV="$(mktemp -d)"
MERLIN_VAULT="$TMPV" MERLIN_BOOTSTRAP_SINCE='7 days ago' \
  bash opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh | head -5
echo "--- state ---"
jq '.repos | keys' "$TMPV/_career-log/.merlin-cv-tracker-state.json"
```
Expected: JSON-Commit-Objekte mit echten Hashes/Subjects; State-File listet bearbeitete Repos.

- [ ] **Step 2: Idempotenz gegen echte Repos**

Run:
```bash
MERLIN_VAULT="$TMPV" bash opencode/skills/merlin-cv-tracker/scripts/commit-collector.sh | wc -l
```
Expected: `0` (zweiter Lauf, alles bereits im Watermark).

- [ ] **Step 3: Capture-Modus headless (echter Lauf in die echte Vault)**

> Voraussetzung: Obsidian läuft. Dieser Schritt schreibt in `~/Zettelkasten/_career-log/`.

Run:
```bash
bash opencode/skills/merlin-cv-tracker/scripts/run-capture.sh
tail -20 ~/Library/Logs/merlin-cv-tracker.out.log
```
Expected: exit 0; eine Monatsnotiz `_career-log/YYYY-MM Commit-Log.md` existiert mit
mindestens einem Schema-konformen Eintrag inkl. wörtlicher Rohdaten.

- [ ] **Step 4: Schema-Konformität der erzeugten Notiz prüfen**

Run:
```bash
NOTE="$HOME/Zettelkasten/_career-log/$(date +%Y-%m) Commit-Log.md"
grep -q 'type: career-log' "$NOTE" \
  && grep -q '\*\*Kompetenz\*\*' "$NOTE" \
  && grep -q 'Rohdaten (nicht editieren)' "$NOTE" \
  && echo NOTE_SCHEMA_OK
```
Expected: `NOTE_SCHEMA_OK`

- [ ] **Step 5: Commit (falls Verifikation Fixes am Skill/Collector nötig machte)**

```bash
git add -A
git commit -m "test(cv-tracker): verify capture end-to-end against real repos"
```

---

## Task 10: Synthese-Verifikation (Tier 2)

**Files:** erzeugt `~/Zettelkasten/Merlin Tätigkeiten.md` (Laufzeit).

- [ ] **Step 1: Synthesize-Modus on-demand auslösen**

Im Chat / via `opencode run`:
```bash
opencode run --agent build \
  "Aktiviere den Skill merlin-cv-tracker im synthesize-Modus. Lies alle _career-log/*.md \
   und aktualisiere 'Merlin Tätigkeiten.md' im CV-Stil von Berufliche Projekte.md."
```

- [ ] **Step 2: CV-Stil-Konformität prüfen**

Run:
```bash
NOTE="$HOME/Zettelkasten/Merlin Tätigkeiten.md"
test -f "$NOTE" \
  && grep -q '^## ' "$NOTE" \
  && grep -q 'Ergebnis:' "$NOTE" \
  && grep -q 'Quelle:' "$NOTE" \
  && echo SYNTH_OK
```
Expected: `SYNTH_OK` — mindestens ein Cluster mit Rolle, `Ergebnis:` und Quell-Verweis.

- [ ] **Step 3: Finaler Commit der Artefakte**

```bash
git add -A
git commit -m "feat(cv-tracker): complete two-tier CV tracking skill"
```

---

## Self-Review-Ergebnis (gegen Spec)

- **Spec §1 Skill/Frontmatter** → Task 4 (Frontmatter-Check), Erfolgskriterium grün.
- **Spec §2 Hash-Watermark/State/Bootstrap** → Tasks 2, 9 (Idempotenz real verifiziert).
- **Spec §2 Merge-Filter/PR-Kontext** → Task 3.
- **Spec §2 Rohdaten-Vollständigkeit (repo, hash, date, subject, stat)** → Tasks 1, 3.
- **Spec §3 Notizformat/Schema-Vertrag** → Task 4 + Task 9 Step 4 (Schema-Check).
- **Spec §4 Tier-2-Lesevertrag/CV-Stil** → Tasks 5, 10.
- **Spec §5 launchd (Wrapper/Plist/Env/Logs/Testpfad)** → Tasks 6, 7, 8.
- **YAGNI** (keine DB, kein Auto-CV-Edit, kein Tier-2-Cron) → eingehalten; Tier 2 bleibt manuell.

Offene Annahmen: Modell/Agent im Wrapper (`anthropic/claude-opus-4-8` / `build`) sind
überschreibbar gesetzt; bei Permission-Wänden im headless-Lauf bricht der Wrapper sauber
ab (Exit ≠0 → `.err.log`), wie in der Spec gefordert.
```
