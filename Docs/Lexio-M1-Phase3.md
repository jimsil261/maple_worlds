# Lexio M1 — Phase 3: Automatic Matchmaking and Meso Score Presentation

> AI note: Keep this checklist synchronized with implementation. Mark work complete only after Maker runtime verification.

## Goal

Add a server-authoritative FIFO automatic queue that assigns three players to the empty 3-seat Lexio table, then reuse the existing seat, ready, countdown, and game-start pipeline. Present the already-defined Lexio score settlement using Maple bronze/silver/gold meso visuals for 1/5/10 points.

## Tasks

- ✅ Task 1 — Queue authority and cancellation
  - Registry-owned FIFO queue; authenticated join/cancel; cleanup on manual seating and user leave.
- ✅ Task 2 — Automatic table assignment
  - Match three valid map01 players to table01 seats and reuse `RegisterTablePlayer`.
  - Client receives authoritative chair assignment and enters the normal ready/countdown flow.
- ✅ Task 3 — Queue interaction and feedback
  - `Q` toggles queue state while unseated; `X` remains manual seating.
  - Add visible queue controls/status to the HUD.
- ✅ Task 4 — Lexio score settlement
  - Verify 64-point zero-sum rules and 2-tile multipliers.
  - Add round score result to the finished snapshot.
- ✅ Task 5 — Maple meso score visuals
  - 1 point: bronze meso; 5 points: silver meso; 10 points: gold meso.
  - Negative score is labelled as meso debt; internal score remains signed integer.
- ✅ Task 6 — Verify
  - One Maker cycle: build logs, queue probes, deterministic score tests, and normal logs with `[VRF]` evidence.
  - If multiple clients are available, verify automatic assignment and split-table isolation.

## Verification record — 2026-10-17

- Maker refresh/build: 0 errors.
- Server probes: queue join/cancel/cleanup all true; score delta sum 0; signed ledger application true.
- Client probe: matchmaking panel and all three meso sprite nodes resolved.
- Visual check: matchmaking HUD appears on map01 while unseated.
- Pending: real three-client automatic assignment/full game and concurrent split-table isolation.
- Queue hardening probe: idempotent duplicate join, single FIFO entry, stale-user pruning, ordered rollback restoration, cancel, and final cleanup all passed.
- Phase disposition: automated verification complete. Real multi-client verification is explicitly deferred because this Maker session exposes only one map user.

