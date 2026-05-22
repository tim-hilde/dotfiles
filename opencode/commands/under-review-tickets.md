---
description: Tims Under-Review-Tickets aus der Notion-DB holen, gruppiert nach Municipality und User-Email
model: opencode/big-pickle
---

Rufe die Notion-Datenbank unter https://www.notion.so/2ee6f202927080908ea6cc9fb1979ede?v=2ee6f202927080fba542000cbfc4d1af auf.

Suche alle Tickets, die:
- an Tim Hildebrandt (User-ID `356d872b-594c-81fe-a3a9-00021ed61f31`) zugeordnet sind
- den Status "Under Review" haben

Gruppiere die Ergebnisse nach Municipality (erste Ebene) und User-Email (zweite Ebene).

Gib für jedes Ticket einen Bullet-Point mit Link zur Seite und einer kurzen Zusammenfassung aus der Description aus.

**Ausgabeformat:**
```
### {Municipality} → {User-Email}

- [{Issue-Titel}]({page-url}) — Kurze 1-2 Satz-Zusammenfassung des Problems
```
