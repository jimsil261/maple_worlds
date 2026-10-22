# Maple Boardgame Cafe — Lexio

MapleStory Worlds에서 구현한 **멀티테이블 보드게임 카페 프로젝트**입니다.  
첫 번째 게임으로 카드 게임 렉시오를 구현했으며, 규칙 처리뿐 아니라 테이블별 세션 격리, 자동 매칭, 관전 정보 분리, 메이플풍 카페·상점·NPC 대화 UI까지 하나의 플레이 흐름으로 구성했습니다.

## 프로젝트 한눈에 보기

- 플랫폼: MapleStory Worlds
- 언어: mLua
- 맵 구성: MapleTile 카페 허브 + 테이블 기반 렉시오 게임 공간
- 플레이 인원: 테이블별 3/4/5인 수동 착석, M1 자동 매칭은 3인
- 핵심 목표: 여러 테이블이 동시에 진행되어도 상태와 카드 정보가 섞이지 않는 서버 권한형 보드게임 구조

## 주요 구현

### 렉시오 게임 규칙

- 단일 카드부터 5장 족보까지 조합 판정 및 비교
- 선 플레이어, 패스, 새 트릭 시작, 승리·종료 처리
- 공식 점수 규칙 기반의 부호 있는 64점 원장과 제로섬 정산
- 1점·5점·10점을 메이플의 동·은·금 메소 칩으로 시각화
- 규칙 및 세션 로직을 UI와 분리해 테스트 가능한 구조로 구성

### 멀티테이블 세션

- `table01`~`table03`별 좌석, 카운트다운, 게임 상태 독립 관리
- 서버에서 좌석 소유권과 플레이 요청을 검증
- 수동 착석과 FIFO 자동 매칭 상태가 충돌하지 않도록 상태 전이 관리
- 이탈·취소·맵 이동·게임 종료 시 예약과 좌석을 정리하는 롤백 처리
- 관전자에게 손패를 제외한 공개 스냅샷만 전달

### 메이플 보드게임 카페

- MapleTile 기반 횡스크롤 카페 공간과 메이플풍 소품 배치
- 나인하트 NPC를 클릭하거나 `Space`로 렉시오 규칙 대화 열기
- 패키지 의존성을 제거한 프로젝트 전용 NPC 대화 UI
- 캐릭터 초상, 이름표, 다단계 규칙 설명을 메이플 대화창 구도로 구성
- 카페의 잡화점 NPC/오브젝트에서 `Space` 또는 클릭으로 상점 열기

### 보상 및 꾸미기 상점

- 경기 보상 포인트, 구매·보유·장착 상태를 서버에서 관리
- 명찰/말풍선 계열과 아바타 장식 아이템을 슬롯별로 분류
- 구매 가능 여부와 장착 상태를 반영하는 메이플풍 상점 UI
- 경기 점수용 메소 칩과 영구 보상 포인트를 별도 데이터로 분리

## 조작

| 입력 | 기능 |
|---|---|
| 방향키 | 이동 |
| `Alt` | 점프 |
| `Space` | 가까운 NPC 대화 또는 상점 상호작용 |
| `X` | 렉시오 테이블 수동 착석/해제 |
| `Q` | 자동 매칭 참가/취소 |
| 마우스 | NPC 클릭, 카드 및 UI 조작 |

## 설계 포인트

```text
Player Input / UI
        │
        ▼
LexioPlayerBridge ── 인증된 요청 ──▶ LexioTableRegistry
        │                                  │
        │                                  ├─ 좌석·대기열·예약
        │                                  ├─ 테이블별 상태 전이
        │                                  └─ 정리·롤백
        │
        └─ 테이블 범위 스냅샷 ◀──── LexioGameSession
                                           │
                                           └─ LexioRules
```

- 규칙: `LexioRules.mlua`
- 한 판의 상태: `LexioGameSession.mlua`
- 테이블/매칭 권한: `LexioTableRegistry.mlua`, `LexioSessionCoordinator.mlua`
- 클라이언트 통신 경계: `LexioPlayerBridge.mlua`
- 플레이 UI: `LexioPlayHUD.ui`, `LexioPlayUIController.mlua`
- 카페 NPC/상점: `LexioGuideNpc.mlua`, `LexioNpcDialogUIController.mlua`, `LexioShopNpc.mlua`, `LexioShopUIController.mlua`

## 검증 현황

- 렉시오 규칙 테스트: 50개 통과
- 세션·테이블·매칭 결정론 테스트: 104개 통과 기록
- 단일 Maker 세션에서 카페 이동, NPC 클릭/Space 대화, Alt 점프, 상점 진입 검증
- 수동 3클라이언트 한 판 검증 완료 기록
- 실제 3클라이언트 자동 매칭과 동시 다중 테이블 실기 검증은 후속 확인 항목

## 실행 방법

1. MapleStory Worlds Maker에서 이 로컬 워크스페이스를 엽니다.
2. Workspace를 새로고침합니다.
3. `boardgame_cafe` 또는 시작 맵에서 Play Test를 실행합니다.
4. 카페의 나인하트와 상점을 통해 온보딩 및 꾸미기 흐름을 확인합니다.
5. 렉시오 테이블에서는 수동 착석 또는 자동 매칭으로 게임에 진입합니다.

## 문서

- [게임 설계 문서](Docs/Lexio-M1-GDD.md)
- [개발 로드맵](Docs/Lexio-Roadmap.md)
- [자동 매칭·점수 표현 단계](Docs/Lexio-M1-Phase3.md)
- [보드게임 카페 설계](Docs/Maple-Boardgame-Cafe-GDD.md)
- [렉시오 규칙 정리](Docs/rules/LexioOriginalBlackRules.md)

## 현재 단계

핵심 게임 규칙, 테이블별 세션, 자동 매칭 로직, 카페 허브, NPC 대화, 상점 UI까지 구현된 프로토타입입니다. 다음 단계는 실제 다중 클라이언트 환경에서 자동 매칭과 동시 테이블 격리를 최종 검증하고, 보상 데이터 저장과 카페 아트 구성을 다듬는 것입니다.

