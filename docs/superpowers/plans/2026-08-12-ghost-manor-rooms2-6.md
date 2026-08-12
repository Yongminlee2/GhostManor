# GhostManor 챕터 1 완성 (방 2~6) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v1 슬라이스(코어 엔진 + 현관)에 본편 방 5개(거실·서재·주방·지하실·다락방)와 챕터 엔딩을 얹어 챕터 1을 완성한다.

**Architecture:** 기존 하이브리드 그대로 — 방 하나 = `lib/rooms/roomN_*.dart` 파일 하나가 선언형 `Room`을 리턴, 특수 기믹은 그 파일 안 커스텀 위젯. 코어 엔진은 Task 1의 `RubbableScene` 추출 외에 변경하지 않는다.

**Tech Stack:** 기존과 동일 + `sensors_plus`(Task 5에서 추가 — 스펙 §4.1이 허용한 4번째 패키지).

**스펙:** `docs/superpowers/specs/2026-08-12-ghost-manor-escape-design.md` §3.2(방 역할·기믹 배치) 준수.

**계획 스타일 주의:** v1 계획과 달리 이 계획은 방별 코드를 전문 수록하지 않는다. 대신 **설계 표(씬·핫스팟 좌표·플래그·대사·힌트 전문)가 구속력 있는 요구사항**이고, 구현은 `lib/rooms/room1_foyer.dart`(패턴 원본)를 그대로 따라 전사한다. 표의 모든 값(id·좌표·문자열)은 verbatim이다. 표에 없는 동작을 임의로 추가하지 않는다.

## Global Constraints

- v1 계획의 Global Constraints 전부 유효: `tool\f.cmd` 래퍼 필수(PowerShell로 실행, timeout 600000ms), ASCII 경로 함정, 한글 파일은 Edit/Write 도구만, AdMob 테스트 ID만, 커밋 한국어 + `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`, analyze는 매 태스크 "No issues found!" 필수.
- **v1에서 확립된 방 작성 규칙 (전부 필수):**
  - 플래그·퍼즐 id는 방 접두어로 전역 유일 (`living_`, `study_`, `kitchen_`, `cellar_`, `attic_` / `p_living_*` 등)
  - `closeups`의 map key == `Scene.id` (Room 생성자 assert가 강제)
  - 정답 시퀀스 테스트는 클로즈업을 여는 핫스팟도 직접 탭해서 `room.closeups.containsKey(s.closeupId)`를 확인
  - 핫스팟 폭 ≥ 0.08 (생성자 assert)
  - 다중 밑줄 파라미터 `(_, __)` 금지 → `(_, _)` (unnecessary_underscores)
  - 모든 유저 노출 신규 텍스트는 `lib/core/strings.dart` 상수로
  - Hotspot의 `when`이 없는 탭 게이트는 onTap 안에서 플래그 검사 (room1 패턴)
- **아이템은 전부 필수 획득 경로에 배치** — 특히 음표 카드 4장은 각 방의 필수 진행 보상과 같은 액션에서 함께 지급된다 (놓치고 다음 방으로 갈 수 없게).
- 방 간 이동은 앞으로만 간다(뒤로 못 감). 따라서 방을 넘는 단서는 **아이템**(자동 휴대)으로만 설계돼 있고, 시각 기억 단서는 반드시 같은 방 안에서 소비된다. 새 퍼즐을 변형할 때도 이 원칙을 깨지 않는다.
- 각 방 파일은 room1과 같은 구조: 상단 퍼즐 로직 순수 함수(테스트가 직접 호출) → 커스텀 위젯 → `buildXxx()`.
- 각 방 태스크는 `test/solutions.dart`에 자기 방의 정답 시퀀스 함수 `solveXxx(GameState s, GameCtx c, Room room)`를 추가한다 (Task 7 통합 테스트가 이어 붙인다). 방 테스트의 해피패스는 이 함수를 호출하고, 부정 테스트는 방 테스트 파일에 직접 쓴다.
- 아트 의뢰 문서 `art/roomN-assets.md`는 설계 표의 좌표를 그대로 옮긴다 (room1-assets.md 형식).

---

### Task 1: 공유 기믹 인프라 — RubbableScene 추출 + solutions.dart

**Files:**
- Create: `lib/core/rub_scene.dart`, `test/solutions.dart`
- Modify: `lib/rooms/room1_foyer.dart` (FrameCloseup을 RubbableScene 래퍼로 교체)
- Test: 기존 `test/room1_foyer_test.dart`가 회귀 그물 (수정 없이 통과해야 함) + `test/solutions_test.dart` 신규

**Interfaces:**
- Consumes: `GameCtx`, `gameImage`, `Cond`
- Produces:
  - `class RubbableScene extends StatefulWidget` (lib/core/rub_scene.dart) — 생성자 `RubbableScene({required GameCtx ctx, required String baseImage, required String coverImage, required Cond cleaned, required void Function(GameCtx c) onCleaned, double progressPerPx = 1 / 2500, Key? gestureKey})`. 동작: room1 FrameCloseup과 동일 — cleaned가 참이면 base만, 아니면 base 위에 `Opacity(1-progress)`의 cover, `onPanUpdate`로 `delta.distance * progressPerPx` 누적, 1.0 도달 시 `onCleaned(ctx)` 정확히 1회 호출(원샷 가드 — 최종리뷰 minor를 여기서 해소) + 이후 pan 무시. GestureDetector에 `key: gestureKey`.
  - `room1_foyer.dart`의 `FrameCloseup`은 삭제하고 closeup 'frame'을 `Scene(id: 'frame', custom: (_, c) => RubbableScene(ctx: c, baseImage: 'assets/scenes/foyer_frame_clean.png', coverImage: 'assets/scenes/foyer_frame_dust.png', cleaned: (s) => s.flag('foyer_dust_cleaned') >= 1, onCleaned: (c) { finishRubbing(c.s); c.sfx('sparkle'); }, gestureKey: const Key('frame_rub')))`로 교체. `finishRubbing`·`tapClockHand`는 그대로.
  - `test/solutions.dart` — 테스트 전용 라이브러리(테스트 파일 아님, `main()` 없음): room1 테스트의 findHotspot/tap 헬퍼를 일반화한 `Hotspot findHotspot(Room room, String sceneId, String hotspotId)`와 `void tapSpot(Room room, GameState s, GameCtx c, String sceneId, String hotspotId)` (활성 검사 expect 포함), 그리고 `void solveFoyer(GameState s, GameCtx c, Room room)` — room1 테스트의 정답 시퀀스와 동일 절차(외투 성냥→신발장 양초→조합→frame 탭+클로즈업 확인+finishRubbing→clock 탭+클로즈업 확인+tapClockHand×3→서랍→촛불→열쇠→문×2). 내부 expect로 각 단계 검증.
- 이 태스크는 room1 테스트 파일을 수정하지 않는다 — 기존 테스트가 그대로 통과하는 것이 FrameCloseup 대체의 회귀 증명이다.

- [ ] **Step 1: `test/solutions_test.dart` 작성** — `solveFoyer`가 새 GameState로 현관을 클리어하는지: `final room = buildFoyer(); solveFoyer(s, c, room); expect(room.cleared(s), isTrue);` (RED: solutions.dart 없음)
- [ ] **Step 2: RED 확인** — `.\tool\f.cmd test test/solutions_test.dart`
- [ ] **Step 3: 구현** — rub_scene.dart, solutions.dart, room1_foyer.dart 교체
- [ ] **Step 4: GREEN** — solutions_test + `test/room1_foyer_test.dart`(무수정 통과) 확인
- [ ] **Step 5: analyze + 전체 스위트** — "No issues found!", 42/42 (41+1)
- [ ] **Step 6: Commit** — "공유 기믹: RubbableScene 추출 + 정답 시퀀스 라이브러리 (문지르기 원샷 가드 포함)"

