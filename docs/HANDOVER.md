# 인수인계 가이드

이 문서만 읽으면 이 저장소를 처음 보는 사람(또는 어떤 개발 도구)도 안전하게
이어서 개발할 수 있도록 쓴다. 아키텍처는 [ARCHITECTURE.md](ARCHITECTURE.md),
퍼즐 내용은 [ROOMS.md](ROOMS.md), 결정의 배경은 [DEVLOG.md](DEVLOG.md) 참조.

## 1. 환경 — 반드시 지킬 것

| 항목 | 내용 |
|---|---|
| Flutter | 3.44.x / Dart 3.12 (개발 머신 기준 `C:\flutter`, PATH 미등록) |
| 실행 | **모든 flutter 명령은 `.\tool\f.cmd <args>`로** — PUB_CACHE/GRADLE_USER_HOME/TEMP를 ASCII 경로로 고정하는 래퍼. 다른 머신에서는 래퍼 안의 경로만 환경에 맞게 수정 |
| 왜? | 사용자 홈이 비ASCII(한글)인 Windows에서 ①`flutter test`가 temp 경로 문제로 0xC0000409 즉사 ②gradle 캐시 경로 문제가 발생한다. 래퍼가 전부 우회 |
| Gradle/AGP | **Gradle 8.14 + AGP 8.12.0 고정** — `google_mobile_ads`가 Gradle 9와 비호환(업스트림). 9로 올리기 전에 광고 SDK 호환을 반드시 확인 |
| minSdk 등 | gradle 설정 일부는 Flutter 도구가 빌드마다 재작성한다. **커밋된 상태 = 도구 출력** — 빌드 후 `git status`가 깨끗해야 정상. 더러우면 도구 버전이 바뀐 것이니 새 출력을 검토 후 커밋 |
| 파일 편집 | 한글 포함 파일을 PowerShell `Get-Content \| Set-Content` 파이프로 수정하면 인코딩이 깨진다 — 에디터/전용 도구로만 |

## 2. 하지 말 것

- 핫스팟 목록 순서를 의미 없이 바꾸지 말 것 — **뒤에 선언한 핫스팟이 탭 우선**.
  큰 rect를 뒤로 보내면 작은 rect가 가려진다. 순서를 바꿨다면
  `test/hotspot_resolution_test.dart`가 잡아준다(예외는 주석과 함께 예외 맵에).
- 방 플래그에 접두어를 빼먹지 말 것 (`cellar_...`) — 세이브 맵이 전역 공유라
  이름 충돌은 다른 방을 미리 풀어버린다.
- `pubspec.yaml`에 의존성을 함부로 늘리지 말 것 — 현재 4개가 전부이며 의도적이다.
- 클리어 전진 로직을 다이얼로그 버튼 안으로 되돌리지 말 것 — 뒤로가기 dismiss
  소프트락의 원인이었다(main.dart의 주석과 DEVLOG §7 참조).

## 3. 남은 작업 체크리스트

### 3-1. 콘텐츠 마감
- [ ] **방 4~6 아트 반영** — `art/room4-assets.md`·`room5`·`room6` 의뢰서대로
  이미지를 생성해 `assets/` 경로에 파일명 그대로 저장. 검수 포인트:
  규격(씬 1024×1536·클로즈업 1024²·아이템 512² 투명), 오버레이 크롭이 표의
  좌표와 일치, **퍼즐 정답 그림의 정확성**(자수 달→해→별→구름, 오르간 건반
  하단 40% 4등분, 지하실 어둠막은 반투명·야광은 형광 초록), 이미지에 글자 금지.
  반영 후 실행해서 좌표가 그림과 안 맞으면 코드 rect를 그림에 맞춰 조정
  (서재 조정 이력이 선례 — `art/room3-assets.md` 상단 주석).
- [ ] **효과음 13종** — CC0 음원을 mp3로 `assets/audio/`에:
  `pickup, combine, unlock, locked, door_open, clock_tick, sparkle, ghost_giggle,
  bgm_manor(루프), note1, note2, note3, note4(도레미파)`.
  없어도 게임은 무음으로 동작하므로 급하지 않다.

### 3-2. 검증
- [ ] **실기기 챕터 1 완주** — 최종 수용 기준. 특히 확인:
  지하실 흔들기(실센서), 힌트 광고 흐름, 각 방 핫스팟 체감 좌표,
  클리어 다이얼로그 뒤로가기 후 정상 전진, 중간 종료 후 이어하기.
- [ ] 완주 중 발견된 좌표·연출 이슈 반영 패스.

### 3-3. 출시 (Google Play)
- [ ] **광고 실ID 전환** — 현재 전부 공식 테스트 ID. 교체 위치 3곳:
  `lib/core/ads.dart`(보상형 유닛), `android/app/src/main/AndroidManifest.xml`
  (APPLICATION_ID 메타데이터), `ios/Runner/Info.plist`(GADApplicationIdentifier).
- [ ] 런처 이름·아이콘 — 현재 템플릿 기본값("ghostmanor"). manifest `android:label`
  + 아이콘 리소스 교체.
- [ ] 서명 키 생성·`key.properties` 연결 (현재 릴리스 빌드는 debug 서명).
- [ ] 스토어 등록 — 스크린샷, 설명, 데이터 보안 신고(광고 SDK 기재).
- [ ] 버전 관리 — pubspec `version` 올리기.

### 3-4. iOS (준비됨, 미착수)
- Xcode 환경에서 빌드만 하면 되는 상태를 유지 중 (순수 Flutter + 공식 플러그인,
  Info.plist에 광고 테스트 ID·세로 고정 반영됨). Apple 개발자 계정 + 실기기 필요.

### 3-5. 챕터 2 (설계부터)
- 방 추가 절차는 ARCHITECTURE.md의 레시피 10단계.
- 챕터 전환 구조(챕터 선택 화면 등)는 미구현 — 현재 `buildAllRooms()` 단일 목록.

## 4. 알려진 유예 항목 (의도된 상태)

수정하면 좋지만 급하지 않은, 인지된 상태로 남긴 것들:

- 다락방 트렁크 최종 탭에 전용 효과음 없음(직후 클리어 연출이 대신함) — 폴리시 후보.
- 오르간 첫 탭부터 틀릴 때 오답 연출 없음(진행 0→0은 리셋이 아님) — 자유 연주
  느낌을 위한 의도된 설계로 결론.
- 방 2~4의 힌트 배선 테스트는 solved 조건 호출을 생략(방 5·6 스타일이 더 강함) —
  테스트 보강 기회.
- `FrameCloseup`(room1)은 `RubbableScene`의 얇은 래퍼로 존치 — room1 테스트가
  직접 인스턴스화하기 때문. room1 테스트를 손볼 일이 생기면 함께 제거 가능.
- 지하실 선반 클로즈업은 어둠 상태에서도 열리며 무반응(공정성 문제는 없음) —
  아트/폴리시 패스에서 재검토.

## 5. 빠른 자가진단

이어받은 직후 이 세 줄이 전부 통과하면 환경이 정상이다:

```bash
.\tool\f.cmd analyze
```

```bash
.\tool\f.cmd test
```

```bash
.\tool\f.cmd build apk --release
```

기대값: 이슈 0 / 112개 전부 통과 / `app-release.apk` 생성 + `git status` 깨끗.
