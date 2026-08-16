# Lexio 3인 수동 세션 시험 명세

## 공식 MSW API 근거

- `UserService`의 `UserEnterEvent`와 `UserLeaveEvent`는 서버에서 월드 입장·퇴장을 통지하며 `event.UserId`를 제공한다. 참가 조정기는 이 이벤트를 사용하고 주기적인 Entity 전체 검색을 사용하지 않는다.
- `_UserService:GetUserEntityByUserId(userId)`는 공식 `UserService` API로 해당 실제 Player Entity를 반환한다.
- 실제 Player Entity의 `PlayerComponent.UserId`를 두 번째 신원 근거로 사용한다.
- `Entity:AddComponent(string typename)`와 `Entity:RemoveComponent(string typename)`는 ControlOnly 런타임 API다. `map01` 참가자에게만 `script.LexioPlayerBridge`와 `script.LexioManualTestControls`를 런타임 부착하며 `DefaultPlayer.model`은 수정하지 않는다.
- 공식 문서 *Preparation for Packet Modulation*에 따라 `@ExecSpace("Server")` 호출의 `senderUserId`는 서버가 부여하며 클라이언트가 변조할 수 없다.
- 공식 문서 *Sending Responses to Specific Clients Only*에 따라 `@ExecSpace("Client")` 메서드를 서버에서 호출할 때 마지막 숨은 인자로 대상 UserId를 전달한다. 개인 손패 및 개인 요청 결과 호출은 항상 이 대상 인자를 명시한다.

## 서버 신원 검증

모든 Ready, Submit, Pass 요청은 다음 조건을 모두 만족해야 한다.

1. `senderUserId == boundUserId`
2. `ownerPlayerEntity == Bridge가 부착된 실제 Player Entity`
3. `senderUserId == ownerPlayerEntity.PlayerComponent.UserId`

`boundUserId`, `ownerPlayerEntity`, 세션 참조, 좌석 및 요청 캐시는 `@Sync`가 없는 서버 측 프로퍼티다. 클라이언트의 동일 이름 로컬 값은 서버 권위 값에 영향을 주지 않는다.

## 준비와 시작

- 입장 순서대로 빈 좌석 1, 2, 3을 배정한다.
- Bridge의 Client `OnBeginPlay`가 실행되어 `NotifyClientReady`가 서버에서 인증된 후에만 해당 좌석을 ready로 표시한다.
- 세 좌석 등록과 세 ready가 모두 충족되어야 한다.
- Coordinator가 `startRequested=true`를 먼저 설정한 뒤 `StartGame`을 호출하므로 중복 Ready로 다시 시작할 수 없다.
- 네 번째 사용자 또는 시작 후 입장자는 관전자이며 개인 손패와 Submit/Pass 권한이 없다.

## 요청 중복 보호

- `requestId`는 1~64자의 비어 있지 않은 문자열이어야 한다.
- 사용자별 Bridge는 마지막 요청 한 건만 저장한다.
- 같은 ID가 같은 payload 또는 다른 payload로 재사용되어도 GameSession을 다시 호출하지 않고 기존 결과만 반환한다.
- 거부 요청은 GameSession의 손패, 차례, 패스 및 `stateVersion`을 변경하지 않는다.

## Maker 다중 클라이언트 수동 입력

Play 후 각 클라이언트 실행 컨텍스트에서 다음처럼 호출한다. 이 컴포넌트는 수동 시험 전용이며 최종 UI와 독립적이다.

```lua
local controls = _UserService.LocalPlayer:GetComponent("script.LexioManualTestControls")
controls:PrintState()
```

현재 손패의 첫 타일 제출:

```lua
_UserService.LocalPlayer:GetComponent("script.LexioManualTestControls"):SubmitFirstTile()
```

명시한 타일 ID 제출:

```lua
_UserService.LocalPlayer:GetComponent("script.LexioManualTestControls"):SubmitTileIds({ 1, 5 })
```

패스:

```lua
_UserService.LocalPlayer:GetComponent("script.LexioManualTestControls"):Pass()
```

`SubmitFirstTile`은 합법 조합을 보장하지 않는다. 현재 차례와 공개 제출을 확인하고 `SubmitTileIds`로 필요한 조합을 지정한다.

## Target Client 수동 시험 훅

Maker의 Lua Executor와 MCP가 기본 클라이언트에만 고정될 때 `LexioManualTestControls:DispatchSeatAction(seat, action)`을 서버 실행 공간에서 호출한다.