---

### Task 2: 방 2 — 거실 (Living Room)

기믹: 클릭 패턴(촛대 토글), 상태 변화(TV·벽난로), 유령 상호작용(부우). 난이도: 본편 도입.

**스토리:** 겁주기 담당 유령 "부우"가 문을 막고 있다. 부우는 사실 못 본 드라마 재방송 때문에 시무룩하다. TV를 켜 주면 소파로 가서 비켜 주고, TV 화면의 기묘한 방송이 촛대 퍼즐의 단서다.

**Files:**
- Create: `lib/rooms/room2_living.dart`, `test/room2_living_test.dart`, `art/room2-assets.md`
- Modify: `lib/rooms/rooms.dart` (buildLiving 추가), `lib/rooms/items.dart`, `lib/core/strings.dart`, `test/solutions.dart` (solveLiving)

**Interfaces — Produces:**
- `Room buildLiving()` (id: 'living', name: '거실'), `void toggleCandle(GameState s, int i)` — i∈1..4, `living_candle<i>` 0↔1 토글 후 패턴(c1==0, c2==1, c3==0, c4==1)이면 `living_fireplace_lit=1`(한 번 켜지면 유지)
- 플래그: `living_got_remote, living_tv_on, living_candle1..4, living_fireplace_lit, living_got_key, living_door_open, living_done`
- items.dart 추가: `remote(리모컨), key_living(거실 열쇠), note1(음표 카드 ♪달), oil(기름병)`

**정답 체인:** 쿠션→리모컨 → 리모컨으로 TV(부우 비킴+단서) → TV 클로즈업(2·4번 촛불 그림) → 촛대 2·4 켜기 → 벽난로 점화+비밀칸 → 열쇠·♪달·기름병 → 열쇠로 문 → 탈출.

**벽면 A `living_a`** (`assets/scenes/living_a.png` — 벽난로 벽):
| 핫스팟 id | rect LTWH | when / 게이트 | onTap |
|---|---|---|---|
| candle1 | 0.06,0.52,0.10,0.16 | fireplace_lit==0 | toggleCandle(1) + sfx('clock_tick') |
| candle2 | 0.28,0.52,0.10,0.16 | fireplace_lit==0 | toggleCandle(2) + sfx('clock_tick'); 점화되면 sfx('sparkle')+say(strLivingFireLit) |
| candle3 | 0.62,0.52,0.10,0.16 | fireplace_lit==0 | toggleCandle(3) 동일 |
| candle4 | 0.84,0.52,0.10,0.16 | fireplace_lit==0 | toggleCandle(4) 동일 (점화 체크는 toggleCandle 안이므로 2·4 어느 쪽이 마지막이든 동작) |
| secret_nook | 0.36,0.30,0.28,0.14 | onTap 게이트: fireplace_lit==0이면 say(strLivingMantel) | lit이고 got_key==0이면 give(key_living)+give(note1)+give(oil)+setFlag(living_got_key,1)+say(strLivingSecretFound); 이미 받았으면 say(strLivingSecretEmpty) |
| fireplace | 0.30,0.48,0.40,0.34 | — | say(fireplace_lit ? strLivingFireplaceLit : strLivingFireplaceCold) |
오버레이: `living_a_candle<i>_on.png`(각 촛대 rect와 동일 위치, when: living_candle<i>==1), `living_a_fire.png`(0.30,0.48,0.40,0.34, when: fireplace_lit), `living_a_nook_open.png`(0.36,0.30,0.28,0.14, when: fireplace_lit)

**벽면 B `living_b`** (`assets/scenes/living_b.png` — 소파·TV·문 벽):
| 핫스팟 id | rect | when / 게이트 | onTap |
|---|---|---|---|
| cushion | 0.08,0.62,0.18,0.14 | — | got_remote==0이면 setFlag+give(remote)+say(strLivingCushion); 이후 say(strLivingCushionEmpty) |
| tv | 0.10,0.24,0.24,0.22 | — | tv_on==1 → openCloseup('tv'); using('remote') → consume(remote)+setFlag(living_tv_on,1)+sfx('sparkle')+say(strLivingTvOn); 그 외 say(strLivingTvOff) |
| boo | 0.62,0.30,0.20,0.30 | tv_on==0 | sfx('ghost_giggle')+say(strLivingBooScare) |
| boo_sofa | 0.34,0.56,0.18,0.22 | tv_on==1 | sfx('ghost_giggle')+say(strLivingBooHappy) |
| door | 0.62,0.26,0.26,0.44 | — | tv_on==0 → say(strLivingBooBlocks); door_open==1 → sfx('door_open')+setFlag(living_done,1); using('key_living') → consume+sfx('unlock')+setFlag(living_door_open,1)+say(strLivingDoorOpened); 그 외 sfx('locked')+say(strLivingDoorLocked) |
오버레이: `living_b_boo_door.png`(0.60,0.28,0.24,0.34, when: tv_on==0), `living_b_boo_sofa.png`(0.34,0.56,0.18,0.22, when: tv_on==1), `living_b_tv_on.png`(0.10,0.24,0.24,0.22, when: tv_on==1), `living_b_door_open.png`(0.62,0.26,0.26,0.44, when: door_open==1)

**클로즈업 `tv`** (`assets/scenes/living_tv.png` — 지지직거리는 화면에 촛대 4개 그림, **2번째와 4번째만 불이 켜져 있음**): 핫스팟 없음(관찰 전용). 이미지 규격 1024×1024.

**onEnter:** say(strLivingIntro). **cleared:** living_done>=1.

**strings.dart 추가 (전문):**
```dart
// ── 거실 (room2_living) ──
const strLivingIntro = '"드, 들어오지 마! 여긴 겁주기 담당 부우 님의 구역이다!" …문 앞의 작은 유령이 이불을 뒤집어쓰고 떨고 있다.';
const strLivingBooScare = '"부우~! 무, 무섭지?! …안 무서워? 하아, 오늘 드라마 재방송도 놓쳤는데."';
const strLivingBooBlocks = '부우가 문 앞을 막고 있다. 뭔가 몹시 시무룩해 보인다. TV 이야기를 중얼거리는데…';
const strLivingBooHappy = '"오오, 3화부터구나!! 넌 좋은 인간이야. 문? 마음대로 해." 부우가 소파에 파묻혀 TV에 빠져 있다.';
const strLivingCushion = '쿠션 밑에서 리모컨을 찾았다! 유령도 리모컨은 숨기는구나.';
const strLivingCushionEmpty = '쿠션 밑엔 이제 과자 부스러기뿐이다.';
const strLivingTvOff = '낡은 TV. 전원이 꺼져 있다. 리모컨이 있어야겠는데.';
const strLivingTvOn = '지지직… TV가 켜졌다! 기묘한 방송이 나온다. 화면을 자세히 봐 두자.';
const strLivingMantel = '벽난로 위 선반. 벽돌 하나가 헐거워 보이는데, 지금은 꿈쩍도 안 한다. 벽난로에 불이 붙으면 어떨까?';
const strLivingFireplaceCold = '차갑게 식은 벽난로. 촛대들과 뭔가 연결되어 있는 것 같다.';
const strLivingFireplaceLit = '벽난로가 활활 타오른다. 훈훈하다 못해 조금 으스스하게 따뜻하다.';
const strLivingFireLit = '화르륵! 촛불의 배열에 맞춰 벽난로에 불이 붙었다! 위쪽 벽돌이 덜컹 열렸다.';
const strLivingSecretFound = '비밀칸에서 거실 열쇠, 달 그림 음표 카드, 기름병을 찾았다!';
const strLivingSecretEmpty = '비밀칸은 이제 비어 있다.';
const strLivingDoorLocked = '잠겨 있다. 열쇠 구멍이 반짝인다.';
const strLivingDoorOpened = '철컥! 다음 방으로 가는 문이 열렸다.';
```

