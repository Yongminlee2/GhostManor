# 아키텍처

이 문서는 엔진의 설계 원칙과 구조를 설명한다. 이 문서와 [ROOMS.md](ROOMS.md),
[HANDOVER.md](HANDOVER.md)를 읽으면 사전 지식 없이 방 추가·기능 확장을 이어갈 수 있다.

## 설계 원칙

1. **상태는 하나** — 게임의 모든 진행 상태는 `GameState` 하나에 산다
   (플래그 `Map<String,int>` + 인벤토리 `List<String>` + 현재 위치).
   UI는 이 객체에만 반응한다(`ChangeNotifier` + `AnimatedBuilder`).
2. **방은 선언, 기믹은 탈출구** — 방은 데이터처럼 선언하고(핫스팟 좌표·조건·액션),
   선언으로 표현이 안 되는 특수 기믹만 그 방 파일 안의 커스텀 위젯으로 쓴다.
   범용 JSON 엔진을 만들지 않은 것은 의도적 결정이다: 기믹 다양성이 스키마에
   갇히는 것을 막고, 방 6개 규모에 과한 추상화를 피했다.
3. **로직은 위젯 밖으로** — 퍼즐 진행 판정(`toggleCandle`, `tapBook`,
   `tapOrganKey` 등)은 `GameState`만 받는 순수 함수다. 위젯은 이 함수를 호출하고
   연출(sfx·대사)만 얹는다. 덕분에 방 클리어 가능성을 위젯 없이 테스트한다.
4. **에셋이 없어도 완전 동작** — 이미지는 `errorBuilder`로 파일명 라벨 블록,
   오디오는 무음 폴백. 아트/사운드 제작과 코드 개발이 완전히 분리된다.

## 핵심 모델 (lib/core/models.dart)

| 타입 | 역할 |
|---|---|
| `GameState` | 플래그·인벤토리·현재 방/벽면/클로즈업/대사. 모든 변이는 메서드 경유(notify) |
| `Room` | id, 이름, 벽면 목록, 클로즈업 맵, 힌트 목록, 클리어 조건, onEnter |
| `Scene` | 벽면 또는 클로즈업: 이미지 + 오버레이 + 핫스팟, 또는 `custom` 위젯(전체 위임) |
| `Hotspot` | 비율 좌표 사각형(0~1) + 표시 조건(`when`) + `onTap(GameCtx)` |
| `SceneOverlay` | 조건부로 겹쳐지는 부분 이미지 (상태 변화 표현) |
| `PuzzleHint` | 퍼즐별 3단계 힌트(방향→구체→정답) + 해결 판정 |
| `GameCtx` | onTap이 받는 실행 컨텍스트: say/sfx/give/consume/using/openCloseup… BuildContext 불필요 |

생성자 assert가 규칙을 강제한다: 핫스팟 폭 ≥ 0.08(픽셀 헌팅 금지),
힌트는 정확히 3단계, 클로즈업 맵의 key == Scene.id.

## 데이터 흐름

```
탭 → SceneView 히트테스트 → Hotspot.onTap(GameCtx)
  → GameState 변이(notifyListeners)
  → UI 리빌드(AnimatedBuilder) + 자동 저장(SaveService, 0.5s 디바운스)
```

## 히트테스트와 z순서 (중요)

`SceneView`는 `hotspots.reversed`로 순회해 **뒤에 선언한 핫스팟이 탭을 우선**한다.

> **규칙: 큰 배경·풍미용 rect는 목록 앞쪽에, 작은 상호작용 rect는 뒤쪽에 선언한다.**

이 규칙을 어기면 큰 rect가 작은 rect를 가려 "보이는데 탭이 안 되는" 결함이
생긴다(테스트가 id로 직접 호출하면 못 잡는다). `test/hotspot_resolution_test.dart`가
모든 방·모든 벽면에서 각 핫스팟 중심점이 자기 자신으로 해상되는지 검사하는
회귀망이다. 의도적 가림(예: 거실 문을 막는 부우)은 그 테스트의 예외 맵에
주석과 함께 등록한다.

## 커스텀 기믹 위젯 패턴

`Scene(custom: (context, ctx) => MyGimmick(ctx: ctx))` — custom이 지정되면
이미지·핫스팟 렌더를 전부 위임받는다. 기존 구현 5종이 패턴의 표본이다:

