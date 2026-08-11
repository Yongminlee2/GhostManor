# GhostManor v1 수직 슬라이스 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 방탈출 게임 「기묘한 유령 저택」의 플레이 가능한 수직 슬라이스 — 코어 엔진 전체 + 현관(튜토리얼) 방 + 타이틀/설정/힌트/광고 — 를 완성한다.

**Architecture:** 하이브리드 — 공통 코어(GameState 플래그 상태머신, 자동 세이브, SceneView 핫스팟 렌더, 인벤토리/조합, 3단계 힌트+광고 게이트)를 한 번 만들고, 방은 Dart 파일 하나가 `Room` 객체를 선언형으로 리턴한다. 특수 기믹은 방 파일 안 커스텀 위젯(escape hatch). UI는 GameState에만 반응하는 순수 리액티브 구조라 방 로직은 위젯 없이 헤드리스로 테스트된다.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12, shared_preferences, audioplayers, google_mobile_ads. 상태관리 라이브러리 없음(ChangeNotifier).

**스펙:** `docs/superpowers/specs/2026-08-12-ghost-manor-escape-design.md`
**범위:** 이 계획은 스펙의 §4(아키텍처)·§6(힌트)·§7(에러)·§8(테스트) 전부와 §3의 방 1(현관)을 구현한다. 방 2~6은 이 슬라이스 검증 후 방마다 별도 콘텐츠 계획(스펙 §5.3의 방 단위 제작 원칙). `sensors_plus`(흔들기)는 방 5 계획에서 추가한다.

## Global Constraints

- **Flutter는 PATH에 없다.** 모든 flutter 명령은 반드시 `tool\f.cmd` 경유 (Task 1에서 생성; `C:\flutter\bin\flutter.bat` + ASCII 환경변수 설정).
- **ASCII 경로 강제** (한글 사용자명 머신): `PUB_CACHE=C:\flutter\.pub-cache`, `GRADLE_USER_HOME=C:\workAndroid\gradle-home-ascii`, `TEMP`/`TMP=C:\workAndroid\tmp-ascii`.
  - `C:\workAndroid\gradle-user-ascii`는 한글 홈으로 가는 정션이므로 **절대 사용 금지**.
  - TEMP 미설정 시 flutter test가 0xC0000409로 즉사하며 "Connection closed before test suite loaded"만 보인다.
- **한글 포함 파일은 PowerShell `Get-Content|Set-Content` 파이프 금지** (인코딩 파손 전례) — 파일 수정은 Edit/Write 도구로만.
- 의존성은 `shared_preferences`, `audioplayers`, `google_mobile_ads` 3개만. 추가 금지.
- `applicationId=com.yongmin.ghostmanor`, minSdk 23, 세로(portrait) 고정.
- 광고는 AdMob **공식 테스트 ID만** 사용 (앱: `ca-app-pub-3940256099942544~3347511713`, 보상형: `ca-app-pub-3940256099942544/5224354917`). 실제 ID 교체는 출시 단계(이 계획 밖).
- 에셋은 pubspec 디렉터리 선언 + 코드에 정확한 경로 문자열. 동적 리소스 참조(getIdentifier류) 금지.
- **이미지·오디오 파일이 없어도 앱은 완전 동작해야 한다** — 이미지는 파일명 라벨 색 블록(errorBuilder), 오디오는 무음 폴백. 아트는 사용자가 Codex로 병렬 공급.
- 모든 유저 노출 텍스트는 `lib/core/strings.dart` 상수로만 (영어판 대비 단일 지점, 스펙 §4.2).
- 커밋 메시지는 한국어, 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- 작업 디렉터리: `C:\workAndroid\GhostManor` (모든 Run 명령은 여기 기준).

---

### Task 1: Flutter 프로젝트 생성 + ASCII 빌드 환경 배선

**Files:**
- Create: `tool/f.cmd`
- Create: `flutter create`가 생성하는 표준 트리 (`lib/main.dart`, `pubspec.yaml`, `android/`, `ios/` 등)
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `android/gradle.properties`, `ios/Runner/Info.plist`, `lib/main.dart`
- Create: `assets/scenes/.gitkeep`, `assets/items/.gitkeep`, `assets/audio/.gitkeep`
- Delete: `test/widget_test.dart` (템플릿 카운터 테스트)

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `tool\f.cmd <args>` — 이후 모든 태스크의 flutter 실행 수단. 앱 골격(세로 고정, 광고 메타데이터, 에셋 폴더 3개 등록).

- [ ] **Step 1: flutter 래퍼 스크립트 작성**

`tool/f.cmd`:

```bat
@echo off
rem ASCII 경로 강제 (한글 사용자명 머신) — TEMP은 flutter test 필수
set PUB_CACHE=C:\flutter\.pub-cache
set GRADLE_USER_HOME=C:\workAndroid\gradle-home-ascii
set TEMP=C:\workAndroid\tmp-ascii
set TMP=C:\workAndroid\tmp-ascii
C:\flutter\bin\flutter.bat %*
```

- [ ] **Step 2: 프로젝트 생성**

Run: `.\tool\f.cmd create --org com.yongmin --project-name ghostmanor --platforms android,ios .`
Expected: "All done!" — 기존 `docs/`, `.git/`, `tool/`은 유지된 채 표준 트리 생성. `test/widget_test.dart`는 삭제한다.

- [ ] **Step 3: pubspec 의존성·에셋 등록**

`pubspec.yaml`의 `dependencies:`와 `flutter:` 섹션을 다음으로 교체(나머지는 유지):

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.3.0
  audioplayers: ^6.0.0
  google_mobile_ads: ^5.2.0

flutter:
  uses-material-design: true
  assets:
    - assets/scenes/
    - assets/items/
    - assets/audio/
```

`assets/scenes/`, `assets/items/`, `assets/audio/` 폴더를 만들고 각각 빈 `.gitkeep` 파일을 넣는다.

- [ ] **Step 4: 안드로이드 설정**

`android/app/src/main/AndroidManifest.xml` — `<activity>`에 `android:screenOrientation="portrait"` 속성 추가, `<application>` 안에 AdMob 테스트 앱 ID 메타데이터 추가:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

`android/app/build.gradle.kts` — `defaultConfig` 블록에서 `minSdk = flutter.minSdkVersion`을 `minSdk = 23`으로 교체 (google_mobile_ads 요구).

`android/gradle.properties` 끝에 추가 (삐약푸시와 동일 관례):

```properties
# 한글 사용자 홈 회피: JDK를 ASCII 경로로 고정
org.gradle.java.home=C:/Program Files/Android/Android Studio/jbr
```

- [ ] **Step 5: iOS 설정 (빌드는 안 하지만 호환 유지 — 스펙 §9)**

`ios/Runner/Info.plist`의 최상위 `<dict>`에 추가:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~3347511713</string>
```

같은 파일의 `UISupportedInterfaceOrientations` 배열을 `UIInterfaceOrientationPortrait` 하나만 남긴다 (iPad용 `~ipad` 키도 동일하게).

- [ ] **Step 6: main.dart 스텁 (세로 고정 + 다크 테마)**

`lib/main.dart` 전체 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GhostManorApp());
}

class GhostManorApp extends StatelessWidget {
  const GhostManorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '기묘한 유령 저택',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B3E96), brightness: Brightness.dark),
      ),
      home: const Scaffold(body: Center(child: Text('기묘한 유령 저택'))),
    );
  }
}
```

- [ ] **Step 7: 정적 분석·빌드 확인**

Run: `.\tool\f.cmd pub get` → Expected: 의존성 해석 성공.
Run: `.\tool\f.cmd analyze` → Expected: "No issues found!"
Run: `.\tool\f.cmd build apk --debug` → Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`. (여기서 실패하면 Global Constraints의 ASCII 경로부터 의심.)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "프로젝트 생성: Flutter 골격 + ASCII 빌드 환경 + 세로 고정 + 광고 테스트 ID"
```

---

### Task 2: GameState — 플래그·인벤토리 상태머신

**Files:**
- Create: `lib/core/game_state.dart`
- Test: `test/game_state_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `class GameState extends ChangeNotifier` — 필드 `Map<String,int> flags`, `List<String> inventory`, `String? selectedItem`, `int roomIndex`, `int sceneIndex`, `String? closeupId`, `String? dialog`. 메서드 `int flag(String)`, `void setFlag(String,int)`, `void addFlag(String,[int])`, `bool has(String)`, `void give(String)`, `void take(String)`, `void select(String?)`, `void say(String?)`, `void openCloseup(String)`, `void closeCloseup()`, `void goScene(int)`, `void goRoom(int)`, `Map<String,dynamic> toJson()`, `static GameState fromJson(Map<String,dynamic>)`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/game_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';