- 서버는 `LexioSessionCoordinator.userIdBySeat`와 `playerEntityBySeat`로 좌석을 실제 등록 사용자에게 변환한다.
- 외부 UserId 입력은 받지 않는다.
- 허용 동작은 `Ready`, `SubmitFirstTile`, `Pass`뿐이다.
- 대상 Client 메서드는 기존 `LexioPlayerBridge:NotifyClientReady`, `RequestSubmit`, `RequestPass` 경로만 사용한다.
- `SubmitForUser` 또는 `PassForUser`를 직접 호출하지 않으므로 `senderUserId`, `boundUserId`, `ownerPlayerEntity.PlayerComponent.UserId` 검증을 우회하지 않는다.
- 관련 프로퍼티와 메서드에 `@Sync`를 사용하지 않는다.

제거 절차:

1. `LexioManualTestControls.mlua`에서 `IsAllowedTargetAction`, `DispatchSeatAction`, `ExecuteTargetAction` 세 메서드를 제거한다.
2. 이 문서의 `Target Client 수동 시험 훅` 절을 제거한다.
3. 최종 UI 단계에서는 `LexioSessionCoordinator.AttachBridge`의 `script.LexioManualTestControls` 런타임 부착 두 줄도 제거한다.
4. refresh/build 후 `map01`에서 `LexioManualTarget` 로그가 더 이상 발생하지 않는지 확인한다.

## 맵 분리

- `map01`: `LexioGameSession` + `LexioSessionCoordinator` 수동 세션 Host
- `lexio_session_tests`: `LexioGameSession` + `LexioGameSessionTests` 자동 테스트 Runner
- 자동 테스트 컴포넌트는 `map01`에 연결하지 않는다.
# Release cleanup: TargetTravel test hook

- `LexioManualTestControls.DispatchTargetTravel` / `ExecuteTargetTravel` are Maker Play-only virtual-client test hooks.
- They must not be referenced by production UI or gameplay code and use no `@Sync` state.
- Before release, remove the two TargetTravel methods and their test-only properties from `LexioManualTestControls`.
- Also remove the Maker Play-only `LexioManualTestControls` attachment block from `LexioTravelMapController.AttachBridge`.
- Re-run LexioRuleTests, LexioGameSessionTests, LexioTravelTests, then confirm lobby/map01 runtime Error/Warning 0.

## 확인 완료: Scene 편집 화면의 흰 실루엣

- 상태: **런타임 아바타 버그로 재현되지 않음**. 첨부 화면은 Play가 종료되고 Scene 탭이 활성화된 편집 화면이며 실제 Player Entity가 존재하지 않는다.
- 왼쪽 실루엣은 `/maps/TileMapTemplate/SpawnLocation`이다. 좌표는 `(0, 0, 999.999)`이고 `SpawnLocationComponent`와 편집 표시용 `SpriteRendererComponent`를 가진다.
- 오른쪽 실루엣은 `/maps/TileMapTemplate/LexioEntrance`이다. 좌표는 `(2, 0, 0)`이고 `InteractionComponent`, `LexioTravelInteractable`, 임시 `SpriteRendererComponent`를 가진다.
- 두 실루엣의 `SpriteRendererComponent.SpriteRUID`는 모두 `8ef238e0d0ca4bb783aca526cff35d11`이다. 따라서 화면의 두 흰 형상은 Player Avatar가 아니라 Scene 배치용 오브젝트 표시다.
- 이전 보존 로그의 동시 `UserLeaveEvent`는 Maker 전체 stop 시각에 발생했으며 개별 사용자 이탈에 의한 자동 귀환 증거가 아니다.
- `LEXIO_EXIT` 목적지는 별도 개선으로 `TileMapTemplate (-2, 0, 0)`으로 변경하고 왕복 검증했다. Entrance와의 거리는 약 4 world unit이며 자동 재입장은 발생하지 않았다.
- 후속 아바타 버그 재현 TODO는 종료한다. 향후 실제 Play 중 Player Avatar가 흰 실루엣으로 지속되는 별도 증거가 생길 때만 새 이슈로 기록한다.
# 종료 직전 테스트 훅 제거 절차

출시 전 `LexioManualTestControls.mlua`에서 `isolatedFinishTiles`, `preparedFinishVersion`, `GetCurrentTurnSeat`, `PrepareFinishScenario`, `DispatchFinishSubmit`과 `FinishSubmit` action 분기를 제거한다. 운영 UI는 이 훅을 참조하지 않으며, 훅은 `map01` Maker Play에서 서버가 호출할 때만 동작한다. 제거 후 Rules 50/0, GameSession 45/0, Travel 12/0과 3인 정상 플레이를 다시 확인한다.
