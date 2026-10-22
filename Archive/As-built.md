# Lexio — As-built

> AI handoff record. Current implementation facts only; planning truth lives in `Docs/`.

## Current-state map

| Area | Current implementation |
|---|---|
| Maps | `TileMapTemplate` lobby, `map01` play room, `lexio_session_tests` integration-test map |
| Movement | `map01` is RectTile with `KinematicbodyComponent`; map01-only InputSpeed 1.2 |
| Travel | Lobby entrance and map01 return portal use server-validated UpArrow travel; an unseated player can return to the lobby |
| Seating | Three physical tables with three chairs each; X toggles sit/stand near a table-specific chair |
| Start rule | Three players seated at the same table for 3 seconds start that table's game; split-table occupancy does not start a match |
| Game session | `LexioSessionCoordinator` manages independent table-scoped runtime/session state for `table01`–`table03` |
| Rules | Three-player Lexio deck, play classification/comparison, turns, pass, finish, replay |
| UI | Hidden until seated; table-scoped status and monster-card rendering; card art, magic circle, faction-colored labels/numbers, external selection check, finish/replay controls |
| Tests | Rule tests and deterministic two-session isolation tests pass; real multi-client table isolation remains pending |

## Standing issues

| Issue | Count | Last seen | Status |
|---|---:|---|---|
| Runtime-attached travel bridge can retain a stale source map | 1 | 2026-08-16 | Entrance now uses independent server validation |
| Real three-client manual match completion | 1 | 2026-09-04 | Passed; nickname turn labels and public-card layout follow-ups fixed |
| Two simultaneous table sessions require six-client isolation testing | 1 | 2026-09-04 | Open |
| Real three-client automatic matchmaking and concurrent-table cleanup | 1 | 2026-10-20 | User-test pending; no multi-client environment available |

## Log

### Brownfield seed — 2026-08-16

- Existing playable prototype supports a single three-seat table and one map-wide match.
- The next milestone will replace map-wide ownership with table-scoped lobbies and sessions.
- Existing card rules, card UI, chair interaction, finish flow, and tests should be reused.

### M1 Phase 1–2 implementation snapshot — 2026-09-04

- Three table clusters and nine table-specific chairs are present in map01.
- Seat ownership, countdowns, requests, snapshots, and game sessions are routed by table ID.
- The map01 return portal accepts UpArrow from an unseated player and returns them to the lobby.
- Card presentation was aligned with the preview layout: centered monster/magic circle, faction-colored text and numbers, and a selection check above the card.
- Maker runtime checks completed: rule tests 50/50 and game-session tests 63/63 passed, including deterministic two-session isolation; the real three-client match passed and concurrent-table verification remains open.

