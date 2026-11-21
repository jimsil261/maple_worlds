# 메이플 렉시오

![메이플 렉시오](Docs/assets/lexio-beta-thumbnail.png)

MapleStory Worlds에서 제작한 PC용 3·4·5인 멀티플레이 카드 보드게임입니다. **2026년 11월 21일 공개 베타 출시**와 출시 클라이언트의 소리 설정 수정까지 반영했습니다.

방 만들기·빠른 매칭부터 카드 제출, 점수 정산, 재경기, 연결 이탈과 AI 대행까지 하나의 흐름으로 구현했습니다. 이전 이동형 카페 시제품을 정적 UI 중심 게임으로 개편한 개인 프로젝트입니다.

## 플레이

메이플스토리 월드에서 **메이플 렉시오**를 검색합니다. PC 클라이언트 기준으로 확인했으며, 웹브라우저 지원은 출시 설정에 활성화했지만 실제 웹 실행 검증은 남아 있습니다. 비로그인 플레이는 비활성화했습니다.

게임 시작 → 공개방 목록 → 방 생성·입장 또는 빠른 매칭 → 준비·3·2·1 → 게임 → 점수 정산 → 전원 동의 시 재경기 / 로비 복귀

- 3·4·5인 모두 12장: 전체 덱 36 / 48 / 60장
- 같은 인원수의 방도 여러 개 생성, 방별 세션과 채팅 분리
- 방장 표시, 대기 중 인원·비밀번호 변경, 빈 방 정리
- 기존 공개 대기방의 빈자리를 먼저 채우는 자동 매칭
- 턴당 15초, 서버가 유효한 제출·패스와 시간 만료 처리
- 방 채팅, Enter 전송, 아바타 말풍선, 비속어 필터
- 카드 6열 2행, 숫자·진영 정렬, MY TURN / PASS, 족보 안내
- 배경음악·효과음 개별 음량 설정 및 카운트다운·턴 효과음

## 연결 이탈과 재경기

이탈 시 게임 타이머를 멈추고, 남은 사람에게 30초 AI 대행 투표를 표시합니다. **찬성이 남은 사람의 절반을 초과**해야 하며 미투표는 반대입니다. 1명만 남아도 찬성하면 AI와 계속할 수 있습니다. 부결되면 방을 종료합니다.

이탈자는 재접속 화면을 유지하며 AI 대행 후에도 같은 좌석으로 돌아올 수 있습니다. 스스로 로비로 이동하면 해당 경기 복귀를 포기합니다. 복귀는 같은 서버 인스턴스의 기존 좌석을 기준으로 하며, 다른 서버로의 세션 복구는 보장하지 않습니다.

종료 시점에 AI가 남아 있으면 점수를 정산한 뒤 방을 닫습니다. AI 대행을 받았더라도 사람이 종료 전에 복귀했다면 **전원 만장일치**로 재경기할 수 있습니다. 새 방은 64점, 같은 방의 재경기는 직전 점수를 이월합니다. 1·5·10점을 동·은·금 메소로 표시하며 영구 보상·코디 상점은 현재 출시 범위가 아닙니다.

## 구현 구조

| 책임 | 소스 |
|---|---|
| 조합 판정·비교·점수 규칙 | [LexioRules](RootDesk/MyDesk/LexioRules.mlua) |
| 한 판의 손패·턴·트릭·정산 | [LexioGameSession](RootDesk/MyDesk/LexioGameSession.mlua) |
| 방·좌석·대기열·동적 호스트 | [LexioTableRegistry](RootDesk/MyDesk/LexioTableRegistry.mlua) |
| 카운트다운·타이머·AI·투표·재경기 | [LexioSessionCoordinator](RootDesk/MyDesk/LexioSessionCoordinator.mlua) |
| 요청 검증·공개/개인 스냅샷 | [LexioPlayerBridge](RootDesk/MyDesk/LexioPlayerBridge.mlua) |
| 방 설정·채팅·재접속 요청 | [LexioManualTestControls](RootDesk/MyDesk/LexioManualTestControls.mlua) |
| 게임 화면·사운드 | [LexioPlayUIController](RootDesk/MyDesk/LexioPlayUIController.mlua) |

클라이언트는 행동을 요청하고 서버가 사용자·좌석 소유권, 요청 ID, 상태 버전과 규칙을 확인합니다. 개인 손패는 공개 상태와 분리해 전달합니다. 자세한 설명은 [기술 포트폴리오](Docs/Portfolio.md)를 참고하세요.

## 검증과 한계

- 2026-11-21 독립 Lua 회귀 검사 **3,625개 단언 통과**: 규칙 50 + 세션 108 + 추가 시나리오 3,467. 서로 다른 기능 3,625개를 의미하지 않습니다.
- Maker에서 3·4·5인 각각 두 판씩 타이머·점수 이월 검증, 동적 방 격리 프로브 수행.
- 최신 수정 후 Maker 빌드 오류·경고 0, 테스트 시작·종료 실행 오류 0 확인.
- 공개 출시 후 실제 클라이언트에서 소리 설정의 클릭·팝업 표시를 확인. 음량 최대값 수정은 Maker 재생 인자 검사까지 수행했습니다.
- **독립된 여러 실계정의 동시 게임과 실제 웹브라우저 플레이는 아직 최종 검증하지 않았습니다.** 가상 플레이어나 서버 프로브가 이를 대체하지 않습니다.

재현 방법과 검사 경계: [검증 기록](Docs/Verification.md).

## 개발 환경과 실행

MapleStory Worlds Maker · mLua · MSW UI/리소스 API. 프로젝트를 Maker에서 열고 Workspace Refresh 후 Play Test를 실행합니다. 공식·업로드 리소스를 불러오려면 해당 월드와 리소스 접근 권한이 필요할 수 있습니다. 일반 Lua 실행만으로 전체 게임을 구동할 수 없습니다.

오프라인 회귀 검사:

```sh
npm ci --prefix tests/lexio-validation
node tests/lexio-validation/run.cjs
```

## 문서

- [현재 출시 상태](Docs/Current-Status.md) · [검증 기록](Docs/Verification.md)
- [기술 포트폴리오](Docs/Portfolio.md) · [후속 로드맵](Docs/Lexio-Roadmap.md)
- [공개 베타 기록](Docs/Lexio-Beta-Release.md) · [규칙](Docs/rules/LexioOriginalBlackRules.md)
- [제출용 PDF](output/pdf/김재렬_메이플렉시오_포트폴리오.pdf)

## 제작 및 리소스

개인 프로젝트이며 AI 코딩 도구를 기획 정리, 코드 작성·수정, 테스트 프로브, 문서화와 일부 이미지 제작에 활용했습니다. 게임 방향, UI 피드백, 실제 플레이 확인과 출시 결정은 제작자가 담당했습니다. AI 생성 결과도 실제 환경 검증이 필요하며, 출시 후 발견한 UI·음량 문제를 수정한 경험을 문서에 포함했습니다.

메이플스토리 및 MapleStory Worlds의 공식 캐릭터·음원·리소스 권리는 각 권리자에게 있습니다. 저장소 공개는 해당 리소스의 별도 재배포·외부 사용 허가를 의미하지 않습니다. 현재 별도 오픈소스 라이선스를 부여하지 않았습니다.