**힌트 (hints, 전문):**
- `p_living_boo` '문을 막는 유령': ①'문을 막은 유령은 겁을 주고 싶은 게 아니라 뭔가 아쉬운 게 있어요. 대사를 잘 들어보세요.' ②'부우는 드라마 재방송을 놓쳐 시무룩해요. TV를 켜 줄 방법을 찾아보세요 — 소파 쿠션을 뒤져 보면?' ③'정답: 쿠션에서 리모컨을 얻고, 리모컨을 선택한 채 TV를 탭하면 부우가 비켜 줘요.' solved: tv_on>=1
- `p_living_candles` '촛대와 벽난로': ①'촛대 네 개는 켜고 끌 수 있어요. 정답 배열이 이 방 어딘가에 그림으로 나와요.' ②'켜진 TV 화면을 자세히 보세요. 촛대 네 개 중 어떤 것에 불이 붙어 있나요?' ③'정답: 2번째와 4번째 촛대만 켜세요(1·3번은 끈 상태). 벽난로가 점화되고 비밀칸이 열려요.' solved: fireplace_lit>=1
- `p_living_door` '잠긴 문': ①'문은 평범한 자물쇠예요. 열쇠는 이 방 안에 숨겨져 있어요.' ②'벽난로 위 열린 비밀칸을 살펴보세요.' ③'정답: 비밀칸의 거실 열쇠를 선택하고 문을 탭하세요.' solved: door_open>=1

**items.dart 추가 (verbatim):** `'remote': Item('remote', '리모컨'), 'key_living': Item('key_living', '거실 열쇠'), 'note1': Item('note1', '음표 카드 ♪달'), 'oil': Item('oil', '기름병'),` — 조합 테이블 변경 없음.

**테스트 (test/room2_living_test.dart):**
- `solveLiving` (solutions.dart에 추가, 시퀀스): cushion→remote 확인 → select remote→tv 탭→tv_on·리모컨 소모 확인 → tv 탭→closeupId 'tv' 확인(containsKey)→closeCloseup → toggleCandle(2)·toggleCandle(4)→fireplace_lit 확인 → secret_nook→key·note1·oil 보유 확인 → select key_living→door→open 확인·열쇠 소모 → door→living_done. 해피패스 테스트는 solveLiving 호출 후 cleared 확인.
- 부정 테스트: ①tv_on==0에서 door 탭 → door_open 0 유지(부우가 막음) ②잘못된 패턴(1·2 켜기) → fireplace_lit==0 ③fireplace_lit 전 secret_nook → 아이템 없음 ④점화 후 candle 핫스팟 when 비활성 확인
- `toggleCandle` 단위: 토글 왕복, 패턴 완성 시 lit, lit 후 재토글해도 lit 유지
- 위젯 테스트 불필요 (커스텀 위젯 없음 — 전부 선언형)

- [ ] Step 1: 테스트+solutions 추가 작성 → RED 확인
- [ ] Step 2: strings/items/room2_living.dart/rooms.dart 구현 → 대상 테스트 GREEN
- [ ] Step 3: `art/room2-assets.md` 작성 (위 표의 파일명·rect 그대로: 씬 2, 클로즈업 1, 오버레이 8, 아이템 4 — 아이템은 512×512 투명, note1엔 달 그림+♪)
- [ ] Step 4: analyze "No issues found!" + 전체 스위트 green
- [ ] Step 5: Commit — "방 2 거실: 부우·촛대 패턴·벽난로 비밀칸"

---

### Task 3: 방 3 — 서재 (Study)

기믹: 문지르기(RubbableScene 재사용), 순서 입력(색 책), 교차 단서(방 2의 기름병 소비). 난이도: 상승 — 이중 잠금 문.

**스토리:** 사서 유령 "너덜"이 책에 파묻혀 있다. 잉크로 얼룩진 종이에 책을 뽑는 순서가 숨어 있다.

**Files:**
- Create: `lib/rooms/room3_study.dart`, `test/room3_study_test.dart`, `art/room3-assets.md`
- Modify: `lib/rooms/rooms.dart`, `lib/rooms/items.dart`, `lib/core/strings.dart`, `test/solutions.dart` (solveStudy)

**Interfaces — Produces:**
- `Room buildStudy()` (id: 'study', name: '서재'), `void tapBook(GameState s, int i)` — 정답 순서 [2,4,1,3](파→초→빨→노). `study_book_seq` 진행도: 다음 정답이면 +1, 틀리면 0으로 리셋. 4 도달 시 `study_nook_open=1`. nook_open 후엔 no-op.
- 플래그: `study_paper_rubbed, study_book_seq, study_nook_open, study_got_crank, study_globe_open, study_got_key, study_door_unlocked, study_door_oiled, study_done`
- items.dart 추가: `crank(놋쇠 크랭크), key_study(서재 열쇠), note2(음표 카드 ♪별)` — oil은 방 2에서 옴(여기서 소비)

**정답 체인:** 종이 문지르기 → 색 순서(파초빨노) → 책 4권 순서대로 탭 → 숨은 공간 → 크랭크+♪별 → 지구본에 크랭크 → 서재 열쇠 → 문: 열쇠(잠금 해제) + 기름(경첩) 둘 다 → 탈출.

**벽면 A `study_a`** (책장 벽): 색 책 4권 — book_red(0.10,0.30,0.10,0.16), book_blue(0.30,0.30,0.10,0.16), book_yellow(0.54,0.30,0.10,0.16), book_green(0.76,0.30,0.10,0.16) — 각각 tapBook(1)/(2)/(3)/(4) + sfx('clock_tick'), when: nook_open==0. 진행이 리셋되면 say(strStudyBookReset)는 tapBook이 아니라 onTap에서: 탭 전 seq 저장→탭 후 seq==0 && 이전>0이면 say. nook 완성 순간 sfx('unlock')+say(strStudyNookOpen).
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| nook | 0.40,0.52,0.20,0.18 | nook_open==1 && got_crank==0 (when) | give(crank)+give(note2)+setFlag(study_got_crank,1)+say(strStudyNookLoot) |
| ned | 0.72,0.60,0.18,0.26 | — | sfx('ghost_giggle')+say(strStudyNed) |
오버레이: `study_a_nook_open.png`(0.40,0.52,0.20,0.18, when: nook_open)

