---
description: Under-Review-Tickets aus dem Notion-ZIP-Export verarbeiten und als HTML mit E-Mail-Vorlagen ausgeben
model: opencode-go/deepseek-v4.1-flash
reasoningEffort: max
agent: build
---

Verarbeite den Notion-ZIP-Export mit den Under-Review-Tickets und erzeuge eine HTML-Übersicht mit kopierbaren E-Mail-Vorlagen.

## Schritt 1: ZIP-Pfad ermitteln

Frage den Nutzer nach dem Pfad zur heruntergeladenen ZIP-Datei (Notion-Export). Der Nutzer lädt den Export über die Notion-Datenbank-Ansicht "tim_under_review" herunter.

Wenn kein Pfad angegeben wird, suche automatisch nach dem neuesten ZIP in `~/Downloads/` der im Namen `ExportBlock` enthält.

## Schritt 2: ZIP auslesen

Lies die ZIP-Datei mit Python aus (doppelt verschachtelt: äußeres ZIP → inneres ZIP → Dateien). Erwarte folgende Struktur:

```
ExportBlock-*.zip
  └── ExportBlock-*-Part-1.zip
        ├── Privat und Geteilt/External Tickets 💬 - _schreibt *.csv   ← Under-Review-Ansicht (gefiltert)
        ├── Privat und Geteilt/External Tickets 💬 - _schreibt (Kopie der gefilterten Ansicht, enthält: Issue, Municipality, User-Email, Description, Status, Variant)
        └── Privat und Geteilt/External Tickets 💬 - _schreibt/
              ├── <Ticket-Titel> <page-id>.html   ← eine Datei pro Ticket
              └── ...
```

Extrahiere aus jeder Ticket-HTML:

- **E-Mail-Vorlage**: aus dem `<code>`-Block der `EMAIL:` enthält
- **Name der einsendenden Person**: aus dem 📋-Callout am Seitenanfang (`data-notion-callout-icon="📋"`), Format `<Name> (<E-Mail>)` – z. B. `Anna Peter (Anna.Peter@velbert.de)` oder `Wagemann, Jan-Erik (j.wagemann@hoexter.de)`
- **Notion-URL**: aus der Page-ID im Dateinamen (`<hex32>.html` → `https://app.notion.com/p/<hex32>`)
- **Seitenkommentare**: aus dem Abschnitt `Seitenkommentare` in der HTML – enthält interne Kommentare von Tim mit Datum und Text

Extrahiere aus der CSV (gefilterte Under-Review-Ansicht):

- `Issue` (Titel), `Municipality`, `User-Email`, `Description`, `Variant`, `Status`

Verknüpfe CSV-Zeilen mit HTML-Dateien über den Issue-Titel (aus dem `--- Zur Erinnerung`-Block in der E-Mail-Vorlage).

## Schritt 3: Antwortvorschlag generieren

Generiere pro Person+Gemeinde einen Antwortvorschlag auf Basis der Ticket-Beschreibungen, der Seitenkommentare und des Kontexts aus dem Chat-Verlauf in der Ticket-HTML. Der Vorschlag soll:

- auf alle Tickets der Person eingehen
- den internen Kommentar (Seitenkommentar) als Hintergrundwissen verwenden, aber nicht wörtlich zitieren
- professionell und knapp formuliert sein (1–3 Sätze pro Ticket)
- auf Deutsch sein

**Persönliche Anrede ermitteln** (pro Person+Gemeinde, aus dem Callout-Namen):

- Name normalisieren: „Nachname, Vorname“ → „Vorname Nachname“.
- Anrede aus dem Vornamen ableiten (deutsche Namenskenntnis): z. B. Anna → Frau, Jan-Erik → Herr. Titel wie „Dr.“ oder „Prof.“ dabei ignorieren.
- Begrüßungszeile: `Hallo Frau <Nachname>,` bzw. `Hallo Herr <Nachname>,` – bei mehrteiligen Nachnamen (z. B. „van der Berg“, „Müller-Lüdenscheidt“) den vollständigen Nachnamen verwenden.
- Ist das Geschlecht nicht sicher ableitbar (z. B. ausländische oder unbekannte Vornamen), geschlechtsneutral formulieren: `Guten Tag <Vorname Nachname>,`.
- Kein Name ermittelbar: `Guten Tag,`.

## Schritt 4: E-Mail-Vorlagen zusammenführen

**Einzelnes Ticket** (1 Ticket pro Person+Gemeinde): originale Vorlage aus der HTML, mit dem Antwortvorschlag anstelle von `[ANTWORT HIER EINFÜGEN]`, ebenfalls mit dem Hinweis `⚠️ ANTWORTVORSCHLAG – bitte vor dem Versenden prüfen und anpassen:` davor. Ersetze außerdem `Hallo Herr/Frau XXXX,` durch die ermittelte Begrüßungszeile (Schritt 3).

**Mehrere Tickets** (gleiche Person+Gemeinde): zusammengeführte Vorlage nach diesem Format (Begrüßungszeile = persönliche Anrede aus Schritt 3):

```
EMAIL: <user-email>
BETREFF: Ihre Tickets zu Merlin Schreibt
(Bitte oben stehende Zeilen vor dem Versenden entfernen)

Hallo <Begrüßung aus Schritt 3>,

vielen Dank für Ihre gemeldeten Tickets. Gerne möchten wir Ihnen hierzu gesammelt eine Rückmeldung geben.

⚠️ ANTWORTVORSCHLAG – bitte vor dem Versenden prüfen und anpassen:
<Antwortvorschlag aus Schritt 3>

Bei weiteren Fragen stehen wir Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen
Ihr Merlin Team

--- Zur Erinnerung, Ihre Tickets ---

--- Ticket 1: "<Titel>" ---
<Beschreibung aus originalem E-Mail-Template>

--- Ticket 2: "<Titel>" ---
<Beschreibung aus originalem E-Mail-Template>
```

## Schritt 4: HTML ausgeben

Lade den **html-artifacts** Skill und folge ihm für die Ausgabe.

Speichere die Datei als `ticket-email-overview.html` im aktuellen Arbeitsverzeichnis (`/Users/tim/code/merlin/`).

Gruppiere nach **Municipality** (erste Ebene) und **User-Email** (zweite Ebene).

Pro Nutzergruppe:

- Ticket-Liste: Titel als Link zur Notion-Seite, kurze Beschreibung, Variant-Badge (Bug/Feature)
- Seitenkommentare je Ticket als hervorgehobener interner Hinweisblock (Autor + Datum + Text), direkt unter der Ticket-Beschreibung – immer anzeigen, sofern vorhanden
- Zusammengeführte E-Mail-Vorlage als kopierbare `<textarea>` mit Kopieren-Button

Zusammenfassungsleiste oben: Anzahl Tickets, Gemeinden, Nutzer.
Inhaltsverzeichnis mit Sprunglinks zu jeder Gemeinde.
