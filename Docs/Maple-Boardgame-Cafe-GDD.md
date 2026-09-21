# Maple Boardgame Cafe — Hub GDD

Stage: Active — café overhaul planning complete; Phase C1 ready

## 1. One-line concept

Players explore a cozy MapleStory-style side-scrolling board-game café, sit at themed tables, and launch self-contained board games; Lexio is the first playable title.

## 2. Product structure

- The café is the persistent shared hub and must not contain Lexio-specific authority.
- Each board game owns its rules, match state, and in-game UI.
- Seating, nickname display, invitations, matchmaking, results, and return-to-hub behavior are reusable café services.
- Lexio launches from the first three physical tables.
- Future board games receive their own themed table zone without rebuilding the hub.

## 3. Player experience

1. Enter the café through a MapleStory-style side-view entrance.
2. Move left/right, jump between footholds, and use ladders or stairs where appropriate.
3. Browse game shelves and game-zone signs.
4. Approach a Lexio chair and press X to sit.
5. When three players are ready, the café HUD stays compact and the Lexio table UI opens.
6. Finish the match, close the game UI, and return to free café movement.

## 4. Platform contract

| Item | Decision |
|---|---|
| Hub map | New map built separately from current `map01` until verified |
| TileMapMode | 0 — MapleTile |
| Player body | `RigidbodyComponent` |
| Terrain | `TileMapComponent` + `FootholdComponent` |
| Movement | Native left/right, jump, down-jump; Maple avatar retained |
| Target | PC 12.8×7.2 world-unit viewport first |
| Interaction | X near a registered chair or café object |
| Camera | Side-view follow with restrained damping and café-wide composition |

## 5. Art direction

- Cozy Henesys-inspired wooden interior, warm amber lighting, cream walls, green accents.
- Readable foreground footholds with shelves, board-game boxes, menu boards, lamps, couches, and a staffed counter.
- Three Lexio tables form one clearly signed zone; future zones remain visually reserved rather than appearing broken.
- Official MSW/Maple resources are preferred. No suitable complete café pack was found, so verified individual background and object sprites will be composed.
- Table silhouettes must look like furniture in the world, not UI panels placed on grass.

## 6. UI direction

- Default exploration: only a small café/game-zone HUD.
- Sitting/waiting: compact table panel with nicknames and readiness.
- Playing: warm wood-and-parchment frame; public play centered above the hand; action buttons along the bottom.
- Turn, new leader, winner, and results always use player nicknames.
- Common café chrome and game-specific content are separate so future games can reuse the shell.

## 7. Reuse and replacement

| Keep | Replace |
|---|---|
| Lexio rules, deck, turns, pass, finish, replay | Current RectTile play-room presentation |
| Table-scoped server sessions and snapshots | Grass background and placeholder furniture layout |
| Authenticated player bridge | RectTile/Kinematic movement assumptions |
| Card monster artwork and faction colors | Development-style navy panels and generic buttons |
| Three-table ownership model | Lexio-only hub naming and tightly coupled presentation |

## 8. Roadmap

### Phase C1 — Café shell and Maple movement

- ⬜ Create the new MapleTile café map from a validated template.
- ⬜ Confirm footholds, spawn point, camera, Rigidbody movement, jump, and return portal.
- ⬜ Compose the first-pass wooden interior using verified official resources.
- ⬜ Verify build and single-client traversal without touching the current playable map.

### Phase C2 — Café zones and interaction

- ⬜ Build the counter, Lexio zone, three redesigned tables, nine chairs, shelves, and future-game spaces.
- ⬜ Generalize table metadata into café game ID + table ID + seat index.
- ⬜ Connect X interaction and seated avatar state on MapleTile.

### Phase C3 — Shared café UI and Lexio skin

- ⬜ Add compact café HUD and reusable table waiting panel.
- ⬜ Redesign the Lexio play HUD with Maple-style wood/parchment presentation.
- ⬜ Preserve responsive PC/mobile card behavior and nickname-based states.

### Phase C4 — Integration and cutover

- ⬜ Run one complete three-client Lexio match in the new café.
- ⬜ Verify table/session isolation and exit cleanup.
- ⬜ Route the lobby entrance to the café and retire the old play-room path only after acceptance.

## 9. Acceptance

- Movement and map traversal feel like MapleStory rather than a top-down test room.
- The café reads immediately as a board-game venue with room for additional games.
- Lexio remains fully playable and does not own the hub architecture.
- Exploration UI does not cover the map; game UI appears only when seated/playing.
- The current playable map remains available until the replacement passes verification.

## 10. Plan changes

| Date | Type | Change | Reason | Impact |
|---|---|---|---|---|
| 2026-09-04 | Product direction | Reframed the venue from a Lexio card tavern to a reusable Maple board-game café | Future board games are planned | Adds shared hub architecture and a safe four-phase visual/physics overhaul before automatic matchmaking |