**벽면 B `study_b`** (책상·지구본·문 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| paper | 0.08,0.56,0.16,0.12 | — | openCloseup('paper') |
| globe | 0.30,0.44,0.18,0.20 | — | globe_open==1 && got_key==0 → give(key_study)+setFlag(study_got_key,1)+say(strStudyGlobeKey); using('crank') → consume(crank)+sfx('unlock')+setFlag(study_globe_open,1)+say(strStudyGlobeOpen); 그 외 say(strStudyGlobe) |
| door | 0.62,0.24,0.26,0.46 | — | 아래 '문 로직' |
| desk | 0.04,0.66,0.24,0.18 | — | say(strStudyDesk) |
문 로직: unlocked&&oiled&&탭 → sfx('door_open')+setFlag(study_done,1) / using('key_study') → consume+sfx('unlock')+setFlag(study_door_unlocked,1)+say(strStudyDoorUnlocked) / using('oil') → consume(oil)+setFlag(study_door_oiled,1)+say(strStudyDoorOiled) / unlocked&&!oiled → sfx('locked')+say(strStudyDoorSqueak) / 그 외 sfx('locked')+say(strStudyDoorLocked)
오버레이: `study_b_globe_open.png`(0.30,0.44,0.18,0.20, when: globe_open), `study_b_door_open.png`(0.62,0.24,0.26,0.46, when: study_done)

**클로즈업 `paper`:** `Scene(id:'paper', custom: RubbableScene(base: 'assets/scenes/study_paper_clean.png', cover: 'assets/scenes/study_paper_ink.png', cleaned: study_paper_rubbed>=1, onCleaned: setFlag(study_paper_rubbed,1)+sfx('sparkle'), gestureKey: Key('paper_rub')))` — base 그림: **책 네 권 색이 순서대로: 파랑→초록→빨강→노랑** (글자 없이 색 블록 화살표).

**onEnter:** say(strStudyIntro). **cleared:** study_done>=1.

**strings.dart 추가 (전문):**
```dart
// ── 서재 (room3_study) ──
const strStudyIntro = '책 무더기 속에서 안경 쓴 유령이 고개를 내민다. "쉿. 여긴 서재야. …책 제목? 다 까먹었어."';
const strStudyNed = '"이 방의 비밀? 음… 잉크를 쏟았던 기억은 나. 어디에 쏟았더라." 너덜이 책장을 뒤적인다.';
const strStudyDesk = '오래된 책상. 잉크병이 쓰러져 있고, 얼룩진 종이 한 장이 눈에 띈다.';
const strStudyBookReset = '덜컥. 책들이 원래대로 튕겨 돌아왔다. 순서가 틀린 모양이다.';
const strStudyNookOpen = '드르륵! 책장 한 칸이 안으로 밀리며 숨은 공간이 드러났다!';
const strStudyNookLoot = '숨은 공간에서 놋쇠 크랭크와 별 그림 음표 카드를 찾았다!';
const strStudyGlobe = '낡은 지구본. 옆면에 크랭크를 꽂는 구멍이 있다.';
const strStudyGlobeOpen = '끼릭끼릭… 지구본이 반으로 갈라졌다!';
const strStudyGlobeKey = '지구본 안에서 서재 열쇠를 꺼냈다.';
const strStudyDoorLocked = '잠겨 있다. 열쇠 구멍이 오래됐다.';
const strStudyDoorUnlocked = '철컥. 잠금은 풀렸는데… 문이 꿈쩍도 안 한다. 경첩이 시뻘겋게 녹슬었다.';
const strStudyDoorSqueak = '끼이이익… 경첩이 녹슬어 열리지 않는다. 기름칠이 필요하다.';
const strStudyDoorOiled = '기름을 듬뿍 발랐다. 경첩이 부드럽게 움직인다.';
```

**힌트:** `p_study_books` '색깔 책들'(①책 네 권은 뽑는 순서가 있어요. 순서는 이 방의 얼룩 속에 숨어 있어요 ②책상 위 얼룩진 종이를 문질러 닦아 보세요. 색 순서가 나와요 ③정답: 파랑→초록→빨강→노랑 순서로 탭. solved: nook_open), `p_study_globe` '갈라지는 지구본'(①지구본엔 뭔가 꽂는 구멍이 있어요 ②숨은 공간에서 찾은 도구를 선택하고 지구본을 탭 ③정답: 놋쇠 크랭크 사용 → 열쇠. solved: globe_open), `p_study_door` '녹슨 문'(①이 문은 자물쇠 말고도 문제가 하나 더 있어요 ②열쇠로 잠금을 풀어도 경첩이 녹슬어 안 열려요. 지난 방에서 챙긴 물건 중에 도움이 될 것이? ③정답: 거실 비밀칸의 기름병을 문에 사용한 뒤, 서재 열쇠로 열기. solved: study_done)

**items.dart 추가:** `'crank': Item('crank', '놋쇠 크랭크'), 'key_study': Item('key_study', '서재 열쇠'), 'note2': Item('note2', '음표 카드 ♪별'),`

**테스트:** solveStudy는 시작 시 `s.give('oil')`을 **하지 않는다** — 대신 함수 주석에 "방 2 진행분 전제"를 적고, 방 단독 테스트에서는 setUp에서 give('oil') 후 solveStudy 호출(전제 명시). 부정: ①틀린 순서(2,1) → seq 0 리셋 ②기름 없이 열쇠만 → done 0 (squeak) ③크랭크 없이 지구본 → globe_open 0 ④paper 핫스팟 탭 → closeup 확인. tapBook 단위 테스트(정답 진행·리셋·완료 후 no-op). RubbableScene 재사용이라 위젯 테스트는 원샷 가드 1개만(빠른 연속 pan에서 onCleaned 1회 — Task 1이 이미 커버했으면 생략 가능, Task 1 테스트 확인 후 판단해 보고서에 명시).

- [ ] Step 1: 테스트+solveStudy → RED
- [ ] Step 2: 구현 → GREEN
- [ ] Step 3: art/room3-assets.md (씬 2, 클로즈업 base+cover 2, 오버레이 3, 아이템 3)
- [ ] Step 4: analyze + 전체 green
- [ ] Step 5: Commit — "방 3 서재: 잉크 문지르기·색 책 순서·이중 잠금 문"

---

### Task 4: 방 4 — 주방 (Kitchen)

기믹: 다단계 수집+조합(유령 수프), 사운드 단서(두드려 찾기 — 음소거 대응은 대사·화면 묘사). 커스텀 위젯 없음.

**스토리:** 요리사 유령 "국자"는 맛을 못 봐서 슬프다. "유령 수프"(재료: 말린 버섯, 이끼 낀 물, 노래하는 주전자)를 만들어 주면 뒷문 열쇠를 준다.

**Files:**
- Create: `lib/rooms/room4_kitchen.dart`, `test/room4_kitchen_test.dart`, `art/room4-assets.md`
- Modify: `lib/rooms/rooms.dart`, `lib/rooms/items.dart`, `lib/core/strings.dart`, `test/solutions.dart` (solveKitchen)

**Interfaces — Produces:**
- `Room buildKitchen()` (id: 'kitchen', name: '주방')
- 플래그: `kitchen_got_bottle, kitchen_got_mushroom, kitchen_hollow_found, kitchen_got_kettle, kitchen_ghost_fed, kitchen_door_open, kitchen_done`
- items.dart 추가: `empty_bottle(빈 병), water_bottle(이끼물 병), mushroom(말린 버섯), kettle_singing(노래하는 주전자), soup_base(수프 베이스), ghost_soup(유령 수프), key_kitchen(뒷문 열쇠), note3(음표 카드 ♪해)`
- **조합 테이블 추가 2건:** `mushroom+water_bottle → soup_base`, `ghost_soup ← kettle_singing+soup_base` (키는 사전순 정렬 규칙 준수)

**정답 체인:** 조리대→빈 병 → 싱크대에 병 사용→이끼물 병 → 찬장 항아리→버섯 → 찬장 문 4개 두드려 속 빈 문 찾기→노래하는 주전자 → 조합(버섯+이끼물=베이스, 베이스+주전자=유령 수프) → 국자에게 수프 → 뒷문 열쇠+♪해 → 문 → 탈출.

**벽면 A `kitchen_a`** (화덕·조리대·국자 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| counter | 0.06,0.60,0.20,0.14 | — | got_bottle==0 → setFlag+give(empty_bottle)+say(strKitchenBottle); 이후 say(strKitchenCounterEmpty) |
| stove | 0.34,0.50,0.26,0.26 | — | say(strKitchenStove) |
| gukja | 0.68,0.34,0.22,0.36 | — | using('ghost_soup') → consume(ghost_soup)+setFlag(kitchen_ghost_fed,1)+give(key_kitchen)+give(note3)+sfx('sparkle')+say(strKitchenFed); ghost_fed==1 → say(strKitchenGukjaHappy); 그 외 sfx('ghost_giggle')+say(strKitchenGukjaAsk) |
| jar | 0.34,0.20,0.14,0.16 | — | got_mushroom==0 → setFlag+give(mushroom)+say(strKitchenJar); 이후 say(strKitchenJarEmpty) |

**벽면 B `kitchen_b`** (찬장·싱크대·뒷문 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| sink | 0.06,0.52,0.20,0.18 | — | using('empty_bottle') → take(empty_bottle)+give(water_bottle)+sfx('sparkle')+say(strKitchenFill); 그 외 say(strKitchenSink) |
| cupboard1 | 0.34,0.28,0.10,0.14 | — | sfx('locked')+say(strKitchenKnockDull) |
| cupboard2 | 0.46,0.28,0.10,0.14 | — | hollow_found==0 → setFlag(kitchen_hollow_found,1)+sfx('unlock')+say(strKitchenKnockHollow); got_kettle==0 && hollow_found==1 → setFlag(kitchen_got_kettle,1)+give(kettle_singing)+say(strKitchenKettle); 이후 say(strKitchenCupboardEmpty) |
| cupboard3 | 0.58,0.28,0.10,0.14 | — | sfx('locked')+say(strKitchenKnockDull) |
| cupboard4 | 0.70,0.28,0.10,0.14 | — | sfx('locked')+say(strKitchenKnockDull) |
| backdoor | 0.62,0.52,0.26,0.40 | — | door_open==1 → sfx('door_open')+setFlag(kitchen_done,1); using('key_kitchen') → consume+sfx('unlock')+setFlag(kitchen_door_open,1)+say(strKitchenDoorOpened); 그 외 sfx('locked')+say(strKitchenDoorLocked) |
오버레이: `kitchen_b_cup2_open.png`(0.46,0.28,0.10,0.14, when: hollow_found==1), `kitchen_b_door_open.png`(0.62,0.52,0.26,0.40, when: door_open==1)

주의(사운드 단서 공정성): 속 빈 문은 sfx 차이(**locked=둔탁**, unlock=울림)에 더해 **대사로 소리를 묘사**해서 음소거 유저도 구분 가능(스펙 §3.3-6). cupboard2의 첫 탭이 발견 판정이므로 순서 상 무작위 두드리기로도 반드시 발견된다 — 난이도는 "두드려 볼 생각"에 있다.

**onEnter:** say(strKitchenIntro). **cleared:** kitchen_done>=1.

**strings.dart 추가 (전문):**
```dart
// ── 주방 (room4_kitchen) ──
const strKitchenIntro = '커다란 국자를 든 유령이 텅 빈 냄비를 젓고 있다. "300년째 맛을 못 봤어… 유령 수프만 있다면."';
const strKitchenGukjaAsk = '"유령 수프의 재료는 셋. 말린 버섯, 이끼 낀 물, 그리고… 노래하는 주전자의 김이지. 만들어 주면 뒷문 열쇠를 주마."';
const strKitchenGukjaHappy = '"완벽한 간이야…!" 국자가 감격에 젖어 수프를 젓고 있다.';
const strKitchenFed = '국자가 수프를 한 모금 넘긴다(어떻게?). "이 맛이야!!" 뒷문 열쇠와 해 그림 음표 카드를 건넸다!';
const strKitchenBottle = '조리대에서 빈 병을 챙겼다.';
const strKitchenCounterEmpty = '조리대엔 이제 먼지뿐이다.';
const strKitchenStove = '오래된 화덕. 불씨가 유령불처럼 파랗게 일렁인다.';
const strKitchenJar = '항아리 속에서 말린 버섯을 찾았다. 몇백 년 묵은 향이 난다.';
const strKitchenJarEmpty = '항아리는 비었다.';
const strKitchenSink = '싱크대에 이끼 낀 물이 고여 있다. 담을 것이 필요하다.';
const strKitchenFill = '병에 이끼 낀 물을 가득 담았다. 초록빛이 은은하다.';
const strKitchenKnockDull = '퉁, 퉁. 꽉 찬 둔탁한 소리다.';
const strKitchenKnockHollow = '통통! 속이 빈 울림이다! 문이 스르륵 열렸다.';
const strKitchenKettle = '찬장 안에서 노래하는 주전자를 꺼냈다. 흥얼거림이 멈추지 않는다.';
const strKitchenCupboardEmpty = '주전자가 있던 자리만 휑하다.';
const strKitchenDoorLocked = '뒷문은 잠겨 있다.';
const strKitchenDoorOpened = '철컥! 뒷문이 열렸다. 지하로 내려가는 계단이 보인다.';
```

**힌트:** `p_kitchen_soup` '유령 수프 만들기'(①국자의 대사에 재료 세 가지가 다 나와요 ②조리대의 병 + 싱크대 물, 항아리의 버섯 — 그리고 세 번째 재료는 소리로 찾아요. 인벤토리에서 둘씩 조합 ③정답: 병을 싱크대에 사용→이끼물 병, 버섯+이끼물 병=수프 베이스, 수프 베이스+노래하는 주전자=유령 수프. solved: has ghost_soup || ghost_fed), `p_kitchen_kettle` '세 번째 재료'(①찬장 문들을 하나씩 두드려 보세요. 소리가 다른 곳이 있어요 ②"통통" 하고 속이 빈 울림이 나는 문이 정답 ③정답: 왼쪽에서 2번째 찬장 문 — 그 안에 노래하는 주전자. solved: got_kettle), `p_kitchen_door` '뒷문'(①열쇠는 국자가 갖고 있어요 ②국자가 원하는 걸 만들어 주세요 ③정답: 유령 수프를 선택하고 국자를 탭 → 열쇠 획득 → 뒷문. solved: kitchen_done)

**테스트:** solveKitchen 시퀀스(위 체인, tryCombine 2회 포함, note3 보유 확인). 부정: ①수프 없이 국자 → 열쇠 없음 ②빈 병 없이 싱크대 → water_bottle 없음 ③cupboard1/3/4 → hollow_found 0 유지 ④조합 순서 뒤집기도 성립(combineResult 대칭) ⑤열쇠 전 문 → locked.

- [ ] Step 1: 테스트+solveKitchen → RED
- [ ] Step 2: 구현(조합 테이블 포함) → GREEN
- [ ] Step 3: art/room4-assets.md (씬 2, 오버레이 2, 아이템 8)
- [ ] Step 4: analyze + 전체 green
- [ ] Step 5: Commit — "방 4 주방: 유령 수프 다단계 조합 + 두드려 찾기"

---

### Task 5: 방 5 — 지하실 (Cellar) + sensors_plus

기믹: 상태 변화(어둠/야광), 드래그(와인통 밀기), 흔들기(폰 셰이크, 연타 폴백). 난이도: 최고조.

**스토리:** 겁쟁이 유령 "덜덜"이 어둠 속에서 떨고 있다. 어둠에서만 보이는 야광 표시가 길잡이다.

**Files:**
- Create: `lib/rooms/room5_cellar.dart`, `test/room5_cellar_test.dart`, `art/room5-assets.md`
- Modify: `pubspec.yaml`(`sensors_plus: ^6.0.0` — 해석 실패 시 ^5.0.0 폴백 후 보고), `lib/rooms/rooms.dart`, `lib/rooms/items.dart`, `lib/core/strings.dart`, `test/solutions.dart` (solveCellar)

**Interfaces — Produces:**
- `Room buildCellar()` (id: 'cellar', name: '지하실')
- 순수 함수: `void dropShelfKey(GameState s)` — cellar_light==1이고 key_dropped==0일 때만 `cellar_key_dropped=1` / `void moveBarrel(GameState s, double dx)` — light==1일 때 `cellar_barrel_px`에 dx 누적(플래그는 정수라 픽셀×100 아닌 **진행도 0~100 정수**로: +=(dx/6).round().clamp(0,100), 100 도달 시 `cellar_barrel_moved=1`)
- 플래그: `cellar_got_fuse, cellar_fuse_installed, cellar_light, cellar_key_dropped, cellar_got_key, cellar_barrel_px, cellar_barrel_moved, cellar_door_open, cellar_done, cellar_shelf_taps`
- items.dart 추가: `fuse(낡은 퓨즈), key_cellar(녹슨 열쇠), note4(음표 카드 ♪구름)`

**정답 체인:** (어둠) 야광 빛나는 상자 → 퓨즈+♪구름 → 배전반에 퓨즈 → 스위치 → 불 켬 → 와인통 클로즈업에서 드래그로 밀기 → 숨은 쪽문 발견 → 선반 클로즈업: 폰 흔들기(또는 선반 10연타) → 열쇠 낙하 → 열쇠 줍기 → 쪽문 → 탈출.

**벽면 A `cellar_a`** (선반·상자들 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| glow_box | 0.10,0.62,0.18,0.16 | when: got_fuse==0 | light==0 → setFlag(cellar_got_fuse,1)+give(fuse)+give(note4)+say(strCellarGlowBox); light==1 → say(strCellarBoxPlain) *(불 켠 뒤엔 어느 상자인지 표가 안 나므로 사실상 어둠에서 열게 됨 — 야광 오버레이가 이 상자를 가리킴)* |
| box2 | 0.34,0.64,0.16,0.14 | — | say(strCellarBoxEmpty) |
| box3 | 0.56,0.64,0.16,0.14 | — | say(strCellarBoxEmpty) |
| shelf | 0.34,0.20,0.40,0.26 | — | openCloseup('shelf') |
| deoldeol | 0.78,0.44,0.16,0.26 | — | sfx('ghost_giggle')+say(light==1 ? strCellarDeoldeolLight : strCellarDeoldeolDark) |
오버레이(선언 순서 중요 — 어둠막 먼저, 야광 나중): `cellar_a_dark.png`(0,0,1,1, when: light==0), `cellar_a_glow.png`(0.08,0.58,0.24,0.24, when: light==0 — 야광 테두리가 glow_box를 가리킴), `cellar_a_key_floor.png`(0.36,0.50,0.12,0.10, when: key_dropped==1 && got_key==0)
| key_floor | 0.34,0.48,0.16,0.14 | when: key_dropped==1 && got_key==0 | give(key_cellar)+setFlag(cellar_got_key,1)+say(strCellarKeyTaken) |

**벽면 B `cellar_b`** (와인통·배전반·쪽문 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| fusebox | 0.08,0.28,0.16,0.18 | — | using('fuse') → consume(fuse)+setFlag(cellar_fuse_installed,1)+sfx('unlock')+say(strCellarFuseIn); 그 외 say(strCellarFusebox) |
| light_switch | 0.30,0.30,0.10,0.12 | — | fuse_installed==0 → say(strCellarSwitchDead); 그 외 addFlag 토글: setFlag(cellar_light, light==1?0:1)+sfx('clock_tick')+say(light 켜지면 strCellarLightOn) |
| barrel | 0.50,0.44,0.30,0.36 | — | light==0 → say(strCellarTooDark); barrel_moved==1 → say(strCellarBarrelMoved); 그 외 openCloseup('barrel') |
| small_door | 0.56,0.30,0.20,0.30 | when: barrel_moved==1 | door_open==1 → sfx('door_open')+setFlag(cellar_done,1); using('key_cellar') → consume+sfx('unlock')+setFlag(cellar_door_open,1)+say(strCellarDoorOpened); 그 외 sfx('locked')+say(strCellarDoorLocked) |
오버레이: `cellar_b_dark.png`(0,0,1,1, when: light==0), `cellar_b_glow_arrow.png`(0.44,0.36,0.20,0.16, when: light==0 — 야광 화살표가 와인통 쪽), `cellar_b_barrel_moved.png`(0.50,0.36,0.34,0.44, when: barrel_moved==1 — 통이 밀려나고 쪽문 노출)

**클로즈업 `barrel` (커스텀 BarrelDrag):** `cellar_barrel_close.png` 위에 GestureDetector(key: Key('barrel_drag')) — onPanUpdate에서 `moveBarrel(s, d.delta.dx.abs())` 호출(양방향 허용), moved 완성 순간 sfx('door_open')+say(strCellarBarrelDone). 진행 중 통 위치를 `Transform.translate(x: progress비율 × 화면폭×0.2)`로 시각화. moved 후엔 pan 무시.
**클로즈업 `shelf` (커스텀 ShelfShake):** `cellar_shelf_close.png`. ①initState에서 sensors_plus `userAccelerometerEventStream()` 구독(try/catch로 미지원 기기 무시), 이벤트 벡터 크기 sqrt(x²+y²+z²) > 12이면 `dropShelfKey(s)` ②GestureDetector(key: Key('shelf_tap'))로 전체 탭: `cellar_shelf_taps` addFlag, 10 이상이면 dropShelfKey(s) (연타 폴백 — 접근성) ③key_dropped 완성 순간 sfx('unlock')+say(strCellarKeyDrop) ④dispose에서 구독 해제. 낙하 후 클로즈업엔 열쇠 없는 선반(오버레이 불필요 — 대사로 안내, 열쇠는 벽면 A 바닥).

**onEnter:** say(strCellarIntro). **cleared:** cellar_done>=1.

**strings.dart 추가 (전문):**
```dart
// ── 지하실 (room5_cellar) ──
const strCellarIntro = '"꺄악! 누, 누구야! …사람? 다행이다아. 난 덜덜. 여기 너무 어두워서 300년째 무서워." 어둠 속 어딘가에서 이가 딱딱 부딪히는 소리가 난다.';
const strCellarDeoldeolDark = '"저기, 저기 빛나는 거 보여? 나는 무서워서 못 만져. 네가 좀…" 덜덜이 구석에서 떨고 있다.';
const strCellarDeoldeolLight = '"불 켜니까 살 것 같다! …참, 선반 위에 열쇠 있는 거 알아? 저긴 아무도 못 닿아. 온 집이 흔들리지 않는 한!"';
const strCellarGlowBox = '야광 표시가 빛나는 상자를 열었다. 낡은 퓨즈와 구름 그림 음표 카드!';
const strCellarBoxPlain = '평범한 상자다. 불을 켜니 다 똑같아 보인다.';
const strCellarBoxEmpty = '빈 상자다. 거미가 항의하듯 쳐다본다.';
const strCellarFusebox = '배전반. 퓨즈 하나가 빠져 있는 자리가 보인다.';
const strCellarFuseIn = '퓨즈를 끼웠다. 배전반이 웅 하고 깨어난다.';
const strCellarSwitchDead = '딸깍. 딸깍. 아무 일도 일어나지 않는다. 배전반이 죽어 있다.';
const strCellarLightOn = '팟! 지하실에 불이 들어왔다. 덜덜의 환호성이 들린다.';
const strCellarTooDark = '너무 어두워서 손잡이를 찾을 수 없다.';
const strCellarBarrelDone = '드드득…! 와인통이 밀려나며 작은 쪽문이 드러났다!';
const strCellarBarrelMoved = '통은 이미 밀어 뒀다. 쪽문이 보인다.';
const strCellarKeyDrop = '와장창! 선반이 흔들리며 열쇠가 바닥으로 떨어졌다! 덜덜: "지, 지진이야?!"';
const strCellarKeyTaken = '바닥에 떨어진 녹슨 열쇠를 주웠다.';
const strCellarDoorLocked = '쪽문은 잠겨 있다. 녹슨 열쇠 구멍.';
const strCellarDoorOpened = '끼익… 쪽문이 열렸다. 좁은 계단이 위로 이어진다.';
```

**힌트:** `p_cellar_light` '어둠 밝히기'(①어둠 속에서만 보이는 것이 있어요. 불을 켜기 전에 잘 둘러보세요 ②야광 표시가 빛나는 상자 안에 배전반에 쓸 것이 ③정답: 야광 상자의 퓨즈를 배전반에 사용 → 스위치. solved: cellar_light), `p_cellar_door` '숨은 쪽문'(①불을 켜기 전 벽에 야광 화살표가 가리키던 것은? ②와인통을 열고(탭) 옆으로 밀어 보세요 — 손가락으로 계속 끄세요 ③정답: 와인통 클로즈업에서 드래그로 끝까지 밀면 쪽문이 나와요. solved: barrel_moved), `p_cellar_key` '닿지 않는 열쇠'(①선반 위 열쇠는 손이 닿지 않아요. 덜덜의 말을 다시 들어보세요 — "온 집이 흔들리지 않는 한!" ②폰을 흔들어 보세요! (또는 선반을 여러 번 두드려도 돼요) ③정답: 선반 클로즈업에서 기기를 흔들거나 10번 연타 → 열쇠가 바닥에 떨어져요. solved: cellar_got_key)

**items.dart 추가:** `'fuse': Item('fuse', '낡은 퓨즈'), 'key_cellar': Item('key_cellar', '녹슨 열쇠'), 'note4': Item('note4', '음표 카드 ♪구름'),`

**테스트:** solveCellar(glow_box→퓨즈·note4→fusebox 사용→switch→light 확인→barrel 탭→closeup 확인→moveBarrel 반복 호출로 moved→shelf 탭→closeup 확인→dropShelfKey (센서 경로의 순수 함수)→key_floor 줍기→key로 small_door→탈출). 부정: ①불 켜기 전 barrel → 클로즈업 안 열림 ②불 꺼진 상태 dropShelfKey no-op ③barrel_moved 전 small_door when 비활성 ④퓨즈 없이 스위치 → light 0. 단위: moveBarrel 누적·완료, dropShelfKey 게이트, 연타 폴백(cellar_shelf_taps 10 → drop). 위젯: ShelfShake 10연타 → key_dropped (센서는 실기기 수동 검증으로 보고서에 명시), BarrelDrag 드래그 반복 → barrel_moved.

- [ ] Step 1: pubspec에 sensors_plus 추가 + `.\tool\f.cmd pub get`
- [ ] Step 2: 테스트+solveCellar → RED
- [ ] Step 3: 구현 → GREEN
- [ ] Step 4: art/room5-assets.md (씬 2, 클로즈업 2, 오버레이 6 — 어둠막 2장은 반투명 남색 전면, 야광은 초록 형광, 아이템 3)
- [ ] Step 5: analyze + 전체 green
- [ ] Step 6: Commit — "방 5 지하실: 야광 어둠·와인통 드래그·셰이크 열쇠 (+sensors_plus)"

---

### Task 6: 방 6 — 다락방 (Attic) + 진짜 엔딩

기믹: 교차 단서 총집결(음표 카드 4장 소비), 순서 연주(오르간), 유령 상호작용(고스포 재등장). 최종 방.

**스토리:** 고스포가 기다린다. "마지막 시험이다." 삼촌의 트렁크는 오르간 연주로만 열린다. 유언장의 코믹 반전으로 챕터 1 마무리.

**Files:**
- Create: `lib/rooms/room6_attic.dart`, `test/room6_attic_test.dart`, `art/room6-assets.md`
- Modify: `lib/rooms/rooms.dart`, `lib/core/strings.dart` (attic 대사 + **strChapterEnd 교체**), `test/solutions.dart` (solveAttic)

**Interfaces — Produces:**
- `Room buildAttic()` (id: 'attic', name: '다락방'), `void tapOrganKey(GameState s, int i)` — i∈1..4(도레미파). 게이트: `attic_cards_placed<4`면 no-op. 정답 순서 **[1,3,2,4] (도미레파)**. `attic_organ_seq` 진행/리셋, 완료 시 `attic_organ_played=1`.
- 플래그: `attic_cards_placed, attic_organ_seq, attic_organ_played, attic_got_will, attic_done`
- 아이템 추가 없음 (note1~4 소비)

**단서 구조:** 카드 그림 = 음 매핑(♪달=도, ♪별=레, ♪해=미, ♪구름=파 — 카드 이름에 이미 그림 명시). 벽걸이 자수(클로즈업) = 연주 순서: **달→해→별→구름** ⇒ 도→미→레→파 = 건반 [1,3,2,4].

**벽면 A `attic_a`** (오르간 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| music_stand | 0.36,0.30,0.28,0.14 | — | using note1/note2/note3/note4 중 하나 → 해당 카드 consume + addFlag(attic_cards_placed) + say(strAtticCardPlaced) (4장째엔 sfx('sparkle')+say(strAtticCardsAll)); 카드 미선택 → say(cards_placed<4 ? strAtticStandEmpty : strAtticStandFull) |
| organ | 0.24,0.44,0.52,0.34 | — | cards_placed<4 → say(strAtticOrganNoCards); 그 외 openCloseup('organ') |
| ghospo | 0.78,0.36,0.18,0.28 | — | sfx('ghost_giggle')+say(organ_played==1 ? strAtticGhospoProud : strAtticGhospoHint) |
오버레이: `attic_a_cards.png`(0.36,0.30,0.28,0.14, when: cards_placed>=4)

**벽면 B `attic_b`** (트렁크·창문·자수 벽):
| 핫스팟 | rect | 게이트 | onTap |
|---|---|---|---|
| embroidery | 0.10,0.24,0.22,0.20 | — | openCloseup('embroidery') |
| trunk | 0.36,0.54,0.34,0.28 | — | organ_played==0 → sfx('locked')+say(strAtticTrunkLocked); got_will==0 → setFlag(attic_got_will,1)+sfx('door_open')+say(strAtticWill); 그 외 → setFlag(attic_done,1) *(유언장 대사 확인 후 다시 탭하면 챕터 종료)* |
| window | 0.76,0.28,0.20,0.26 | — | say(strAtticWindow) |
오버레이: `attic_b_trunk_open.png`(0.36,0.54,0.34,0.28, when: organ_played==1)

**클로즈업 `embroidery`:** `attic_embroidery.png` — 자수 그림: **달 → 해 → 별 → 구름** (화살표로 순서 명시, 글자 없음). 관찰 전용.
**클로즈업 `organ` (커스텀 OrganKeys):** `attic_organ_close.png` 위에 건반 4개 GestureDetector(key: Key('organ_key_1')..4, rect 가로 4등분 하단 40%). 탭 시 tapOrganKey + sfx('note1'~'note4' — 음별 효과음, 없으면 무음 폴백). 리셋되면 sfx('locked')+say(strAtticOrganWrong), 완료 순간 sfx('unlock')+say(strAtticOrganPlayed).

**onEnter:** say(strAtticIntro). **cleared:** attic_done>=1.

**strings.dart 추가 (전문) + 교체:**
```dart
// ── 다락방 (room6_attic) ──
const strAtticIntro = '"드디어 여기까지 왔군." 고스포가 트렁크 앞을 지키고 서 있다. "마지막 시험이다. 삼촌의 오르간은… 올바른 노래에만 답하지."';
const strAtticGhospoHint = '"카드는 보면대에, 순서는… 저 낡은 자수가 알고 있다. 나? 난 음치라서 모른다."';
const strAtticGhospoProud = '"그 노래… 주인님이 생전에 흥얼거리던 곡이야." 고스포가 눈시울(?)을 훔친다.';
const strAtticStandEmpty = '오르간 보면대. 음표 카드를 놓는 홈이 네 개 파여 있다.';
const strAtticCardPlaced = '카드를 보면대에 놓았다.';
const strAtticCardsAll = '네 장이 모두 모였다! 악보가 완성됐다 — 달, 별, 해, 구름이 각각 도·레·미·파로 빛난다.';
const strAtticStandFull = '악보 완성. 이제 연주만 남았다.';
const strAtticOrganNoCards = '건반을 눌러도 먹먹한 소리뿐이다. 보면대에 악보(음표 카드)가 있어야 할 것 같다.';
const strAtticOrganWrong = '삐끗! 오르간이 불쾌한 화음을 낸다. 처음부터 다시.';
const strAtticOrganPlayed = '웅장한 화음이 다락을 가득 채운다…! 트렁크의 자물쇠가 저절로 풀렸다.';
const strAtticTrunkLocked = '삼촌의 트렁크. 자물쇠에 열쇠 구멍이 없다. 음표 문양만 새겨져 있다.';
const strAtticWill = '유언장을 찾았다! "축하한다, 조카야. 시험을 통과했으니 저택은 네 것이다. 참, 말 안 했던가? 나도 300년 전부터 유령이란다. 앞으로 잘 부탁한다 — 2층에서 만나자꾸나. ― 삼촌" …잠깐, 뭐라고요?';
const strAtticWindow = '둥근 창으로 달빛이 쏟아진다. 마당의 허수아비가 손을 흔든… 기분 탓이겠지.';
```
`strChapterEnd`를 다음으로 **교체**: `'챕터 1 클리어!\n삼촌(유령)의 저택은 이제 당신 것.\n…2층의 이야기는 다음 챕터에서.'`

**힌트:** `p_attic_cards` '오르간과 카드'(①여정에서 모은 음표 카드 네 장이 필요해요. 보면대에 놓으세요 ②카드를 하나씩 선택해 보면대를 탭 — 네 장 전부 ③정답: ♪달·♪별·♪해·♪구름 카드를 모두 보면대에. solved: cards_placed>=4), `p_attic_order` '연주 순서'(①순서는 이 방의 오래된 물건에 수놓아져 있어요 ②자수: 달→해→별→구름. 카드가 알려준 음 매핑과 합치면? ③정답: 도(달)→미(해)→레(별)→파(구름) — 건반 1·3·2·4 순서. solved: organ_played), `p_attic_trunk` '삼촌의 트렁크'(①이 트렁크엔 열쇠 구멍이 없어요. 음악으로 여는 자물쇠 ②오르간을 올바로 연주하면 열려요 ③정답: 연주 성공 후 트렁크를 탭 — 유언장을 읽고 한 번 더 탭하면 탈출. solved: attic_done)

**테스트:** solveAttic 전제: note1~4 보유(주석 명시, 단독 테스트 setUp에서 give×4). 시퀀스: 카드 4장 배치(각각 select→music_stand)→embroidery 탭+클로즈업 확인→organ 탭+클로즈업 확인→tapOrganKey 1,3,2,4→organ_played→trunk(유언장)→trunk(종료). 부정: ①카드 3장에서 organ → 클로즈업 안 열림 ②tapOrganKey 카드 미완이면 no-op ③틀린 연주(1,2)→리셋 ④organ_played 전 trunk → locked. 단위: tapOrganKey 진행·리셋·게이트. 위젯: OrganKeys 4키 순서 탭 → organ_played.

- [ ] Step 1: 테스트+solveAttic → RED
- [ ] Step 2: 구현(+strChapterEnd 교체 — app_shell_test의 엔딩 문구 기대값도 상수 참조라 수정 불필요임을 확인) → GREEN
- [ ] Step 3: art/room6-assets.md (씬 2, 클로즈업 2, 오버레이 2, 신규 아이템 0)
- [ ] Step 4: analyze + 전체 green
- [ ] Step 5: Commit — "방 6 다락방: 음표 오르간 연주 + 삼촌 유령 반전 엔딩"

---

### Task 7: 챕터 통합 테스트 + 릴리스 검증 + README 갱신

**Files:**
- Create: `test/chapter1_integration_test.dart`
- Modify: `README.md`
- Test: 통합 테스트 자체

**Interfaces — Consumes:** `buildAllRooms()`(이 시점에 6개), `test/solutions.dart`의 solve 6종

- [ ] **Step 1: 통합 테스트 작성** — 하나의 GameState/GameCtx로 6개 방을 순서대로: 각 방마다 `final room = rooms[i]; solveXxx(s, c, room); expect(room.cleared(s), isTrue); s.goRoom(i+1);`. 경계 검증: 서재 시작 전 `expect(s.has('oil'), isTrue)`, 다락 시작 전 `expect(s.has('note1')&&…note4, isTrue)`. 마지막에 attic_done 확인. **이 테스트가 교차 아이템 흐름(챕터 무결성)의 유일한 전체 증명이다.**
- [ ] **Step 2: RED→GREEN 확인** (이미 전부 구현돼 있으므로 바로 green이어야 정상 — 실패하면 방 간 아이템 배선 버그이니 STOP 후 보고)
- [ ] **Step 3: 전체 게이트** — analyze "No issues found!", 전체 스위트 green
- [ ] **Step 4: 릴리스 빌드** — `.\tool\f.cmd build apk --release` (600000ms). 마이그레이터 상태 확인: **이 계획 시작 전에 마이그레이터 출력이 커밋되어 있으므로 빌드 후 `git status --porcelain`이 비어 있어야 한다.** 비어 있지 않으면 무엇이 바뀌었는지 보고(커밋 금지).
- [ ] **Step 5: README 갱신** — "남은 일" 섹션을 현행화: 방 2~6 완료 반영, 남은 일 = 방 2~6 아트/효과음 도착 시 좌표 미세조정, 출시 단계(실 AdMob ID·서명 키·스토어 등록·런처 이름), iOS. 아트 의뢰서 목록에 room2~6-assets.md 추가.
- [ ] **Step 6: Commit** — "챕터 1 통합: 6방 연속 클리어 테스트 + 릴리스 검증 + README"

---

## 계획 밖 (후속)

- 실기기 챕터 1 완주 (수용 기준 — 사용자 요청 시 빌드·설치)
- 아트·효과음 도착 후 좌표·연출 미세조정 패스
- 출시 계획: 실제 AdMob ID, 서명 키, 스토어 리스팅, 데이터 보안 신고, 런처 이름/아이콘
- 챕터 2 (별도 브레인스토밍)
