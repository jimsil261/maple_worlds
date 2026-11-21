> **과거 시제품 기록입니다.** 현재 공개 베타의 기준은 [README](../README.md), [현재 상태](../Docs/Current-Status.md), [검증 기록](../Docs/Verification.md)입니다.

# Lexio — As-built

> AI handoff record. Current implementation facts only; planning truth lives in `Docs/`.

## Current-state map — 2026-11-20

현재 제품은 PC 정적 UI 렉시오다. 최신 근거와 검증 한계는 Docs/Current-Status.md, 출시 전 실행 항목은 Docs/Lexio-Beta-Release.md를 따른다. 아래 과거 물리 테이블·이동 관련 기록은 설계 이력이며 현재 화면 흐름의 계약이 아니다.

- 메인 → 공개방 목록 → 대기 → 게임 → 결과·재경기·로비 복귀.
- 각 인원 12장, 36/48/60장 덱. 64점 시작 및 재경기 점수 이월.
- 서버 권한 방 상태·요청 검증, 개인 패 분리, 15초 자동 행동.
- 11월 20일: 게임 중 방 입장 차단, 대기열 재시도, 이탈 좌석 회수, 입장 팝업 보강.
- 사용자 확인: 3인 완주·재경기 점수·초록색 동의 표시.
- 독립 검사: 50+108+112개 통과. LSP 8개 오류 0. Maker 빌드 오류 0과 단일 사용자 방 흐름 확인.
- 미구현: 30초 복구·AI 전환·사설방 추방 투표. 실제 다중 클라이언트 검증 대기.

## Historical state map

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

