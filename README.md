# 기묘한 유령 저택 (GhostManor)

세로 화면 포인트앤클릭 방탈출. 코믹+으스스한 유령 저택, 챕터 1.

## 빌드 (한글 사용자명 머신 — 반드시 래퍼 사용)

- 모든 flutter 명령: `.\tool\f.cmd <args>` (ASCII 경로 환경변수 자동 설정)
- 테스트: `.\tool\f.cmd test` — 래퍼 없이 직접 실행하면 TEMP 한글 경로로 flutter_tester가 0xC0000409로 죽는다
- APK: `.\tool\f.cmd build apk --release`
- `C:\workAndroid\gradle-user-ascii`는 한글 홈 정션 — 사용 금지 (진짜는 gradle-home-ascii)
- gradle 설정 일부(minSdk 줄, newDsl/builtInKotlin 플래그)는 Flutter 마이그레이터가 빌드 때마다 관리한다 — **커밋된 상태 = 마이그레이터 출력**이라 빌드 후에도 트리가 깨끗해야 정상. effective minSdk는 Flutter 기본값이며 광고 SDK 요구(23+) 충족은 빌드 성공으로 검증됨

## 구조

- `lib/core/` — 엔진 (GameState 플래그 상태머신, 세이브+백업, SceneView, 인벤토리/조합, 3단계 힌트+광고)
- `lib/rooms/roomN_*.dart` — 방 하나 = 파일 하나. 방 추가: 파일 작성 → `rooms.dart` 목록에 추가 → 정답 시퀀스 테스트 필수. 플래그·퍼즐 id는 방 접두어(예: foyer_)로 전역 유일하게 짓는다(세이브가 방 사이에 공유되므로). 핫스팟 목록은 z순서(뒤에 선언한 것이 탭 우선) — 큰 배경·풍미용 rect는 목록 앞쪽에 선언한다.
- `art/` — Codex 생성 의뢰 문서(`room1~6-assets.md`, `style-guide.md`). 이미지 파일을 `assets/`에 넣으면 코드 수정 없이 반영 (없으면 라벨 색 블록)
- 스펙: `docs/superpowers/specs/`, 계획: `docs/superpowers/plans/`

## 남은 일 (v1 출시까지)

- 챕터 1 콘텐츠(방 1~6: 현관·거실·서재·주방·지하실·다락방) 완료 — 통합 테스트로 6방 연속 클리어 검증(테스트 99개 전부 통과)
- 방 2~6 아트/효과음 도착 시 핫스팟 좌표를 실제 그림에 맞게 미세조정
- 출시 단계: 실제 AdMob ID 교체, 서명 키, 스토어 등록, 런처 이름 (문구에 광고·결제 언급 금지)
- iOS 빌드는 아직 미착수