void main() {
  test('플래그: 기본 0, set/add, 변경 시 notify', () {
    final s = GameState();
    var notified = 0;
    s.addListener(() => notified++);
    expect(s.flag('x'), 0);
    s.setFlag('x', 2);
    s.addFlag('x');
    expect(s.flag('x'), 3);
    expect(notified, 2);
  });

  test('인벤토리: give/take/has, take는 선택 해제', () {
    final s = GameState();
    s.give('candle');
    expect(s.has('candle'), isTrue);
    s.select('candle');
    s.take('candle');
    expect(s.has('candle'), isFalse);
    expect(s.selectedItem, isNull);
  });

  test('내비게이션: goScene은 클로즈업 닫음, goRoom은 위치·대사 리셋', () {
    final s = GameState();
    s.openCloseup('drawer');
    s.goScene(1);
    expect(s.closeupId, isNull);
    expect(s.sceneIndex, 1);
    s.say('안녕');
    s.goRoom(2);
    expect(s.roomIndex, 2);
    expect(s.sceneIndex, 0);
    expect(s.dialog, isNull);
  });

  test('JSON 라운드트립 (일시 상태 closeup/dialog는 저장 제외)', () {
    final s = GameState();
    s.setFlag('got_key', 1);
    s.give('match');
    s.select('match');
    s.goRoom(1);
    s.goScene(2);
    final r = GameState.fromJson(s.toJson());
    expect(r.flag('got_key'), 1);
    expect(r.inventory, ['match']);
    expect(r.selectedItem, 'match');
    expect(r.roomIndex, 1);
    expect(r.sceneIndex, 2);
    expect(r.closeupId, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/game_state_test.dart`
Expected: FAIL — `game_state.dart` 없음 (URI 에러).

- [ ] **Step 3: 구현**

`lib/core/game_state.dart`:

```dart
import 'package:flutter/foundation.dart';

/// 게임의 유일한 상태. UI는 이 객체에만 반응한다 (스펙 §4.4).
class GameState extends ChangeNotifier {
  Map<String, int> flags = {};
  List<String> inventory = [];
  String? selectedItem;
  int roomIndex = 0;
  int sceneIndex = 0;
  String? closeupId; // 일시 상태 — 저장 안 함
  String? dialog; // 일시 상태 — 저장 안 함

  int flag(String key) => flags[key] ?? 0;

  void setFlag(String key, int value) {
    flags[key] = value;
    notifyListeners();
  }

  void addFlag(String key, [int delta = 1]) => setFlag(key, flag(key) + delta);

  bool has(String itemId) => inventory.contains(itemId);

  void give(String itemId) {
    inventory.add(itemId);
    notifyListeners();
  }

  void take(String itemId) {
    inventory.remove(itemId);
    if (selectedItem == itemId) selectedItem = null;
    notifyListeners();
  }

  void select(String? itemId) {
    selectedItem = itemId;
    notifyListeners();
  }

  void say(String? text) {
    dialog = text;
    notifyListeners();
  }

  void openCloseup(String id) {
    closeupId = id;
    notifyListeners();
  }

  void closeCloseup() {
    closeupId = null;
    notifyListeners();
  }

  void goScene(int index) {
    sceneIndex = index;
    closeupId = null;
    notifyListeners();
  }

  void goRoom(int index) {
    roomIndex = index;
    sceneIndex = 0;
    closeupId = null;
    dialog = null;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'flags': flags,
        'inventory': inventory,
        'selectedItem': selectedItem,
        'roomIndex': roomIndex,
        'sceneIndex': sceneIndex,
      };

  static GameState fromJson(Map<String, dynamic> json) {
    final s = GameState();
    s.flags = Map<String, int>.from(json['flags'] as Map);
    s.inventory = List<String>.from(json['inventory'] as List);
    s.selectedItem = json['selectedItem'] as String?;
    s.roomIndex = json['roomIndex'] as int;
    s.sceneIndex = json['sceneIndex'] as int;
    return s;
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `.\tool\f.cmd test test/game_state_test.dart`
Expected: All tests passed (4개).

- [ ] **Step 5: Commit**

```bash
git add lib/core/game_state.dart test/game_state_test.dart
git commit -m "코어: GameState 플래그·인벤토리 상태머신 + JSON 직렬화"
```

---

### Task 3: 아이템 레지스트리 + 조합 테이블

**Files:**
- Create: `lib/rooms/items.dart`
- Test: `test/items_test.dart`

**Interfaces:**
- Consumes: `GameState` (give/take/has)
- Produces: `class Item { String id; String name; String get icon; }`, `const Map<String, Item> itemsById`, `String? combineResult(String a, String b)`, `bool tryCombine(GameState s, String a, String b)` — 성공 시 재료 2개 제거·결과 지급 후 true.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/items_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/rooms/items.dart';

void main() {
  test('레지스트리: 아이콘 경로 규약', () {
    expect(itemsById['candle']!.icon, 'assets/items/candle.png');
    expect(itemsById['candle']!.name, '양초');
  });

  test('조합: 순서 무관, 없는 조합은 null', () {
    expect(combineResult('candle', 'match'), 'lit_candle');
    expect(combineResult('match', 'candle'), 'lit_candle');
    expect(combineResult('match', 'key_foyer'), isNull);
  });

  test('tryCombine: 재료 소모 + 결과 지급', () {
    final s = GameState();
    s.give('candle');
    s.give('match');
    expect(tryCombine(s, 'candle', 'match'), isTrue);
    expect(s.has('candle'), isFalse);
    expect(s.has('match'), isFalse);
    expect(s.has('lit_candle'), isTrue);
  });

  test('tryCombine 실패: 아무것도 변하지 않음', () {
    final s = GameState();
    s.give('candle');
    s.give('key_foyer');
    expect(tryCombine(s, 'candle', 'key_foyer'), isFalse);
    expect(s.inventory, ['candle', 'key_foyer']);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/items_test.dart`
Expected: FAIL — `items.dart` 없음.

- [ ] **Step 3: 구현**

`lib/rooms/items.dart`:

```dart
import '../core/game_state.dart';

class Item {
  final String id;
  final String name;
  const Item(this.id, this.name);
  String get icon => 'assets/items/$id.png';
}

/// 전 챕터 아이템 전역 레지스트리 (스펙 §4.3). 방 추가 시 여기에만 등록.
const Map<String, Item> itemsById = {
  'match': Item('match', '성냥'),
  'candle': Item('candle', '양초'),
  'lit_candle': Item('lit_candle', '불 켠 초'),
  'key_foyer': Item('key_foyer', '낡은 열쇠'),
};

/// 키 = 두 id를 사전순 정렬해 '+'로 연결.
const Map<String, String> _combineTable = {
  'candle+match': 'lit_candle',
};

String? combineResult(String a, String b) {
  final ids = [a, b]..sort();
  return _combineTable['${ids[0]}+${ids[1]}'];
}

/// 성공 시 재료 2개 제거 + 결과 지급 후 true (스펙 §4.3 전역 조합 규칙).
bool tryCombine(GameState s, String a, String b) {
  final result = combineResult(a, b);
  if (result == null) return false;
  s.take(a);
  s.take(b);
  s.give(result);
  return true;
}
```

- [ ] **Step 4: 통과 확인**

Run: `.\tool\f.cmd test test/items_test.dart`
Expected: All tests passed (4개).

- [ ] **Step 5: Commit**

```bash
git add lib/rooms/items.dart test/items_test.dart
git commit -m "코어: 아이템 레지스트리 + 전역 조합 테이블"
```

---

### Task 4: SaveService — 자동 저장 + 백업 슬롯

**Files:**
- Create: `lib/core/save_service.dart`
- Test: `test/save_service_test.dart`

**Interfaces:**
- Consumes: `GameState.toJson()/fromJson()`
- Produces: `class SaveService` — `Future<void> save(GameState s)`, `Future<GameState?> load()`, `Future<void> clear()`, `void attach(GameState s)` (0.5초 디바운스 자동 저장). 저장 키 `'save'`, 백업 키 `'save_bak'`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/save_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장→로드 라운드트립', () async {
    final svc = SaveService();
    final s = GameState()..setFlag('got_key', 1)..give('match');
    await svc.save(s);
    final r = await svc.load();
    expect(r!.flag('got_key'), 1);
    expect(r.has('match'), isTrue);
  });

  test('세이브 없으면 null', () async {
    expect(await SaveService().load(), isNull);
  });

  test('본 세이브 파손 시 백업 슬롯으로 복구 (스펙 §4.5)', () async {
    final svc = SaveService();
    final s = GameState()..setFlag('a', 1);
    await svc.save(s); // save=v1
    s.setFlag('a', 2);
    await svc.save(s); // bak=v1, save=v2
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SaveService.key, '{깨진 json');
    final r = await svc.load();
    expect(r!.flag('a'), 1); // 백업(v1)으로 복구
  });

  test('clear는 본·백업 모두 삭제', () async {
    final svc = SaveService();
    await svc.save(GameState());
    await svc.save(GameState());
    await svc.clear();
    expect(await svc.load(), isNull);
  });

  test('attach: 상태 변화 후 자동 저장돼 있음 (디바운스 0.5초)', () async {
    final svc = SaveService();
    final s = GameState();
    svc.attach(s);
    s.setFlag('x', 7);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final r = await svc.load();
    expect(r!.flag('x'), 7);
  });
}
```

디바운스의 정밀 타이밍(연속 변경 시 저장 1회)은 검증 가치 대비 비용이 커서 실시간 결과 검증 하나로 갈음한다.

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/save_service_test.dart`
Expected: FAIL — `save_service.dart` 없음.

- [ ] **Step 3: 구현**

`lib/core/save_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';

/// 자동 저장 + 백업 슬롯 (스펙 §4.5, §7).
class SaveService {
  static const key = 'save';
  static const bakKey = 'save_bak';
  Timer? _debounce;

  Future<void> save(GameState s) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(key);
    if (old != null) await prefs.setString(bakKey, old); // 직전본 백업
    await prefs.setString(key, jsonEncode(s.toJson()));
  }

  Future<GameState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [key, bakKey]) {
      final raw = prefs.getString(k);
      if (raw == null) continue;
      try {
        return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // 파손 → 다음 슬롯 시도
      }
    }
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(bakKey);
  }

  /// 상태 변화를 0.5초 디바운스로 자동 저장 (스펙 §4.4).
  void attach(GameState s) {
    s.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () => save(s));
    });
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `.\tool\f.cmd test test/save_service_test.dart`
Expected: All tests passed (5개).

- [ ] **Step 5: Commit**

```bash
git add lib/core/save_service.dart test/save_service_test.dart
git commit -m "코어: SaveService 자동 저장 + 백업 슬롯 복구"
```

---

### Task 5: 씬 모델 + GameCtx + AudioService

**Files:**
- Create: `lib/core/models.dart`, `lib/core/audio_service.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Consumes: `GameState`
- Produces:
  - `typedef Cond = bool Function(GameState s)`
  - `class AudioService { AudioService({bool enabled = true}); bool muted; Future<void> play(String name); Future<void> playBgm(String name); Future<void> setMuted(bool m); }` — 파일 없음/플러그인 없음이어도 절대 throw하지 않음. 테스트는 `AudioService(enabled: false)`.
  - `class GameCtx { GameCtx(GameState s, AudioService audio); GameState s; AudioService audio; void say(String)/sfx(String)/give(String)/consume(String)/openCloseup(String)/closeCloseup(); bool using(String); }`
  - `class Hotspot { String id; Rect area; Cond? when; void Function(GameCtx) onTap; }` — area는 비율 좌표(0~1), 생성자 assert로 `area.width >= 0.08` (픽셀 헌팅 금지, 스펙 §3.4).
  - `class SceneOverlay { String image; Rect area; Cond when; }`
  - `class Scene { String id; String? image; List<SceneOverlay> overlays; List<Hotspot> hotspots; Widget Function(BuildContext, GameCtx)? custom; }` — `custom` 지정 시 이미지·핫스팟 대신 전체 위임(escape hatch). assert: `custom != null || image != null`.
  - `class PuzzleHint { String puzzleId; String title; List<String> steps; Cond? solved; }` — steps는 정확히 3개.
  - `class Room { String id; String name; List<Scene> walls; Map<String, Scene> closeups; List<PuzzleHint> hints; Cond cleared; void Function(GameCtx)? onEnter; }`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/models_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';

void main() {
  GameCtx ctx(GameState s) => GameCtx(s, AudioService(enabled: false));

  test('GameCtx: give/consume/using/say/closeup이 상태에 반영', () {
    final s = GameState();
    final c = ctx(s);
    c.give('match');
    expect(s.has('match'), isTrue);
    s.select('match');
    expect(c.using('match'), isTrue);
    c.consume('match');
    expect(s.has('match'), isFalse);
    c.say('안녕');
    expect(s.dialog, '안녕');
    c.openCloseup('drawer');
    expect(s.closeupId, 'drawer');
    c.closeCloseup();
    expect(s.closeupId, isNull);
  });

  test('Hotspot: 최소 폭 8% 미만은 assert (픽셀 헌팅 금지)', () {
    expect(
        () => Hotspot(
            id: 'tiny',
            area: const Rect.fromLTWH(0, 0, 0.05, 0.5),
            onTap: (_) {}),
        throwsAssertionError);
  });

  test('AudioService: 비활성/음소거/에셋 없음 모두 안전', () async {
    final a = AudioService(enabled: false);
    await a.play('pickup'); // throw 없으면 통과
    await a.playBgm('bgm_manor');
    await a.setMuted(true);
    await a.play('pickup');
  });

  test('Scene: custom 없고 image도 없으면 assert', () {
    expect(() => Scene(id: 'x'), throwsAssertionError);
    expect(() => Scene(id: 'x', image: 'a.png'), returnsNormally);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/models_test.dart`
Expected: FAIL — models.dart / audio_service.dart 없음.

- [ ] **Step 3: AudioService 구현**

`lib/core/audio_service.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';

/// 소리 없어도 게임은 돈다 — 모든 실패는 무음 폴백 (스펙 §7 정신).
class AudioService {
  final bool enabled; // 테스트에서 false: 플러그인 자체를 건드리지 않음
  bool muted = false;
  AudioPlayer? _bgm;

  AudioService({this.enabled = true});

  Future<void> play(String name) async {
    if (!enabled || muted) return;
    try {
      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p.dispose());
      await p.play(AssetSource('audio/$name.mp3'));
    } catch (_) {/* 에셋 미도착·기기 문제 → 무음 진행 */}
  }

  Future<void> playBgm(String name) async {
    if (!enabled) return;
    try {
      _bgm ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _bgm!.play(AssetSource('audio/$name.mp3'));
      if (muted) await _bgm!.pause();
    } catch (_) {}
  }

  Future<void> setMuted(bool m) async {
    muted = m;
    try {
      if (m) {
        await _bgm?.pause();
      } else {
        await _bgm?.resume();
      }
    } catch (_) {}
  }
}
```

- [ ] **Step 4: 모델 + GameCtx 구현**

`lib/core/models.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'audio_service.dart';
import 'game_state.dart';

typedef Cond = bool Function(GameState s);

/// 핫스팟 onTap이 받는 실행 컨텍스트. BuildContext 불필요 →
/// 방 로직을 위젯 없이 헤드리스로 테스트할 수 있다 (스펙 §8).
class GameCtx {
  final GameState s;
  final AudioService audio;
  GameCtx(this.s, this.audio);

  void say(String text) => s.say(text);
  void sfx(String name) => audio.play(name);
  void give(String itemId) {
    s.give(itemId);
    audio.play('pickup');
  }

  bool using(String itemId) => s.selectedItem == itemId;
  void consume(String itemId) => s.take(itemId);
  void openCloseup(String id) => s.openCloseup(id);
  void closeCloseup() => s.closeCloseup();
}

class Hotspot {
  final String id;
  final Rect area; // 씬 이미지 대비 비율 좌표(0~1)
  final Cond? when; // null이면 항상 활성
  final void Function(GameCtx c) onTap;

  Hotspot({required this.id, required this.area, this.when, required this.onTap})
      : assert(area.width >= 0.08, '픽셀 헌팅 금지: 핫스팟 폭은 화면의 8% 이상 (스펙 §3.4)');
}

class SceneOverlay {
  final String image; // assets/scenes/...
  final Rect area; // 비율 좌표. 전체 덮기는 Rect.fromLTWH(0,0,1,1)
  final Cond when;
  const SceneOverlay({required this.image, required this.area, required this.when});
}

class Scene {
  final String id;
  final String? image; // assets/scenes/... (custom 씬은 생략 가능)
  final List<SceneOverlay> overlays;
  final List<Hotspot> hotspots;

  /// escape hatch: 지정 시 이미지·오버레이·핫스팟 대신 위젯에 전체 위임 (스펙 §4.3)
  final Widget Function(BuildContext context, GameCtx ctx)? custom;

  Scene({
    required this.id,
    this.image,
    this.overlays = const [],
    this.hotspots = const [],
    this.custom,
  }) : assert(custom != null || image != null, '씬은 image나 custom 중 하나 필수');
}

class PuzzleHint {
  final String puzzleId;
  final String title;
  final List<String> steps; // 방향→구체→정답
  final Cond? solved; // 풀린 퍼즐은 힌트 목록에 완료 표시
  PuzzleHint(
      {required this.puzzleId,
      required this.title,
      required this.steps,
      this.solved})
      : assert(steps.length == 3, '힌트는 정확히 3단계 (스펙 §6)');
}

class Room {
  final String id;
  final String name;
  final List<Scene> walls; // 좌우 화살표로 순환
  final Map<String, Scene> closeups;
  final List<PuzzleHint> hints;
  final Cond cleared; // 탈출 조건
  final void Function(GameCtx c)? onEnter; // 첫 진입 시 1회 (셸이 호출)

  Room({
    required this.id,
    required this.name,
    required this.walls,
    this.closeups = const {},
    this.hints = const [],
    required this.cleared,
    this.onEnter,
  });
}
```

- [ ] **Step 5: 통과 확인**

Run: `.\tool\f.cmd test test/models_test.dart`
Expected: All tests passed (4개).

- [ ] **Step 6: Commit**

```bash
git add lib/core/models.dart lib/core/audio_service.dart test/models_test.dart
git commit -m "코어: 씬/방 모델 + GameCtx + 무음 폴백 AudioService"
```

---

### Task 6: SceneView + InventoryBar 위젯

**Files:**
- Create: `lib/core/scene_view.dart`, `lib/core/inventory_bar.dart`
- Test: `test/scene_view_test.dart`

**Interfaces:**
- Consumes: `Room/Scene/Hotspot/SceneOverlay`, `GameCtx`, `GameState`, `itemsById`, `tryCombine`
- Produces:
  - `Widget gameImage(String path)` (scene_view.dart의 최상위 함수) — `Image.asset(fit: BoxFit.fill)` + errorBuilder(파일명 라벨 색 블록). 커스텀 기믹 위젯도 이걸 쓴다.
  - `class SceneView extends StatelessWidget { SceneView({required Room room, required GameCtx ctx}); }` — 현재 벽면/클로즈업 렌더, 비율 좌표 히트테스트(뒤에 선언된 핫스팟 우선), 조건부 오버레이, 좌우 화살표(`Key('arrow_left'/'arrow_right')`), 클로즈업 X버튼(`Key('closeup_close')`), 대사 말풍선(탭으로 닫힘).
  - `class InventoryBar extends StatelessWidget { InventoryBar({required GameCtx ctx}); }` — 슬롯 `Key('inv_<itemId>')`, 탭=선택/해제, 선택 중 다른 아이템 탭=조합 시도(성공 시 sfx('combine'), 실패 시 그 아이템으로 선택 이동).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/scene_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/inventory_bar.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/scene_view.dart';

Room _testRoom() => Room(
      id: 't',
      name: '테스트',
      cleared: (s) => false,
      walls: [
        Scene(id: 'a', image: 'assets/scenes/wall_a.png', overlays: [
          SceneOverlay(
              image: 'assets/scenes/ov.png',
              area: const Rect.fromLTWH(0, 0, 1, 1),
              when: (s) => s.flag('ov') == 1),
        ], hotspots: [
          Hotspot(
              id: 'big',
              area: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
              onTap: (c) => c.s.addFlag('tapped')),
          Hotspot(
              id: 'gated',
              area: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
              when: (s) => s.flag('gate') == 1,
              onTap: (c) => c.s.addFlag('gated_tapped')),
        ]),
        Scene(id: 'b', image: 'assets/scenes/wall_b.png'),
      ],
      closeups: {
        'cu': Scene(id: 'cu', image: 'assets/scenes/cu.png'),
      },
    );

void main() {
  late GameState s;
  late GameCtx c;

  Future<void> pump(WidgetTester t, Widget child) => t.pumpWidget(MaterialApp(
      home: Center(child: SizedBox(width: 400, height: 600, child: child))));

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
  });

  testWidgets('핫스팟 탭: 비율 좌표 히트 + 뒤 핫스팟 우선 + when 게이트', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    final origin = t.getTopLeft(find.byType(SceneView));
    await t.tapAt(origin + const Offset(200, 300)); // (0.5, 0.5)
    await t.pump();
    // gated가 뒤에 선언됐지만 when 미충족 → big이 받음
    expect(s.flag('tapped'), 1);
    expect(s.flag('gated_tapped'), 0);
    s.setFlag('gate', 1);
    await t.tapAt(origin + const Offset(200, 300));
    await t.pump();
    expect(s.flag('gated_tapped'), 1);
    expect(s.flag('tapped'), 1); // big은 더 안 받음
  });

  testWidgets('빈 곳 탭은 무반응', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    final origin = t.getTopLeft(find.byType(SceneView));
    await t.tapAt(origin + const Offset(10, 10)); // (0.025, 0.017)
    await t.pump();
    expect(s.flag('tapped'), 0);
  });

  testWidgets('화살표로 벽면 순환, 클로즈업 열면 화살표 숨김+X로 닫기', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    await t.tap(find.byKey(const Key('arrow_right')));
    await t.pump();
    expect(s.sceneIndex, 1);
    s.openCloseup('cu');
    await t.pump();
    expect(find.byKey(const Key('arrow_right')), findsNothing);
    await t.tap(find.byKey(const Key('closeup_close')));
    await t.pump();
    expect(s.closeupId, isNull);
  });

  testWidgets('없는 에셋은 파일명 라벨 색 블록 (스펙 §7)', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    await t.pump();
    expect(find.text('wall_a.png'), findsOneWidget);
  });

  testWidgets('오버레이는 조건 충족 시에만', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    await t.pump();
    expect(find.text('ov.png'), findsNothing);
    s.setFlag('ov', 1);
    await t.pump();
    expect(find.text('ov.png'), findsOneWidget);
  });

  testWidgets('대사 말풍선: 표시 + 탭으로 닫기', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    s.say('으스스한 인사');
    await t.pump();
    expect(find.text('으스스한 인사'), findsOneWidget);
    await t.tap(find.text('으스스한 인사'));
    await t.pump();
    expect(s.dialog, isNull);
  });

  testWidgets('인벤토리: 선택 → 조합 성공, 실패 시 선택 이동', (t) async {
    s.give('candle');
    s.give('match');
    s.give('key_foyer');
    await pump(t, InventoryBar(ctx: c));
    await t.tap(find.byKey(const Key('inv_candle')));
    await t.pump();
    expect(s.selectedItem, 'candle');
    await t.tap(find.byKey(const Key('inv_key_foyer'))); // 조합 안 됨
    await t.pump();
    expect(s.selectedItem, 'key_foyer');
    await t.tap(find.byKey(const Key('inv_candle')));
    await t.pump();
    await t.tap(find.byKey(const Key('inv_match'))); // 조합 성공
    await t.pump();
    expect(s.has('lit_candle'), isTrue);
    expect(s.selectedItem, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/scene_view_test.dart`
Expected: FAIL — scene_view.dart / inventory_bar.dart 없음.

- [ ] **Step 3: SceneView 구현**

`lib/core/scene_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'models.dart';

/// 에셋 없으면 파일명 라벨 색 블록 — 아트 도착 전에도 게임 동작 (스펙 §7).
Widget gameImage(String path) => Image.asset(
      path,
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF3A2E4F),
        alignment: Alignment.center,
        child: Text(path.split('/').last,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
    );

/// 벽면/클로즈업 렌더 + 비율 좌표 히트테스트. 부모가 2:3 박스를 보장한다.
class SceneView extends StatelessWidget {
  final Room room;
  final GameCtx ctx;
  const SceneView({super.key, required this.room, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final scene = s.closeupId != null
            ? room.closeups[s.closeupId]!
            : room.walls[s.sceneIndex % room.walls.length];
        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          Rect px(Rect r) =>
              Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
          return Stack(children: [
            if (scene.custom != null)
              Positioned.fill(child: scene.custom!(context, ctx))
            else ...[
              Positioned.fill(child: gameImage(scene.image!)),
              for (final o in scene.overlays)
                if (o.when(s))
                  Positioned.fromRect(rect: px(o.area), child: gameImage(o.image)),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final p = Offset(
                        d.localPosition.dx / w, d.localPosition.dy / h);
                    for (final hs in scene.hotspots.reversed) {
                      if ((hs.when?.call(s) ?? true) && hs.area.contains(p)) {
                        hs.onTap(ctx);
                        return;
                      }
                    }
                  },
                ),
              ),
            ],
            if (s.closeupId == null && room.walls.length > 1) ...[
              _arrow(left: true,
                  onTap: () => s.goScene(
                      (s.sceneIndex - 1 + room.walls.length) % room.walls.length)),
              _arrow(left: false,
                  onTap: () => s.goScene((s.sceneIndex + 1) % room.walls.length)),
            ],
            if (s.closeupId != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const Key('closeup_close'),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: s.closeCloseup,
                ),
              ),
            if (s.dialog != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () => s.say(null),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xE6241B36),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7C5CC4)),
                    ),
                    child: Text(s.dialog!,
                        style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ),
              ),
          ]);
        });
      },
    );
  }

  Widget _arrow({required bool left, required VoidCallback onTap}) => Positioned(
        left: left ? 0 : null,
        right: left ? null : 0,
        top: 0,
        bottom: 0,
        child: Center(
          child: IconButton(
            key: Key(left ? 'arrow_left' : 'arrow_right'),
            icon: Icon(left ? Icons.chevron_left : Icons.chevron_right,
                color: Colors.white70, size: 40),
            onPressed: onTap,
          ),
        ),
      );
}
```

- [ ] **Step 4: InventoryBar 구현**

`lib/core/inventory_bar.dart`:

```dart
import 'package:flutter/material.dart';
import '../rooms/items.dart';
import 'game_state.dart';
import 'models.dart';

