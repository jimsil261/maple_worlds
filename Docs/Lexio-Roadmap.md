# Lexio — Milestone Roadmap

Last updated: 2026-10-20

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
| M1 | Three physical tables, manual seating, automatic queue, isolated table sessions | ⏳ user-test pending |
| M2 | Persistent reward points and Maple-style name-tag/chat-balloon cosmetic shop | 🔨 active |
| M3 | Capacity expansion, reconnect recovery, spectator/table browsing polish | ⬜ planned |

## Backlog

- Dynamic table creation beyond the initial three physical tables
- Party-based automatic matchmaking
- Skill/rating-based matchmaking
- Spectator mode and table browser
- Cross-room/world matchmaking

## Current next step

1. Verify the project-native persistent reward balance: every finisher earns 3 points and the winner earns a 10-point bonus.
2. Build the Maple-style shop UI over the completed server catalog and purchase/equip RPCs.
3. Add custom monster-themed `NameTagRUID` and `ChatBalloonRUID` skins after validating their 9-slice sprites.
4. Keep M1 real three-client automatic matching and concurrent split-table verification as environment-blocked acceptance checks.

## M2 direction — Reward points and cosmetic rings

- Currency: persistent reward points earned from completed Lexio matches; separate from the signed 64-point match ledger and its 1/5/10 meso-chip presentation.
- Earning: every player who completes a match earns 3 reward points; the winner receives an additional 10 points (13 total).
- Purchase: server-authoritative point deduction and one-time ownership grant; duplicate purchases are rejected.
- Slots: one equipped name-tag ring and one equipped chat-balloon ring.
- Application: equipped values map to `NameTagComponent.NameTagRUID` and `ChatBalloonComponent.ChatBalloonRUID`.
- Persistence: save reward balance, owned cosmetic IDs, and both equipped IDs; validate saved IDs against the server catalog when loading.
- Presentation: Maple general-store styling in the board-game cafe, with preview-before-purchase and owned/equipped states.
- Catalog classification: `Special` contains name-tag/chat-balloon skins; `Avatar` contains cape, face-accessory, and one-handed-weapon cosmetics. Initial verified avatar stock is Heart Balloon (30), Pink Bean Balloon (60), Ghost Balloon (90), Maple Leaf (45), Heart Mark (70), and Ice Snowflake Ring (120).
- Package decision: the official `resource-package` was evaluated but its current RPC event/struct signatures produce four build errors on this world's CoreVersion. Keep it unconnected and implement a lightweight project-native reward balance after the locally installed package is removed in Maker. Continue avoiding `shop-package` (WorldShop products) and the oversized full `inventory-package`.

Completed onboarding polish: the board-game cafe lobby has a Neinheart guide NPC using Space or mouse click and a project-native Maple-style dialog UI to explain Lexio rules and controls. Jump is mapped to Alt so Space remains dedicated to nearby interactions.

