---
description: Tims Under-Review-Tickets aus der Notion-DB holen, gruppiert nach Municipality und User-Email
model: anthropic/claude-haiku-4-5
variant: max
agent: build
---

## Datenquellen

Zwei Notion-Datenbanken mit gefilterten Ansichten (Status = "Under Review", Assigned to = Tim):

- DB 1: `2fc6f202-9270-80f5-8023-d36db60eb157`
- DB 2: `2ee6f202-9270-8090-8ea6-cc9fb1979ede`

## Problem

`notion_notion-search` ist eine semantische Volltext-Suche, **keine** Datenbank-Query. Es gibt keinen Filter für Property-Werte wie Status oder Assigned to. Daher reicht ein einzelner Suchbegriff nicht — Tickets können übersehen werden, wenn ihr Titel/Inhalt semantisch nicht zum Suchbegriff passt.

## Strategie

1. Versuche zuerst `notion_notion-query-database` auf beiden Datenbank-IDs mit Filter `Status = "Under Review"` und `Assigned to enthält User-ID 356d872b-594c-81fe-a3a9-00021ed61f31`.
2. Falls `notion_notion-query-database` nicht verfügbar: Führe **mehrere breite Suchdurchläufe** mit verschiedenen generischen Begriffen durch (z.B. "Ticket", "Issue", "Municipality Status", "Under Review", "Öffnungszeiten").
3. Sammle alle gefundenen Page-IDs aus allen Durchläufen (Deduplizieren).
4. Rufe jede einzelne Seite per `notion_notion-fetch` ab, um die Properties `Assigned to`, `Status`, `Municipality`, `User-Email`, `Description` zu prüfen.

## Ausgabe

Lade den **html-artifacts** Skill und folge ihm für die Ausgabe. Erstelle eine selbst-enthaltene HTML-Datei.

Gruppiere die Ergebnisse nach Municipality (erste Ebene) und User-Email (zweite Ebene).

Gib für jedes Ticket einen Eintrag mit Link zur Seite und einer kurzen Zusammenfassung aus der Description aus.

**Inhalt pro Ticket:**

- Titel als verlinkter Link zur Notion-Seite
- Kurze 1-2 Satz-Zusammenfassung des Problems aus der Description