| 위젯 | 방 | 패턴 포인트 |
|---|---|---|
| `RubbableScene` (core 공용) | 현관 액자, 서재 종이 | pan 누적으로 덮개 제거, `_done` 원샷 가드 |
| `ClockCloseup` | 현관 | 탭마다 순수 함수 호출, 완성 순간만 연출(라이브 플래그 비교) |
| `BarrelDrag` | 지하실 | pan 누적 → 진행도 정수 플래그, 완료 후 pan 무시 |
| `ShelfShake` | 지하실 | 센서 스트림 구독(initState try/catch, dispose 해제) + 연타 폴백 |
| `OrganKeys` | 다락방 | 4분할 키 존, 순서 판정은 순수 함수, 오답 리셋 연출 |

공통 원칙: **원샷 연출 가드는 위젯 필드가 아니라 라이브 플래그의 전/후 비교로**
(같은 제스처의 다중 이벤트가 리빌드 전에 몰려도 이중 발화하지 않는다).

## 세이브 (lib/core/save_service.dart)

- 저장 대상: 플래그 전체 + 인벤토리 + 선택 아이템 + 방/벽면 인덱스
  (클로즈업·대사는 일시 상태라 제외).
- 쓰기 전 직전본을 백업 슬롯에 보존 → 본 저장 파손 시 백업으로 복구.
- `attach(state)`가 0.5초 디바운스 자동 저장, `dispose()`가 대기 타이머 취소.

## 앱 셸과 클리어 흐름 (lib/main.dart)

- `RoomScreen`: 상단바(방 이름·힌트·설정) + 2:3 `SceneView` + 하단 인벤토리.
- 첫 진입 시 `entered_<roomId>` 플래그 + `Room.onEnter`(인트로 대사).
- 방 진입 시 그 방 이미지 프리로드(에러 무시).
- **클리어 흐름의 불변식**: 방 전진은 클리어 다이얼로그가 *어떤 방식으로든 닫힌 뒤*
  실행된다(버튼은 pop만). 뒤로가기 dismiss나 프로세스 사망으로도 갇히지 않도록,
  시작 시 `_selfHealStrandedClear()`가 "클리어됐지만 전진 못 한" 저장을 감지해
  자동 전진한다. 마지막 방 여부는 저장 플래그에서 파생되는 `_ended` getter로
  판정한다(위젯 필드에 두지 않는다 — 재개 시에도 옳아야 하므로).

## 힌트와 광고 (lib/core/hint_service.dart, ads.dart)

- 힌트 해금 단계는 `hint_<puzzleId>` 플래그(0~3)로 저장돼 세이브와 함께 유지.
- 1단계 무료, 2·3단계는 보상형 광고. 광고 로드 실패 누적 3회면 무료 지급 후
  카운터 리셋 — 오프라인 유저를 광고에 가두지 않는다.
- 광고 유닛은 현재 공식 테스트 ID. 실ID 전환 위치는 [HANDOVER.md](HANDOVER.md) 참조.

## 방 추가 레시피

1. `lib/rooms/roomN_<이름>.dart` 생성 — 기존 방(특히 room2, room5)을 표본으로.
2. **플래그·퍼즐 id는 방 접두어로 전역 유일하게** (`cellar_got_key`, `p_cellar_key`).
   세이브가 방 사이에 공유되므로 접두어 없는 플래그는 다른 방을 오염시킨다.
3. 핫스팟 목록은 z순서 규칙대로(큰 rect 먼저). 클로즈업 맵 key == Scene.id.
4. 대사·힌트 텍스트는 전부 `lib/core/strings.dart` 상수로.
5. 아이템은 `lib/rooms/items.dart` 레지스트리에 등록(조합은 정렬 키 규칙).
6. `lib/rooms/rooms.dart` 목록에 한 줄 추가.
7. `test/solutions.dart`에 `solveXxx` 정답 시퀀스 추가(클로즈업은 구체 id로 단언),
   `test/roomN_..._test.dart`에 부정 테스트(잠금 우회 불가 등)·순수 함수 단위·
   커스텀 위젯 배선 테스트. 힌트 테스트는 각 solved 조건을 실제로 호출할 것.
8. `test/chapter1_integration_test.dart`(또는 챕터별 통합 테스트)에 연결.
9. `art/roomN-assets.md` 의뢰 문서 작성 — 코드의 rect 값을 표로 그대로.
10. `.\tool\f.cmd analyze` 무결점 + 전체 테스트 green 확인 후 커밋.
