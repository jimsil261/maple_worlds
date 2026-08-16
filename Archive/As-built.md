# Lexio — As-built

> AI handoff record. Current implementation facts only; planning truth lives in `Docs/`.

## Current-state map

| Area | Current implementation |
|---|---|
| Maps | `TileMapTemplate` lobby, `map01` play room, `lexio_session_tests` integration-test map |
| Movement | `map01` is RectTile with `KinematicbodyComponent`; map01-only InputSpeed 1.2 |
| Travel | Lobby entrance uses server-validated UpArrow travel; map01 has a lobby return path |
| Seating | One physical table represented by three chairs; X toggles sit/stand near a chair |
| Start rule | Three registered players seated on distinct chairs for 3 seconds starts one game |
| Game session | One map-wide `LexioGameSession` coordinated by one `LexioSessionCoordinator` |
| Rules | Three-player Lexio deck, play classification/comparison, turns, pass, finish, replay |
| UI | Hidden until seated; monster-card hand/public-play rendering; finish/replay controls |
| Tests | Rule and session tests plus Maker runtime checks exist |

## Standing issues

| Issue | Count | Last seen | Status |
|---|---:|---|---|
| Runtime-attached travel bridge can retain a stale source map | 1 | 2026-08-16 | Entrance now uses independent server validation |
| Real three-client multiplayer behavior needs human testing | 1 | 2026-08-16 | Open |

## Log

### Brownfield seed — 2026-08-16

- Existing playable prototype supports a single three-seat table and one map-wide match.
- The next milestone will replace map-wide ownership with table-scoped lobbies and sessions.
- Existing card rules, card UI, chair interaction, finish flow, and tests should be reused.

