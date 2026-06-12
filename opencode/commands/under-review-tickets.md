---
description: Tims Under-Review-Tickets aus der Notion-DB holen, gruppiert nach Municipality und User-Email
model: anthropic/claude-sonnet-4-6
variant: max
agent: build
---

## Datenquellen

- DB 1: `2fc6f202-9270-80f5-8023-d36db60eb157`
- DB 2: `2ee6f202-9270-8090-8ea6-cc9fb1979ede`

## Strategie

1. Hole alle Seiten aus DB 1 via `notion_notion-query-database` — kein Filter.
2. Hole alle Seiten aus DB 2 via `notion_notion-query-database` — kein Filter.
3. Rufe jede Seite per `notion_notion-fetch` ab, um die Properties `Municipality`, `User-Email`, `Name`, `Description`, `Email Template` zu laden.

## Ausgabe

Lade den **html-artifacts** Skill und folge ihm für die Ausgabe. Erstelle eine selbst-enthaltene HTML-Datei.

Gruppiere die Ergebnisse nach Municipality (erste Ebene) und User-Email (zweite Ebene).

**Pro Gruppe (Municipality + User-Email):**

Zeige zuerst die Ticket-Liste:
- Titel als verlinkter Link zur Notion-Seite
- Kurze 1-2 Satz-Zusammenfassung des Problems aus der Description

Darunter eine **zusammengeführte E-Mail-Vorlage** für alle Tickets dieser Person:
- Anrede mit dem Namen der Person (aus der `Name`-Property)
- Inhalt: alle `Email Template`-Felder der Tickets dieser Gruppe zusammengeführt zu einer einzigen E-Mail
- Als kopierbarer Textblock (z.B. `<textarea>` oder `<pre>` mit Copy-Button)