class InventoryBar extends StatelessWidget {
  final GameCtx ctx;
  const InventoryBar({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => Container(
        height: 84,
        color: const Color(0xFF241B36),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          children: [for (final id in s.inventory) _slot(id, s)],
        ),
      ),
    );
  }

  Widget _slot(String id, GameState s) {
    final item = itemsById[id]!;
    final selected = s.selectedItem == id;
    return GestureDetector(
      key: Key('inv_$id'),
      onTap: () {
        if (selected) {
          s.select(null);
          return;
        }
        final prev = s.selectedItem;
        if (prev != null && tryCombine(s, prev, id)) {
          ctx.sfx('combine');
          return;
        }
        s.select(id);
      },
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF32264C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? const Color(0xFFFFB74D) : const Color(0xFF4A3A6B),
              width: selected ? 2.5 : 1),
        ),
        child: Column(children: [
          Expanded(
            child: Image.asset(item.icon,
                errorBuilder: (_, __, ___) => Center(
                    child: Text(item.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)))),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(item.name,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `.\tool\f.cmd test test/scene_view_test.dart`
Expected: All tests passed (7개). 이미지 로드 예외가 테스트 로그에 찍혀도 errorBuilder가 처리하므로 실패가 아니다 — assertion은 find 결과로만 판단.

- [ ] **Step 6: 전체 회귀 + Commit**

Run: `.\tool\f.cmd test`
Expected: 전부 통과.

```bash
git add lib/core/scene_view.dart lib/core/inventory_bar.dart test/scene_view_test.dart
git commit -m "코어: SceneView 핫스팟 렌더 + InventoryBar 선택·조합 UI"
```

---

### Task 7: HintService + 보상형 광고 + HintSheet

**Files:**
- Create: `lib/core/hint_service.dart`, `lib/core/ads.dart`, `lib/core/hint_sheet.dart`
- Test: `test/hint_service_test.dart`

**Interfaces:**
- Consumes: `GameState`(플래그 `hint_<puzzleId>`=해금 단계 0~3, `ad_fail`=광고 실패 누적), `Room.hints`, `PuzzleHint`
- Produces:
  - `enum HintOutcome { granted, grantedFree, adFailed, alreadyMax }`
  - `class HintService { HintService(GameState s, {required Future<bool> Function() showRewardedAd}); int unlocked(String puzzleId); Future<HintOutcome> unlockNext(String puzzleId); }`
  - `Future<bool> showRewardedAd()` (ads.dart 최상위 함수) — AdMob 테스트 유닛으로 로드·표시, 보상 시 true, 모든 실패는 false.
  - `void showHintSheet(BuildContext context, Room room, HintService hints)` (hint_sheet.dart) — 바텀시트.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/hint_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/hint_service.dart';

void main() {
  test('1단계는 무료, 광고 함수 호출 안 함', () async {
    var adCalls = 0;
    final svc = HintService(GameState(), showRewardedAd: () async {
      adCalls++;
      return true;
    });
    expect(await svc.unlockNext('p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 1);
    expect(adCalls, 0);
  });

  test('2·3단계는 광고 성공 시 해금, 3단계 이후 alreadyMax', () async {
    final svc = HintService(GameState(), showRewardedAd: () async => true);
    await svc.unlockNext('p1'); // 1 무료
    expect(await svc.unlockNext('p1'), HintOutcome.granted); // 2
    expect(await svc.unlockNext('p1'), HintOutcome.granted); // 3
    expect(svc.unlocked('p1'), 3);
    expect(await svc.unlockNext('p1'), HintOutcome.alreadyMax);
  });

  test('광고 실패 → adFailed + 누적, 3회째부터 무료 지급 (스펙 §6)', () async {
    final s = GameState();
    final svc = HintService(s, showRewardedAd: () async => false);
    await svc.unlockNext('p1'); // 1 무료
    expect(await svc.unlockNext('p1'), HintOutcome.adFailed); // fail 1
    expect(await svc.unlockNext('p1'), HintOutcome.adFailed); // fail 2
    expect(await svc.unlockNext('p1'), HintOutcome.adFailed); // fail 3
    expect(s.flag('ad_fail'), 3);
    expect(await svc.unlockNext('p1'), HintOutcome.grantedFree); // 무료 지급
    expect(svc.unlocked('p1'), 2);
    expect(s.flag('ad_fail'), 0); // 지급 후 리셋
  });

  test('광고 성공 시 실패 카운터 리셋', () async {
    final s = GameState();
    var ok = false;
    final svc = HintService(s, showRewardedAd: () async => ok);
    await svc.unlockNext('p1'); // 1 무료
    await svc.unlockNext('p1'); // fail 1
    ok = true;
    expect(await svc.unlockNext('p1'), HintOutcome.granted);
    expect(s.flag('ad_fail'), 0);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/hint_service_test.dart`
Expected: FAIL — hint_service.dart 없음.

- [ ] **Step 3: HintService 구현**

`lib/core/hint_service.dart`:

```dart
import 'game_state.dart';

enum HintOutcome { granted, grantedFree, adFailed, alreadyMax }

/// 3단계 힌트: 1단계 무료, 2·3단계 광고. 실패 누적 3회면 무료 (스펙 §6).
class HintService {
  final GameState s;
  final Future<bool> Function() showRewardedAd;
  HintService(this.s, {required this.showRewardedAd});

  int unlocked(String puzzleId) => s.flag('hint_$puzzleId');

  Future<HintOutcome> unlockNext(String puzzleId) async {
    final cur = unlocked(puzzleId);
    if (cur >= 3) return HintOutcome.alreadyMax;
    if (cur == 0) {
      s.setFlag('hint_$puzzleId', 1);
      return HintOutcome.granted;
    }
    if (s.flag('ad_fail') >= 3) {
      s.setFlag('ad_fail', 0);
      s.setFlag('hint_$puzzleId', cur + 1);
      return HintOutcome.grantedFree;
    }
    final rewarded = await showRewardedAd();
    if (!rewarded) {
      s.addFlag('ad_fail');
      return HintOutcome.adFailed;
    }
    s.setFlag('ad_fail', 0);
    s.setFlag('hint_$puzzleId', cur + 1);
    return HintOutcome.granted;
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `.\tool\f.cmd test test/hint_service_test.dart`
Expected: All tests passed (4개).

- [ ] **Step 5: 실제 광고 함수 (수동 검증 대상 — 단위 테스트 없음)**

`lib/core/ads.dart`:

```dart
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 공식 테스트 보상형 유닛. 실제 ID 교체는 출시 태스크 (스펙 §9).
const rewardedTestUnitId = 'ca-app-pub-3940256099942544/5224354917';
bool _initialized = false;

/// 보상 획득 시 true. 로드/표시 실패·예외는 전부 false (HintService가 폴백 처리).
Future<bool> showRewardedAd() async {
  try {
    if (!_initialized) {
      await MobileAds.instance.initialize();
      _initialized = true;
    }
    final loader = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: rewardedTestUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => loader.complete(ad),
        onAdFailedToLoad: (_) => loader.complete(null),
      ),
    );
    final ad = await loader.future;
    if (ad == null) return false;
    var rewarded = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => rewarded = true);
    await closed.future;
    return rewarded;
  } catch (_) {
    return false;
  }
}
```

- [ ] **Step 6: HintSheet UI (얇은 UI — 로직은 위에서 전부 테스트됨)**

`lib/core/hint_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'hint_service.dart';
import 'models.dart';
import 'strings.dart';

void showHintSheet(BuildContext context, Room room, HintService hints) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF241B36),
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(strHintTitle,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final h in room.hints) ...[
              Row(children: [
                Expanded(
                    child: Text(h.title,
                        style: const TextStyle(
                            color: Color(0xFFFFB74D), fontSize: 15))),
                if (h.solved?.call(hints.s) ?? false)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ]),
              for (var i = 0; i < hints.unlocked(h.puzzleId); i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${i + 1}. ${h.steps[i]}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              if (hints.unlocked(h.puzzleId) < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: Key('hint_btn_${h.puzzleId}'),
                    onPressed: () async {
                      final r = await hints.unlockNext(h.puzzleId);
                      if (r == HintOutcome.adFailed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(strAdFailed)));
                      }
                      setState(() {});
                    },
                    child: Text(hints.unlocked(h.puzzleId) == 0
                        ? strHintFree
                        : strHintByAd),
                  ),
                ),
              const Divider(color: Color(0xFF4A3A6B)),
            ],
          ],
        ),
      ),
    ),
  );
}
```

`lib/core/strings.dart`를 다음 4줄로 이 태스크에서 생성한다 (Task 8·9가 확장):

```dart
const strHintTitle = '힌트';
const strHintFree = '힌트 보기 (무료)';
const strHintByAd = '광고 보고 힌트 보기';
const strAdFailed = '광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.';
```

- [ ] **Step 7: analyze + 전체 회귀 + Commit**

Run: `.\tool\f.cmd analyze` → Expected: No issues found!
Run: `.\tool\f.cmd test` → Expected: 전부 통과.

```bash
git add lib/core/hint_service.dart lib/core/ads.dart lib/core/hint_sheet.dart lib/core/strings.dart test/hint_service_test.dart
git commit -m "코어: 3단계 힌트 + 보상형 광고 게이트 + 실패 3회 무료 폴백"
```

---

### Task 8: 현관(튜토리얼) 방 — 콘텐츠 + 커스텀 기믹 + 아트 의뢰 문서

**Files:**
- Create: `lib/rooms/room1_foyer.dart`, `lib/rooms/rooms.dart`
- Modify: `lib/core/strings.dart` (대사 추가)
- Create: `art/style-guide.md`, `art/room1-assets.md`
- Test: `test/room1_foyer_test.dart`

**Interfaces:**
- Consumes: 모든 코어 (`Room/Scene/Hotspot/SceneOverlay/PuzzleHint`, `GameCtx`, `gameImage`, `tryCombine`)
- Produces:
  - `Room buildFoyer()` (room1_foyer.dart)
  - `void tapClockHand(GameState s)` — 시침 1→12 순환(`clock_hour`), 3시 도달 시 `drawer_unlocked=1`
  - `void finishRubbing(GameState s)` — `dust_cleaned=1`
  - `List<Room> buildAllRooms()` (rooms.dart) — 현재 `[buildFoyer()]`
  - 사용 플래그: `got_match, got_candle, dust_cleaned, clock_hour, drawer_unlocked, drawer_lit, got_key, inner_door_open, foyer_done` / 힌트 퍼즐 id: `p_light, p_clock, p_door`

**퍼즐 흐름(정답)**: 외투→성냥 → 신발장 클로즈업→양초 → 조합=불 켠 초 → 액자 먼지 문지르기→"시계 3시" 그림 → 벽시계 시침 3시→서랍 해금 → 서랍 클로즈업(어두움)→불 켠 초 사용→열쇠 → 열쇠로 안쪽 문 → 문 탭해 입장=클리어. 튜토리얼로서 탭/클로즈업/조합/문지르기/교차 단서/아이템 사용을 순서대로 가르친다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/room1_foyer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';

void main() {
  late GameState s;
  late GameCtx c;
  late Room room;

  Hotspot find(String sceneId, String hotspotId) {
    final scenes = [...room.walls, ...room.closeups.values];
    final scene = scenes.firstWhere((sc) => sc.id == sceneId);
    return scene.hotspots.firstWhere((h) => h.id == hotspotId);
  }

  void tap(String sceneId, String hotspotId) {
    final h = find(sceneId, hotspotId);
    expect(h.when?.call(s) ?? true, isTrue,
        reason: '$hotspotId가 비활성 상태에서 탭됨');
    h.onTap(c);
  }

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
    room = buildFoyer();
  });

  test('정답 시퀀스로 클리어 가능 (스펙 §8 최소 안전망)', () {
    expect(room.cleared(s), isFalse);

    tap('foyer_b', 'coat'); // 성냥
    expect(s.has('match'), isTrue);
    tap('foyer_b', 'coat'); // 두 번째는 빈 주머니 (중복 지급 없음)
    expect(s.inventory.where((i) => i == 'match').length, 1);

    tap('foyer_b', 'shoe_cabinet');
    expect(s.closeupId, 'shoes');
    tap('shoes', 'candle_in_shoe'); // 양초
    expect(s.has('candle'), isTrue);

    expect(tryCombine(s, 'candle', 'match'), isTrue);
    expect(s.has('lit_candle'), isTrue);

    // 잠긴 서랍은 아직 안 열림
    s.closeCloseup();
    tap('foyer_a', 'drawer');
    expect(s.closeupId, isNull);

    // 액자 먼지 → 시계 3시 단서 (제스처 로직 함수)
    finishRubbing(s);
    expect(s.flag('dust_cleaned'), 1);

    // 벽시계 12→1→2→3
    tapClockHand(s);
    tapClockHand(s);
    tapClockHand(s);
    expect(s.flag('clock_hour'), 3);
    expect(s.flag('drawer_unlocked'), 1);

    // 서랍: 열림 → 어두움 → 촛불 → 열쇠
    tap('foyer_a', 'drawer');
    expect(s.closeupId, 'drawer');
    s.select('lit_candle');
    tap('drawer', 'drawer_dark');
    expect(s.flag('drawer_lit'), 1);
    tap('drawer', 'drawer_key');
    expect(s.has('key_foyer'), isTrue);

    // 문: 잠김 → 열쇠 → 입장
    expect(room.cleared(s), isFalse);
    s.select('key_foyer');
    tap('foyer_a', 'inner_door');
    expect(s.flag('inner_door_open'), 1);
    expect(s.has('key_foyer'), isFalse); // 열쇠 소모
    tap('foyer_a', 'inner_door');
    expect(room.cleared(s), isTrue);
  });

  test('순서 강제: 촛불 없이 서랍 안은 안 보임, 열쇠 없인 문 안 열림', () {
    s.setFlag('drawer_unlocked', 1);
    tap('foyer_a', 'drawer');
    tap('drawer', 'drawer_dark'); // 촛불 미선택
    expect(s.flag('drawer_lit'), 0);
    tap('foyer_a', 'inner_door'); // 열쇠 없음
    expect(s.flag('inner_door_open'), 0);
  });

  test('시계는 12시간 순환', () {
    for (var i = 0; i < 12; i++) {
      tapClockHand(s);
    }
    expect(s.flag('clock_hour'), 12);
    tapClockHand(s);
    expect(s.flag('clock_hour'), 1);
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId), ['p_light', 'p_clock', 'p_door']);
    s.setFlag('drawer_lit', 1);
    expect(room.hints[0].solved!(s), isTrue);
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['match', 'candle', 'lit_candle', 'key_foyer']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `.\tool\f.cmd test test/room1_foyer_test.dart`
Expected: FAIL — room1_foyer.dart 없음.

- [ ] **Step 3: 대사 추가**

`lib/core/strings.dart`에 추가 (Task 7의 4줄 유지):

```dart
// ── 현관 (room1_foyer) ──
const strFoyerIntro =
    '어이쿠, 살아있는 사람이잖아?! …아, 아니, 어흠. 나는 이 저택의 집사 유령 "고스포"다. '
    '상속자라면 자격을 증명해야지. 이 현관을 빠져나와 보시게. 무, 무섭지? 응?';
const strFoyerGhostChat = '"시험 중엔 말 걸지 말아줄래? …사실 나도 정답이 잘 기억 안 나."';
const strFoyerFrontDoor = '나가는 문은 안 열어줌. 밖은 깜깜하고… 솔직히 나도 밖은 좀 무서워. — 고스포';
const strFoyerUmbrella = '우산꽂이. 우산은 없고 거미줄만 잔뜩이다.';
const strFoyerCoatMatch = '외투 주머니에서 성냥을 찾았다!';
const strFoyerCoatEmpty = '주머니엔 이제 보풀뿐이다.';
const strFoyerCandleFound = '신발 속에 양초가?! 삼촌의 수납 센스는 알 수가 없다.';
const strFoyerDoorLocked = '단단히 잠겨 있다. 오래된 열쇠 구멍이 보인다.';
const strFoyerDrawerLocked = '서랍이 잠겨 있다. 어디선가 "똑딱똑딱" 소리가 들리는 것 같은데…';
const strFoyerDrawerDark = '서랍 속이 너무 어두워서 아무것도 안 보인다.';
const strFoyerKeyFound = '낡은 열쇠를 얻었다! 고스포가 아쉬운 표정을 짓는다.';
const strFoyerDoorOpened = '철컥! 문이 열렸다. 저택 안쪽으로 들어가자.';
const strFoyerClockSet = '똑딱… 철컥! 어디선가 잠금이 풀리는 소리가 났다.';
```

- [ ] **Step 4: 방 구현**

`lib/rooms/room1_foyer.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──

/// 시침 탭: 1→12 순환. 3시 도달 시 서랍 해금.
void tapClockHand(GameState s) {
  final cur = s.flag('clock_hour') == 0 ? 12 : s.flag('clock_hour');
  final next = cur % 12 + 1;
  s.setFlag('clock_hour', next);
  if (next == 3) s.setFlag('drawer_unlocked', 1);
}

/// 액자 먼지 닦기 완료.
void finishRubbing(GameState s) => s.setFlag('dust_cleaned', 1);

// ── 커스텀 기믹 위젯 (escape hatch) ──

/// 벽시계 클로즈업: 탭할 때마다 시침이 한 칸 돈다.
class ClockCloseup extends StatelessWidget {
  final GameCtx ctx;
  const ClockCloseup({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final hour = s.flag('clock_hour') == 0 ? 12 : s.flag('clock_hour');
        return GestureDetector(
          key: const Key('clock_tap'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final before = s.flag('drawer_unlocked');
            tapClockHand(s);
            ctx.sfx('clock_tick');
            if (before == 0 && s.flag('drawer_unlocked') == 1) {
              ctx.sfx('unlock');
              ctx.say(strFoyerClockSet);
            }
          },
          child: Stack(fit: StackFit.expand, children: [
            gameImage('assets/scenes/foyer_clock.png'),
            CustomPaint(painter: _HandPainter(hour)),
          ]),
        );
      },
    );
  }
}

class _HandPainter extends CustomPainter {
  final int hour;
  _HandPainter(this.hour);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final angle = hour * 2 * math.pi / 12;
    final tip = center +
        Offset(math.sin(angle), -math.cos(angle)) * size.shortestSide * 0.28;
    canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = const Color(0xFFF5E6C8)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.hour != hour;
}

/// 액자 클로즈업: 먼지를 문질러 닦는다.
class FrameCloseup extends StatefulWidget {
  final GameCtx ctx;
  const FrameCloseup({super.key, required this.ctx});

  @override
  State<FrameCloseup> createState() => _FrameCloseupState();
}

class _FrameCloseupState extends State<FrameCloseup> {
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.ctx.s;
    final cleaned = s.flag('dust_cleaned') == 1;
    return GestureDetector(
      key: const Key('frame_rub'),
      behavior: HitTestBehavior.opaque,
      onPanUpdate: cleaned
          ? null
          : (d) {
              setState(() => progress += d.delta.distance / 2500);
              if (progress >= 1) {
                finishRubbing(s);
                widget.ctx.sfx('sparkle');
              }
            },
      child: Stack(fit: StackFit.expand, children: [
        gameImage('assets/scenes/foyer_frame_clean.png'),
        if (!cleaned)
          Opacity(
              opacity: (1 - progress).clamp(0.0, 1.0),
              child: gameImage('assets/scenes/foyer_frame_dust.png')),
      ]),
    );
  }
}

// ── 방 정의 ──

Room buildFoyer() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  return Room(
    id: 'foyer',
    name: '현관',
    onEnter: (c) => c.say(strFoyerIntro),
    cleared: flagSet('foyer_done'),
    walls: [
      // 벽면 A: 안쪽 문
      Scene(id: 'foyer_a', image: 'assets/scenes/foyer_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/foyer_a_door_open.png',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            when: flagSet('inner_door_open')),
        SceneOverlay(
            image: 'assets/scenes/ghost_butler.png',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_done') == 0),
      ], hotspots: [
        Hotspot(
            id: 'inner_door',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            onTap: (c) {
              final s = c.s;
              if (s.flag('inner_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('foyer_done', 1);
              } else if (c.using('key_foyer')) {
                c.consume('key_foyer');
                c.sfx('unlock');
                s.setFlag('inner_door_open', 1);
                c.say(strFoyerDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strFoyerDoorLocked);
              }
            }),
        Hotspot(
            id: 'ghost',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_done') == 0,
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strFoyerGhostChat);
            }),
        Hotspot(
            id: 'frame',
            area: const Rect.fromLTWH(0.66, 0.12, 0.24, 0.20),
            onTap: (c) => c.openCloseup('frame')),
        Hotspot(
            id: 'drawer',
            area: const Rect.fromLTWH(0.64, 0.52, 0.28, 0.16),
            onTap: (c) {
              if (c.s.flag('drawer_unlocked') >= 1) {
                c.openCloseup('drawer');
              } else {
                c.sfx('locked');
                c.say(strFoyerDrawerLocked);
              }
            }),
        Hotspot(
            id: 'umbrella_stand',
            area: const Rect.fromLTWH(0.02, 0.66, 0.14, 0.22),
            onTap: (c) => c.say(strFoyerUmbrella)),
      ]),
      // 벽면 B: 입구
      Scene(id: 'foyer_b', image: 'assets/scenes/foyer_b.png', hotspots: [
        Hotspot(
            id: 'coat',
            area: const Rect.fromLTWH(0.08, 0.28, 0.22, 0.36),
            onTap: (c) {
              if (c.s.flag('got_match') == 0) {
                c.s.setFlag('got_match', 1);
                c.give('match');
                c.say(strFoyerCoatMatch);
              } else {
                c.say(strFoyerCoatEmpty);
              }
            }),
        Hotspot(
            id: 'clock',
            area: const Rect.fromLTWH(0.40, 0.08, 0.20, 0.16),
            onTap: (c) => c.openCloseup('clock')),
        Hotspot(
            id: 'front_door',
            area: const Rect.fromLTWH(0.36, 0.30, 0.28, 0.42),
            onTap: (c) => c.say(strFoyerFrontDoor)),
        Hotspot(
            id: 'shoe_cabinet',
            area: const Rect.fromLTWH(0.66, 0.56, 0.30, 0.26),
            onTap: (c) => c.openCloseup('shoes')),
      ]),
    ],
    closeups: {
      'shoes': Scene(id: 'shoes', image: 'assets/scenes/foyer_shoes.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/foyer_shoes_candle.png',
                area: const Rect.fromLTWH(0.52, 0.34, 0.28, 0.32),
                when: (s) => s.flag('got_candle') == 0),
          ],
          hotspots: [
            Hotspot(
                id: 'candle_in_shoe',
                area: const Rect.fromLTWH(0.52, 0.34, 0.28, 0.32),
                when: (s) => s.flag('got_candle') == 0,
                onTap: (c) {
                  c.s.setFlag('got_candle', 1);
                  c.give('candle');
                  c.say(strFoyerCandleFound);
                }),
          ]),
      'drawer': Scene(id: 'drawer', image: 'assets/scenes/foyer_drawer_dark.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/foyer_drawer_lit.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('drawer_lit')),
          ],
          hotspots: [
            Hotspot(
                id: 'drawer_dark',
                area: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
                when: (s) => s.flag('drawer_lit') == 0,
                onTap: (c) {
                  if (c.using('lit_candle')) {
                    c.s.setFlag('drawer_lit', 1);
                    c.sfx('sparkle');
                  } else {
                    c.say(strFoyerDrawerDark);
                  }
                }),
            Hotspot(
                id: 'drawer_key',
                area: const Rect.fromLTWH(0.38, 0.42, 0.24, 0.16),
                when: (s) => s.flag('drawer_lit') >= 1 && s.flag('got_key') == 0,
                onTap: (c) {
                  c.s.setFlag('got_key', 1);
                  c.give('key_foyer');
                  c.say(strFoyerKeyFound);
                }),
          ]),
      'frame': Scene(id: 'frame', custom: (_, c) => FrameCloseup(ctx: c)),
      'clock': Scene(id: 'clock', custom: (_, c) => ClockCloseup(ctx: c)),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_light', title: '어두운 서랍 속', steps: [
        '어둠 속을 보려면 불빛이 필요해요. 불을 만들 재료 두 가지가 이 현관 어딘가에 있어요.',
        '외투 주머니와 신발장 안을 살펴보세요. 인벤토리에서 두 아이템을 차례로 탭하면 조합할 수 있어요.',
        '정답: 외투에서 성냥, 신발장의 신발 속에서 양초를 얻어 조합하면 "불 켠 초". 서랍을 연 뒤 불 켠 초를 선택하고 서랍 안을 탭하세요.',
      ], solved: (s) => s.flag('drawer_lit') >= 1),
      PuzzleHint(puzzleId: 'p_clock', title: '잠긴 서랍', steps: [
        '서랍의 잠금은 이 방의 다른 물건과 연결돼 있어요. 벽에 걸린 것들을 잘 보세요.',
        '액자의 먼지를 손가락으로 문질러 닦으면 그림이 드러나요. 그림 속 시계가 가리키는 시각은?',
        '정답: 액자 그림의 시계는 3시. 입구 쪽 벽시계를 탭해 시침을 3시에 맞추면 서랍이 열려요.',
      ], solved: (s) => s.flag('drawer_unlocked') >= 1),
      PuzzleHint(puzzleId: 'p_door', title: '안쪽 문', steps: [
        '문을 열려면 열쇠가 필요해요. 아직 들여다보지 못한 곳이 있지 않나요?',
        '콘솔 서랍 깊은 곳 — 불을 비추면 반짝이는 게 보여요.',
        '정답: 서랍 안의 낡은 열쇠를 선택한 채 안쪽 문을 탭하면 열려요. 열린 문을 다시 탭하면 입장!',
      ], solved: (s) => s.flag('inner_door_open') >= 1),
    ],
  );
}
```

`lib/rooms/rooms.dart`:

```dart
import '../core/models.dart';
import 'room1_foyer.dart';

/// 챕터 1 방 목록 (순차 해금). 방 추가 = 여기 한 줄 (스펙 §4.3).
List<Room> buildAllRooms() => [buildFoyer()];
```

- [ ] **Step 5: 통과 확인**

Run: `.\tool\f.cmd test test/room1_foyer_test.dart`
Expected: All tests passed (5개).

- [ ] **Step 6: 커스텀 위젯 배선 위젯 테스트**

`test/room1_foyer_test.dart` 끝의 `main()` 안에 추가:

```dart
  testWidgets('시계 위젯: 탭 3번이면 서랍 해금', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: ClockCloseup(ctx: c))));
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const Key('clock_tap')));
      await t.pump();
    }
    expect(s.flag('drawer_unlocked'), 1);
  });

  testWidgets('액자 위젯: 문지르면 먼지 제거', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: FrameCloseup(ctx: c))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('frame_rub')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('dust_cleaned'), 1);
  });
```

Run: `.\tool\f.cmd test test/room1_foyer_test.dart`
Expected: All tests passed (7개).

- [ ] **Step 7: 아트 스타일 가이드 + 현관 에셋 의뢰 문서**

`art/style-guide.md`:

```markdown
# GhostManor 아트 스타일 가이드 (Codex 생성용)

모든 이미지 프롬프트 앞에 붙이는 공통 접두어:

> 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에
> 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 분위기, 낡은 빅토리안 저택,
> 텍스트·글자 없음, 모바일 게임 배경 일러스트

규칙:
- 벽면 씬: 1024×1536 세로. 화면에 글자·숫자 넣지 않는다(단서는 그림·기호로).
- 클로즈업: 1024×1024.
- 아이템: 512×512, 배경 투명(PNG), 사물 하나만 중앙에.
- 오버레이: 대응하는 씬과 같은 구도로 부분만 다르게 생성 후 해당 영역을 잘라낸다.
- 첫 방(현관) 생성에서 톤이 확정되면 이 문서에 확정 프롬프트를 기록하고 이후 전 에셋에 동일 적용.
- 방 1개 분량씩 생성→게임에서 확인→다음 방 (스펙 §5.3).
```

`art/room1-assets.md` — 아래 표 그대로 작성. `배치 좌표`는 코드의 비율 사각형(LTWH)으로, 오버레이를 그 위치에 맞게 잘라 넣으면 된다:

```markdown
# 현관(room1_foyer) 에셋 의뢰 목록

공통 접두어는 style-guide.md 참조. 완성 파일은 그대로 아래 경로에 저장 (코드 수정 불필요).

## 씬 (1024×1536)
| 파일 | 내용 |
|---|---|
| assets/scenes/foyer_a.png | 저택 현관 안쪽 벽. 중앙에 잠긴 커다란 목재 문(0.36,0.28,0.28,0.44), 오른쪽 위 먼지 낀 액자(0.66,0.12,0.24,0.20), 오른쪽 아래 서랍 달린 콘솔 테이블(0.64,0.52,0.28,0.16), 왼쪽 아래 우산꽂이(0.02,0.66,0.14,0.22), 왼쪽 중간은 비워둠(유령 자리) |
| assets/scenes/foyer_b.png | 현관 입구 벽. 왼쪽 코트 걸이에 낡은 외투(0.08,0.28,0.22,0.36), 위 중앙 벽시계—시곗바늘 없이 문자판만(0.40,0.08,0.20,0.16), 중앙 현관문(0.36,0.30,0.28,0.42), 오른쪽 아래 신발장(0.66,0.56,0.30,0.26) |

## 오버레이 (씬 부분, 좌표에 맞춰 재단)
| 파일 | 내용 | 배치 좌표(LTWH, foyer_a 기준) |
|---|---|---|
| assets/scenes/foyer_a_door_open.png | 활짝 열린 안쪽 문, 안쪽은 어두운 복도 | 0.36,0.28,0.28,0.44 |
| assets/scenes/ghost_butler.png | 코믹한 집사 유령 "고스포" — 나비넥타이, 허세 부리는 표정, 반투명 | 0.02,0.34,0.20,0.30 |

## 클로즈업 (1024×1024)
| 파일 | 내용 |
|---|---|
| assets/scenes/foyer_shoes.png | 열린 신발장 내부, 낡은 구두들 |
| assets/scenes/foyer_shoes_candle.png | (오버레이) 구두 속에 꽂힌 양초, 좌표 0.52,0.34,0.28,0.32 |
| assets/scenes/foyer_drawer_dark.png | 열린 서랍 내부, 거의 새까만 어둠 |
| assets/scenes/foyer_drawer_lit.png | 같은 구도, 촛불에 비친 서랍 속 — 중앙(0.38,0.42,0.24,0.16)에 낡은 열쇠 |
| assets/scenes/foyer_frame_clean.png | 액자 그림: 벽난로 위 시계가 3시를 가리키는 옛 저택 그림 (바늘이 또렷하게 3시) |
| assets/scenes/foyer_frame_dust.png | 같은 크기의 뿌연 먼지 층 (아래가 안 비치는 회색 먼지) |
| assets/scenes/foyer_clock.png | 벽시계 문자판 클로즈업, 시곗바늘 없음 (바늘은 코드가 그림) |

## 아이템 (512×512, 투명 배경)
| 파일 | 내용 |
|---|---|
| assets/items/match.png | 성냥 한 갑 |
| assets/items/candle.png | 꺼진 양초 |
| assets/items/lit_candle.png | 불 켜진 양초 |
| assets/items/key_foyer.png | 낡은 놋쇠 열쇠 |

## 효과음 (Codex 아님 — CC0 사이트에서 수급, mp3)
assets/audio/: pickup, combine, unlock, locked, door_open, clock_tick, sparkle, ghost_giggle, bgm_manor(루프 BGM)
```

- [ ] **Step 8: analyze + 전체 회귀 + Commit**

Run: `.\tool\f.cmd analyze` → Expected: No issues found!
Run: `.\tool\f.cmd test` → Expected: 전부 통과.

```bash
git add lib/rooms/ lib/core/strings.dart test/room1_foyer_test.dart art/
git commit -m "현관 튜토리얼 방: 퍼즐 배선 + 시계·먼지닦기 기믹 + 아트 의뢰 문서"
```

---

### Task 9: 앱 셸 — 타이틀·설정·RoomScreen·클리어 흐름

**Files:**
- Modify: `lib/main.dart` (전체 교체)
- Modify: `lib/core/strings.dart` (셸 문구 추가)
- Test: `test/app_shell_test.dart`

**Interfaces:**
- Consumes: 전부 — `buildAllRooms()`, `SceneView`, `InventoryBar`, `SaveService`, `HintService`, `showHintSheet`, `showRewardedAd`, `AudioService`, `GameState`
- Produces:
  - `class GhostManorApp extends StatefulWidget { GhostManorApp({GameState? initialState, Future<bool> Function()? adFn, bool audioEnabled = true}); }` — 테스트 주입 포인트 3개.
  - `class RoomScreen` (main.dart 내부) — 상단바(방 이름, 힌트 `Key('btn_hint')`, 설정 `Key('btn_settings')`), 중앙 `AspectRatio(2/3)` SceneView, 하단 InventoryBar. 첫 진입 시 `entered_<roomId>` 플래그 + `onEnter` 호출. `room.cleared(s)`가 참이 되면 클리어 다이얼로그(1회, `cleared_shown_<roomId>` 플래그) → 다음 방 `goRoom` 또는 마지막 방이면 엔딩 화면.
  - 사용 플래그: `entered_<roomId>`, `cleared_shown_<roomId>`, `muted`

- [ ] **Step 1: 셸 문구 추가**

`lib/core/strings.dart`에 추가:

```dart
// ── 앱 셸 ──
const strAppTitle = '기묘한 유령 저택';
const strContinue = '이어하기';
const strNewGame = '처음부터';
const strNewGameConfirm = '저장된 진행이 삭제됩니다. 처음부터 시작할까요?';
const strSettings = '설정';
const strMute = '소리 끄기';
const strResetProgress = '진행 초기화';
const strResetConfirm = '정말 모든 진행을 삭제할까요?';
const strRoomClear = '방 탈출 성공!';
const strNextRoom = '다음 방으로';
const strChapterEnd = '챕터 1 클리어!\n저택의 더 깊은 곳은 준비 중…';
const strBackToTitle = '처음으로';
const strCancel = '취소';
const strOk = '확인';
```

- [ ] **Step 2: 실패하는 테스트 작성**

`test/app_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app({GameState? state}) => GhostManorApp(
      initialState: state, adFn: () async => true, audioEnabled: false);

  testWidgets('타이틀: 세이브 없으면 이어하기 없음, 처음부터 → 현관 진입 + 인트로 대사', (t) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text(strAppTitle), findsOneWidget);
    expect(find.text(strContinue), findsNothing);
    await t.tap(find.text(strNewGame));
    await t.pumpAndSettle();
    expect(find.text('현관'), findsOneWidget);
    expect(find.textContaining('고스포'), findsOneWidget); // onEnter 인트로
  });

  testWidgets('클리어 흐름: foyer_done → 클리어 다이얼로그 → (마지막 방) 엔딩', (t) async {
    final s = GameState()..setFlag('entered_foyer', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text('현관'), findsOneWidget);
    s.setFlag('foyer_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text(strChapterEnd), findsOneWidget); // 방 1개뿐이라 엔딩
  });

  testWidgets('설정: 진행 초기화 → 타이틀로 + 세이브 삭제', (t) async {
    final s = GameState()..setFlag('entered_foyer', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('btn_settings')));
    await t.pumpAndSettle();
    await t.tap(find.text(strResetProgress));
    await t.pumpAndSettle();
    await t.tap(find.text(strOk));
    await t.pumpAndSettle();
    expect(find.text(strAppTitle), findsOneWidget);
    expect(find.text(strContinue), findsNothing); // 세이브 없음
  });

  testWidgets('힌트 버튼 → 힌트 시트에 퍼즐 목록', (t) async {
    final s = GameState()..setFlag('entered_foyer', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('btn_hint')));
    await t.pumpAndSettle();
    expect(find.text('어두운 서랍 속'), findsOneWidget);
    expect(find.text('잠긴 서랍'), findsOneWidget);
    expect(find.text('안쪽 문'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `.\tool\f.cmd test test/app_shell_test.dart`
Expected: FAIL — GhostManorApp에 해당 생성자·화면 없음.

- [ ] **Step 4: 구현**

`lib/main.dart` 전체 교체:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/ads.dart' as ads;
import 'core/audio_service.dart';
import 'core/game_state.dart';
import 'core/hint_service.dart';
import 'core/hint_sheet.dart';
import 'core/inventory_bar.dart';
import 'core/models.dart';
import 'core/save_service.dart';
import 'core/scene_view.dart';
import 'core/strings.dart';
import 'rooms/rooms.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GhostManorApp());
}

class GhostManorApp extends StatefulWidget {
  final GameState? initialState; // 테스트 주입: 지정 시 타이틀 건너뛰고 바로 방
  final Future<bool> Function()? adFn;
  final bool audioEnabled;
  const GhostManorApp(
      {super.key, this.initialState, this.adFn, this.audioEnabled = true});

  @override
  State<GhostManorApp> createState() => _GhostManorAppState();
}

class _GhostManorAppState extends State<GhostManorApp> {
  final save = SaveService();
  late final audio = AudioService(enabled: widget.audioEnabled);
  late final rooms = buildAllRooms();
  GameState? playing; // null이면 타이틀
  bool hasSave = false;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialState != null) {
      _start(widget.initialState!);
      loaded = true;
    } else {
      save.load().then((s) {
        setState(() {
          hasSave = s != null;
          loaded = true;
        });
      });
    }
  }

  void _start(GameState s) {
    save.attach(s);
    audio.muted = s.flag('muted') == 1;
    setState(() => playing = s);
  }

  Future<void> _toTitle() async {
    final s = await save.load();
    setState(() {
      playing = null;
      hasSave = s != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: strAppTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B3E96), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF1A1226),
      ),
      home: !loaded
          ? const Scaffold(body: SizedBox())
          : playing == null
              ? TitleScreen(
                  hasSave: hasSave,
                  onContinue: () async {
                    final s = await save.load();
                    if (s != null) _start(s);
                  },
                  onNewGame: (context) async {
                    if (hasSave) {
                      final ok = await _confirm(context, strNewGameConfirm);
                      if (!ok) return;
                      await save.clear();
                    }
                    _start(GameState());
                  },
                )
              : RoomScreen(
                  state: playing!,
                  rooms: rooms,
                  audio: audio,
                  save: save,
                  adFn: widget.adFn ?? ads.showRewardedAd,
                  onExitToTitle: _toTitle,
                ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(strCancel)),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(strOk)),
      ],
    ),
  );
  return r ?? false;
}

class TitleScreen extends StatelessWidget {
  final bool hasSave;
  final VoidCallback onContinue;
  final void Function(BuildContext) onNewGame;
  const TitleScreen(
      {super.key,
      required this.hasSave,
      required this.onContinue,
      required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text(strAppTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          if (hasSave)
            FilledButton(onPressed: onContinue, child: const Text(strContinue)),
          const SizedBox(height: 12),
          FilledButton.tonal(
              onPressed: () => onNewGame(context),
              child: const Text(strNewGame)),
        ]),
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  final GameState state;
  final List<Room> rooms;
  final AudioService audio;
  final SaveService save;
  final Future<bool> Function() adFn;
  final Future<void> Function() onExitToTitle;
  const RoomScreen(
      {super.key,
      required this.state,
      required this.rooms,
      required this.audio,
      required this.save,
      required this.adFn,
      required this.onExitToTitle});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final GameCtx ctx = GameCtx(widget.state, widget.audio);
  late final HintService hints =
      HintService(widget.state, showRewardedAd: widget.adFn);

  Room get room => widget.rooms[widget.state.roomIndex % widget.rooms.length];

  @override
  void initState() {
    super.initState();
    widget.audio.playBgm('bgm_manor');
    widget.state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheRoomImages();
      _enterRoomIfFirst();
    });
  }

  /// 방 진입 시 이미지 프리로드 (스펙 §4.6). 에셋 미도착이면 조용히 무시.
  void _precacheRoomImages() {
    for (final sc in [...room.walls, ...room.closeups.values]) {
      for (final path in [
        if (sc.image != null) sc.image!,
        for (final o in sc.overlays) o.image,
      ]) {
        precacheImage(AssetImage(path), context, onError: (_, __) {});
      }
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _enterRoomIfFirst() {
    final s = widget.state;
    if (s.flag('entered_${room.id}') == 0) {
      s.setFlag('entered_${room.id}', 1);
      room.onEnter?.call(ctx);
    }
    _onStateChanged();
  }

  void _onStateChanged() {
    final s = widget.state;
    if (room.cleared(s) && s.flag('cleared_shown_${room.id}') == 0) {
      s.setFlag('cleared_shown_${room.id}', 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showClear());
    }
  }

  Future<void> _showClear() async {
    widget.audio.play('door_open');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(strRoomClear),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final s = widget.state;
              if (s.roomIndex + 1 < widget.rooms.length) {
                s.goRoom(s.roomIndex + 1);
                _precacheRoomImages();
                _enterRoomIfFirst();
              } else {
                setState(() => _ended = true);
              }
            },
            child: const Text(strNextRoom),
          ),
        ],
      ),
    );
  }

  bool _ended = false;

  Future<void> _openSettings() async {
    final s = widget.state;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(strSettings),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          StatefulBuilder(
            builder: (context, setDlg) => SwitchListTile(
              title: const Text(strMute),
              value: widget.audio.muted,
              onChanged: (v) {
                widget.audio.setMuted(v);
                s.setFlag('muted', v ? 1 : 0);
                setDlg(() {});
              },
            ),
          ),
          TextButton(
            onPressed: () async {
              final ok = await _confirm(context, strResetConfirm);
              if (!ok) return;
              await widget.save.clear();
              if (context.mounted) Navigator.pop(context);
              await widget.onExitToTitle();
            },
            child: const Text(strResetProgress,
                style: TextStyle(color: Colors.redAccent)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ended) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text(strChapterEnd,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 22)),
            const SizedBox(height: 32),
            FilledButton(
                onPressed: widget.onExitToTitle,
                child: const Text(strBackToTitle)),
          ]),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 16),
            Expanded(
                child: Text(room.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(
                key: const Key('btn_hint'),
                icon: const Icon(Icons.lightbulb_outline),
                onPressed: () => showHintSheet(context, room, hints)),
            IconButton(
                key: const Key('btn_settings'),
                icon: const Icon(Icons.settings),
                onPressed: _openSettings),
          ]),
          Expanded(
            child: Center(
              child: AspectRatio(
                  aspectRatio: 2 / 3, child: SceneView(room: room, ctx: ctx)),
            ),
          ),
          InventoryBar(ctx: ctx),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `.\tool\f.cmd test test/app_shell_test.dart`
Expected: All tests passed (4개).

- [ ] **Step 6: analyze + 전체 회귀 + Commit**

Run: `.\tool\f.cmd analyze` → Expected: No issues found!
Run: `.\tool\f.cmd test` → Expected: 전부 통과.

```bash
git add lib/main.dart lib/core/strings.dart test/app_shell_test.dart
git commit -m "앱 셸: 타이틀·설정·RoomScreen·클리어 흐름 + 자동 저장 배선"
```

---

### Task 10: 통합 검증 + 릴리스 빌드 + README

**Files:**
- Create: `README.md`
- Modify: 없음 (검증 태스크)

**Interfaces:**
- Consumes: 전체 앱
- Produces: 실기기 설치 가능한 debug/release APK, 프로젝트 README

- [ ] **Step 1: 전체 테스트·분석 최종 확인**

Run: `.\tool\f.cmd analyze` → Expected: No issues found!
Run: `.\tool\f.cmd test` → Expected: 전부 통과 (총 30개 내외).

- [ ] **Step 2: 릴리스 APK 빌드 (릴리스 전용 문제 조기 발견 — 스펙 §8)**

Run: `.\tool\f.cmd build apk --release`
Expected: `Built build\app\outputs\flutter-apk\app-release.apk`. (서명은 debug 키 — 스토어 서명은 출시 단계.)

- [ ] **Step 3: README 작성**

`README.md`:

```markdown
# 기묘한 유령 저택 (GhostManor)

세로 화면 포인트앤클릭 방탈출. 코믹+으스스한 유령 저택, 챕터 1.

## 빌드 (한글 사용자명 머신 — 반드시 래퍼 사용)

- 모든 flutter 명령: `.\tool\f.cmd <args>` (ASCII 경로 환경변수 자동 설정)
- 테스트: `.\tool\f.cmd test` — 래퍼 없이 직접 실행하면 TEMP 한글 경로로 flutter_tester가 0xC0000409로 죽는다
- APK: `.\tool\f.cmd build apk --release`
- `C:\workAndroid\gradle-user-ascii`는 한글 홈 정션 — 사용 금지 (진짜는 gradle-home-ascii)

## 구조

- `lib/core/` — 엔진 (GameState 플래그 상태머신, 세이브+백업, SceneView, 인벤토리/조합, 3단계 힌트+광고)
- `lib/rooms/roomN_*.dart` — 방 하나 = 파일 하나. 방 추가: 파일 작성 → `rooms.dart` 목록에 추가 → 정답 시퀀스 테스트 필수
- `art/` — Codex 생성 의뢰 문서. 이미지 파일을 `assets/`에 넣으면 코드 수정 없이 반영 (없으면 라벨 색 블록)
- 스펙: `docs/superpowers/specs/`, 계획: `docs/superpowers/plans/`

## 남은 일 (v1 출시까지)

- 방 2~6 (거실·서재·주방·지하실·다락방) — 방마다 별도 콘텐츠 계획
- 현관 아트/효과음 도착 시 핫스팟 좌표를 실제 그림에 맞게 미세조정
- 출시 단계: 실제 AdMob ID 교체, 서명 키, 스토어 등록 (문구에 광고·결제 언급 금지)
```

- [ ] **Step 4: 실기기 확인 안내 (설치는 사용자 요청 시에만)**

APK 경로를 사용자에게 알리고, 폰 연결 후 설치를 원하는지 확인한다. adb를 백그라운드로 대기시키지 말 것. 실기기에서 현관 1회 완주가 이 슬라이스의 최종 수용 기준 (빌드 통과 ≠ 동작 확인).

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "통합 검증: 릴리스 APK 빌드 확인 + README"
```

---

## 계획 밖 (후속 계획에서)

- **방 2~6 콘텐츠 계획** (방마다 1개): 퍼즐 상세 설계 + 방 파일 + 정답 시퀀스 테스트 + 아트 의뢰 문서. 방 5에서 `sensors_plus` 추가(흔들기).
- **출시 계획**: 서명 키 생성, 실제 AdMob 앱/유닛 ID, 스토어 리스팅(스크린샷·문구), 데이터 보안 신고(광고 SDK), 내부 테스트 트랙.
- iOS 빌드: Mac/클라우드 확보 후.
