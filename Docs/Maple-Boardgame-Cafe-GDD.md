# Maple Boardgame Plaza — Hub and Game Buildings GDD

Stage: Active — Lexio-building shell and elevator travel verified; adaptive matchmaking verification in progress

## 1. One-line concept

Players gather in a MapleStory-style outdoor board-game plaza and enter a dedicated themed building for each game; Lexio is the first playable title.

## 2. Product structure

- The outdoor plaza is the persistent shared hub and must not contain Lexio-specific authority.
- Each board game receives its own building connected to the plaza: Lexio first, with Bang! and Halli Galli as natural future additions.
- Each board game owns its rules, match state, and in-game UI.
- Nickname display, invitations, matchmaking, results, cosmetics, and return-to-plaza behavior are reusable services.
- Physical table and chair props are not used as the primary room-selection interface. Game-room doors represent playable rooms.
- A shared cosmetic shop stands in the plaza so name-tag, chat-balloon, and map-specific cosmetics can be used across games.

## 3. Player experience

1. Enter the outdoor board-game plaza.
2. Choose a game building; Lexio is the first open building.
3. In the Lexio building, use Neinheart's rule guide, automatic matching, or the private-room floor.
4. Travel between floors with a vertically aligned elevator rather than stairs.
5. Enter a game-room door; only then open the waiting or game UI.
6. Finish one round, vote to continue, or return to the Lexio lobby/plaza.

## 3.1 Lexio building zoning

| Area | Role |
|---|---|
| 1F | Entrance lobby, Neinheart rules, automatic matching reception, elevator |
| 2F | Private-room creation, public room list, password/invite-code entry, room doors |
| 3F | Closed future floor for spectating, tournaments, rankings, and special rooms |
| Plaza | Shared cosmetic shop, game-building entrances, announcements and events |

- Automatic matching offers `3 players`, `4 players`, `5 players`, or `Any player count`.
- Match formation prioritizes the longest-waiting eligible player. `Any` entries fill compatible shortages and are removed atomically when assigned.
- Private rooms support a room title, 3/4/5-player capacity, public/private visibility, password, and short invite code.
- A private round starts after the selected capacity is full and every player presses Ready; a three-second countdown is cancelled if anyone unreadies or leaves.
- Spectating is explicitly postponed until the later third-floor milestone.

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

- The plaza uses a Henesys-inspired outdoor village composition with distinct game-building silhouettes.
- The Lexio building uses a warm fantasy-club interior with wooden and brass elevator doors, floor lamps, room plaques, and restrained decorative furniture.
- Doors, reception desks, status lamps, and floor signage carry navigation; low-quality table/chair clusters are removed.
- Official MSW/Maple resources are preferred. No suitable complete café pack was found, so verified individual background and object sprites will be composed.
- Table silhouettes must look like furniture in the world, not UI panels placed on grass.

## 6. UI direction

- Default exploration: only a small café/game-zone HUD.
- Room waiting: room title, capacity, invite code/password state, player slots, and per-player Ready state.
- Playing: a large centered game-board window that leaves a narrow border of the world visible.
- The same game-board UI adapts to 3, 4, or 5 players: the local player remains bottom-center; opponents occupy an upper arc; unused slots are disabled rather than duplicated.
- The center uses a circular turn indicator, last-play cards, combination strength, and submitting player. The top shows a server-authoritative 30-second turn timer with a final-five-second warning.
- Turn, new leader, winner, and results always use player nicknames.
- Common café chrome and game-specific content are separate so future games can reuse the shell.

## 6.1 Round, disconnect, and reward rules

- Each game is one round. After results, all current participants vote `Continue` or `Leave`; only unanimous Continue starts a rematch with a fresh deal and randomized lead/seat order.
- Automatic-match disconnect: allow 30 seconds for reconnection while turns are handled automatically, then permanently convert the seat to AI.
- Private-room disconnect: wait for reconnection; connected players may start a majority kick vote. A successful kick transfers the exact seat, hand, and score to AI.
- A reconnect during a private-room kick vote cancels that vote.
- The signed 1/5/10 bronze/silver/gold meso chips are round score only and are never directly exchangeable for cosmetics.
- Only eligible completed automatic matches award persistent cosmetic points. Private rooms, disconnected/kicked accounts, and AI seats award no persistent currency.

## 7. Reuse and replacement

| Keep | Replace |
|---|---|
| Lexio rules, deck, turns, pass, finish, replay | Current RectTile physical-table presentation |
| Table-scoped server sessions and snapshots | Grass background, placeholder furniture, and chair-driven room selection |
| Authenticated player bridge | RectTile/Kinematic movement assumptions |
| Card monster artwork and faction colors | Development-style navy panels and generic buttons |
| Isolated room/session ownership model | Lexio-only hub naming and tightly coupled presentation |

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
| 2026-10-23 | Hub revision | Replaced the single café-as-hub concept with an outdoor board-game plaza and one building per game | Lexio, Bang!, Halli Galli, and later games need distinct identities and scalable entrances | Moves shared shop to the plaza; moves Neinheart, matching, private rooms, and future spectating into a three-floor Lexio building with elevator travel |
| 2026-10-23 | Match and UI direction | Confirmed 3/4/5/Any automatic matching, hybrid public/private rooms, adaptive 3–5-player board UI, 30-second turns, reconnect/AI rules, and unanimous rematch voting | Replace physical furniture interaction with a reliable room-service flow | Adds future server matchmaking, private-room, AI takeover, anti-farming, and responsive UI requirements |
| 2026-10-24 | Building shell implementation | Replaced visible table/chair clusters in `map01` with three interior floors, elevator stops, service doors, and invisible logical seat anchors; moved Neinheart into the 1F lobby | Establish the new building navigation without discarding the proven session contracts | 🟡 implemented, untested in Maker; automatic-match door reuses the current queue, private room and 3F remain intentionally deferred |
| 2026-11-05 | Navigation and matchmaking verification | Aligned the three-floor background, fixed authoritative one-floor elevator travel, hardened direct-play map detection, and verified exact-size-first 3/4/5/Any queue candidate ordering | Runtime map names and MapleTile physics invalidated direct transform and string-name assumptions | 🟢 elevator travel and match-size menu verified in Maker; full multi-client table assignment remains an acceptance test |
| 2026-11-06 | Private-room vertical slice | Added the 2F private-room browser and waiting room, server room catalog, short invite codes, optional passwords, 3/4/5-player capacity, owner transfer, explicit per-player Ready, and the existing cancellable three-second session countdown | Reuse the proven isolated table sessions while keeping automatic matchmaking behavior unchanged | 🟢 single-client create/ready/leave/cleanup and readiness gating verified in Maker; multi-client join and full countdown remain acceptance checks |
| 2026-11-06 | Plaza shop integration | Split shop authentication from game-session authentication, added an always-present player RPC transport, hid the unimplemented Sell tab, and exposed purchase/equip result messages in the Maple-style shop | The plaza player has no Lexio session bridge before entering a game, which previously caused shop requests to fail silently | 🟢 snapshot and insufficient-points purchase rejection verified in Maker; funded purchase/equip remains an acceptance check |
