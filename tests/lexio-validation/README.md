# 독립 회귀 검사

실제 mLua 메서드 본문을 Fengari로 실행합니다. 엔진·RPC·렌더링 검증과 구분합니다.

```sh
npm ci --prefix tests/lexio-validation
node tests/lexio-validation/run.cjs
```

2026-11-21: 규칙 50 + 세션 108 + 추가 시나리오 3467 = 3625개 단언 통과. UI 버튼 수와 효과음 최대 음량 변경에 맞춰 기대값 갱신.
