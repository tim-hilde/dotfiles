---
description: Tims Under-Review-Tickets aus der Notion-DB holen, gruppiert nach Municipality und User-Email
model: anthropic/haiku-4-5
agent: build
---

## Problem

`notion_notion-search` ist eine semantische Volltext-Suche, **keine** Datenbank-Query. Es gibt keinen Filter für Property-Werte wie Status oder Assigned to. Daher reicht ein einzelner Suchbegriff nicht — Tickets können übersehen werden, wenn ihr Titel/Inhalt semantisch nicht zum Suchbegriff passt.

## Strategie

1. Führe **mehrere breite Suchdurchläufe** mit verschiedenen generischen Begriffen auf der Datenquelle durch, um möglichst alle Seiten der DB zu erfassen (z.B. "Ticket", "Issue", "Municipality Status", "Under Review", "Öffnungszeiten").
2. Sammle alle gefundenen Page-IDs aus allen Durchläufen (Deduplizieren).
3. Rufe jede einzelne Seite per `notion_notion-fetch` ab, um die Properties `Assigned to`, `Status`, `Municipality`, `User-Email`, `Description` zu prüfen.
4. Filtere auf:
   - Assigned to enthält User-ID `356d872b-594c-81fe-a3a9-00021ed61f31`
   - Status = `"Under Review"`

## Ausgabe

Nutze den html skill.

Gruppiere die Ergebnisse nach Municipality (erste Ebene) und User-Email (zweite Ebene).

Gib für jedes Ticket einen Bullet-Point mit Link zur Seite und einer kurzen Zusammenfassung aus der Description aus.

**Ausgabeformat:**

```
### {Municipality} → {User-Email}

- [{Issue-Titel}]({page-url}) — Kurze 1-2 Satz-Zusammenfassung des Problems
```
