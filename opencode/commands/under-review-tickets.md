---
description: Under-Review-Tickets aus dem Notion-ZIP-Export verarbeiten und als HTML mit E-Mail-Vorlagen ausgeben
model: anthropic/claude-sonnet-4-6
variant: max
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
- **Notion-URL**: aus der Page-ID im Dateinamen (`<hex32>.html` → `https://app.notion.com/p/<hex32>`)

Extrahiere aus der CSV (gefilterte Under-Review-Ansicht):
- `Issue` (Titel), `Municipality`, `User-Email`, `Description`, `Variant`, `Status`

Verknüpfe CSV-Zeilen mit HTML-Dateien über den Issue-Titel (aus dem `--- Zur Erinnerung`-Block in der E-Mail-Vorlage).

## Schritt 3: E-Mail-Vorlagen zusammenführen

**Einzelnes Ticket** (1 Ticket pro Person+Gemeinde): originale Vorlage aus der HTML unverändert übernehmen.

**Mehrere Tickets** (gleiche Person+Gemeinde): zusammengeführte Vorlage nach diesem Format:

```
EMAIL: <user-email>
BETREFF: Ihre Tickets zu Merlin Schreibt
(Bitte oben stehende Zeilen vor dem Versenden entfernen)

Hallo Herr/Frau XXXX,

vielen Dank für Ihre gemeldeten Tickets. Gerne möchten wir Ihnen hierzu gesammelt eine Rückmeldung geben.

[ANTWORT HIER EINFÜGEN]

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
- Zusammengeführte E-Mail-Vorlage als kopierbare `<textarea>` mit Kopieren-Button

Zusammenfassungsleiste oben: Anzahl Tickets, Gemeinden, Nutzer.
Inhaltsverzeichnis mit Sprunglinks zu jeder Gemeinde.
