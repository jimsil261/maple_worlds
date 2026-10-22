# Lexio M1 — Multi-table Match Hall GDD

> 🔖 **AI note — resuming?** If you're reading this in a new session to continue/resume this game, load the `msw-planning` skill FIRST and follow its resume flow (read `Lexio-Roadmap.md` + `Archive/As-built.md` → reconstruct state → reconcile) — don't edit or implement straight from this doc. **Before touching any `⬜/🟡/✅` state or running a completion, read the skill's `references/build-management.md` in full.**

Stage: Active — awaiting user tests for real automatic matchmaking and concurrent-table isolation

## 1. One-line concept

A shared RectTile Lexio hall with 3/4/5-player physical tables where players either sit together for a manual match or join a three-player automatic queue that assigns table01 and starts an isolated game.

## 2. Player experience and core loop

1. Enter `map01`; no matchmaking starts by default.
2. Choose one of two paths:
   - Manual: walk to a table and sit in one of its chairs.
   - Automatic: press the automatic-match button to join the server queue.
3. Manual players wait only for the other seats at the same table.
4. Automatic players remain unseated while queued; when three are available, the server reserves the empty three-seat table01 and seats them there.
5. When one table has three valid seated players, a three-second countdown begins.
6. If any player stands/leaves before completion, that table's countdown cancels.
7. The table runs an isolated Lexio round, shows only that table's state, then releases its seats.

## 3. Target and platform

| Item | Decision |
|---|---|
| Players | Manual tables support 3/4/5 players; M1 automatic matching groups three players |
| Platform | PC first; mobile-compatible UI bindings retained |
| Map | `map01`, `TileMapMode=1` RectTile |
| Player body | `KinematicbodyComponent` |
| Input | Movement + X sit/stand + UI automatic-match/cancel button |
| Build effort | Medium–High brownfield extension |

## 4. Key decisions and rules

| Topic | Contract |
|---|---|
| Table count | M1 ships with exactly three physical tables |
| Seats | table01/table02/table03 own 3/4/5 distinct chair entities respectively |
| Default state | Entering map01 never enrolls a player in any match or queue |
| Manual match | Sitting reserves that chair and associates the player with that table only |
| Automatic queue | Explicit opt-in; queued users cannot simultaneously own a manual seat |
| Auto assignment | First three valid queued users receive the empty three-seat table01; additional capacity modes are M2 scope |
| Empty-table definition | No seated users, no countdown, no active/finishing session, no reservation |
| Start | Three valid seated players at one table continuously for three seconds |
| Cancellation | Stand, disconnect, map leave, queue cancel, or invalid assignment clears affected state |
| Authority | Queue, reservations, seats, countdowns, and sessions are ServerOnly authoritative |
| Isolation | Every request includes/resolves a table ID; clients render only their assigned table snapshot |
| Existing rules | Card rules and one-round game behavior remain unchanged |

## 5. Systems and MSW mapping

| System | MSW implementation direction |
|---|---|
| Table registry | Map-scoped coordinator component on `map01`; table records keyed `table01`–`table03` |
| Physical layout | Three table entities and twelve chair entities placed with MapBuilder in world units |
| Seat ownership | Server tables: `userIdBySeat`, `seatByUserId`, `tableByUserId`, `chairBySeat` |
| Manual seating | Existing X interaction sends a validated table/chair seat request |
| Auto queue | Server FIFO queue with idempotent join/cancel and stale-user pruning |
| Auto placement | Server reserves an empty table, validates all three users, teleports each to its chair, then confirms seating |
| Sessions | One session component/entity per table or equivalent table-keyed isolated session state |
| Client bridge | Authenticated player bridge carries assigned table ID and table-scoped snapshots |
| UI | `LexioPlayHUD.ui` gains manual-wait status, auto-match/cancel button, queue status, and assigned-table status |
| Cleanup | Map leave, disconnect, stand, finish, replay/exit paths release queue/table ownership |

## 6. Implementation roadmap

### Phase 1 — Table domain and physical layout (3/4 ✅)

- ✅ Define authoritative table/seat state model and table lifecycle.
- ✅ Add three table entities and twelve table-specific chair entities to `map01`.
- ✅ Convert chair interaction from global chair names to table ID + seat index.
- 🟡 Preserve default no-match behavior and verify independent manual seat ownership. (Automated/single-client checks passed; multi-client split-table verification pending.)

