# Lexio — Milestone Roadmap

Last updated: 2026-08-16

## Vision

Players enter a shared Lexio hall, choose a table manually or enter automatic matchmaking, and play isolated three-player rounds with the people assigned to that table.

## Release criteria

- Multiple tables can host independent games in the same `map01` instance.
- Manual and automatic matching never mix players or leak state between tables.
- Leaving a chair, queue, map, or completed game cleans up ownership reliably.
- Three real clients can complete a match without cross-table UI or turn-state contamination.

## Milestones

| Milestone | Theme | Status |
|---|---|---|
| M1 | Three physical tables, manual seating, automatic queue, isolated table sessions | 🔨 active (Phase 0/4 done) |
| M2 | Capacity expansion, reconnect recovery, spectator/table browsing polish | ⬜ planned |

## Backlog

- Dynamic table creation beyond the initial three physical tables
- Party-based automatic matchmaking
- Skill/rating-based matchmaking
- Spectator mode and table browser
- Cross-room/world matchmaking