### Phase 2 — Manual table matches (3/4 ✅)

- ✅ Replace the single map-wide coordinator/session with table-scoped coordination.
- ✅ Start/cancel the three-second countdown independently per table.
- ✅ Route submit/pass/finish/replay requests and snapshots by assigned table.
- 🟡 Verify two simultaneous table sessions cannot affect each other. (Deterministic two-session tests passed; real six-client verification pending.)

### Phase 3 — Automatic matchmaking (5/5 ✅)

- ✅ Add authenticated FIFO queue join/cancel requests.
- ✅ Add automatic-match/cancel UI and queue feedback.
- ✅ Reserve the empty three-seat table01 when three valid users are queued.
- ✅ Move and seat the matched trio at table01, then use the normal countdown/start path.
- ✅ Handle queue churn, map leave, disconnect, and reservation rollback. (Atomic preflight, ordered rollback, stale-user pruning, idempotent join, cancel, manual-seat cleanup, and user-leave cleanup implemented and server-probed.)

Score presentation added with the official signed 64-point ledger, pairwise zero-sum settlement, 2-tile multipliers, and Maple meso visuals: bronze=1, silver=5, gold=10. Negative totals render as `메소 빚`.

Spectator presentation now binds only to table-scoped public snapshots. Spectators receive an empty version envelope instead of private tiles, can switch among table01–table03, and see turn, remaining counts, public plays, and results without hand/action controls. The Lexio HUD is skinned consistently with the official `cardgame` palette while preserving the custom Maple monster cards.

The board-game cafe lobby now includes a stationary Neinheart guide NPC. Nearby players use Space or click the NPC to open the project-native Maple-style dialog UI and read six pages covering the goal, combinations, opening rule, passing, Lexio-only 1/5/10 chips, automatic matching, and spectating. The portrait, name plate, and text areas are laid out independently so the upper-body portrait can overlap the dialog frame without covering the copy.

### Phase 4 — Multiplayer verification and polish (2/4 ✅)

- ✅ Add deterministic tests for table isolation, queue grouping, rollback, cleanup, replay chip reset, and spectator hand privacy. (`LexioGameSessionTests`: 104 passed, 0 failed; queue hardening probe passed.)
- ✅ Verify three-client manual matching and one full game.
- ⬜ Verify three-client automatic matching and one full game.
- ⬜ Verify concurrent games plus finish/exit/requeue cleanup.

## 7. Data and state contracts

### Table state

`Idle → WaitingManual/ReservedAuto → Countdown → Playing → Finished → Idle`

- `tableId`: stable string (`table01`–`table03`)
- `seatUserIds`: three server-owned user IDs
- `seatEntities`: validated player entity references
- `chairNames`: three configured chair entity names
- `mode`: `None`, `Manual`, or `Auto`
- `countdown`: remaining seconds and generation token
- `session`: isolated Lexio game state for that table

### Player matchmaking state

Exactly one state at a time:

`Free | ManualSeated(tableId, seat) | AutoQueued(queueToken) | AutoReserved(tableId, seat) | Playing(tableId)`

### Queue guarantees

- Duplicate join is idempotent.
- Cancel invalidates the user's current queue token.
- Assignment consumes exactly three still-valid queue entries.
- Reservation rollback returns valid users to the front in original order or frees them according to the Phase 3 detailed contract.

## 8. Verification and acceptance

- Entering map01 alone never starts a countdown or queue.
- Three users at table01 do not populate or start table02/table03.
- Standing during countdown cancels only that table.
- Auto-match ignores manually seated users and groups only explicit queue members.
- A matched trio is placed at one empty table with distinct seats.
- No empty table means queued users remain queued with visible status.
- Finish/exit/map leave leaves no stale seat, reservation, queue, or UI state.
- Real three-client manual and automatic flows remain user-test requirements before M1 completion.

## 9. Plan changes

| Date | Type | Change | Reason | Impact |
|---|---|---|---|---|
| 2026-08-16 | Brownfield milestone | Added three-table manual and automatic matching M1 | Extend the existing single-table prototype | Replaces map-wide match ownership with table-scoped authority across four Phases |
| 2026-10-20 | Onboarding polish | Added Neinheart Lexio guide NPC to the board-game cafe lobby | Teach rules in-world without leaving the MapleStory presentation | Official dialog package, Space interaction, portrait-safe six-page guide |
