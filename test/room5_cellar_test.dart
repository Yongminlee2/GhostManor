import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/scene_view.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/core/switch_panel.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room5_cellar.dart';
import 'solutions.dart';

// sensors_plus는 실기기 플랫폼 채널이 필요 — flutter_test(호스트 VM)엔 구현체가 없어
// EventChannel의 'listen' 호출이 실패하면 FlutterError.reportError로 보고돼 위젯
// 테스트가 실패한다(예외가 스트림 onError로 전달되는 게 아니라 채널 활성화 실패로
// 보고되는 SDK 동작 — platform_channel.dart 확인). 두 채널을 무해한 응답으로
// 목(mock) 처리해 ShelfShake의 initState 구독 시도가 조용히 지나가게 한다. 실제
// 흔들기 이벤트는 안 보내므로 이 목은 탭 폴백 경로에만 영향 없음(센서 경로는
// 실기기 수동 검증 대상 — 브리프 지시).
const _sensorsMethodChannel = MethodChannel('dev.fluttercommunity.plus/sensors/method');
const _userAccelChannel = MethodChannel('dev.fluttercommunity.plus/sensors/user_accel');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sensorsMethodChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_userAccelChannel, (call) async => null);
  });

  late GameState s;
  late GameCtx c;
  late Room room;

  void tap(String sceneId, String hotspotId) =>
      tapSpot(room, s, c, sceneId, hotspotId);

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
    room = buildCellar();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveCellar(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('어둠 왕복 최소 2회가 정답 시퀀스에 실재한다(소등↔점등 전환 실측)', () {
    final lightHistory = <int>[];
    var last = 0;
    s.addListener(() {
      final cur = s.flag('cellar_r_light');
      if (cur != last) {
        lightHistory.add(cur);
        last = cur;
      }
    });
    solveCellar(s, c, room);
    final wentToLight = lightHistory.where((v) => v == 1).length;
    expect(wentToLight, greaterThanOrEqualTo(2),
        reason: '소등→점등 전환이 2회 미만 — 어둠 왕복 설계 위반. 기록: $lightHistory');
    expect(lightHistory, contains(0),
        reason: '중간에 실제로 다시 어두워진 적이 없다면 "왕복"이 아니다. 기록: $lightHistory');
  });

  test('병렬 단언: 진입 직후(어둠) 상자A 야광·배전반 옆 낙서·랙 옆 낙서 셋 다 확인 가능', () {
    final glowBox = findHotspot(room, 'cellar_a', 'glow_box');
    expect(glowBox.when?.call(s) ?? true, isTrue);

    final wallB = room.walls.firstWhere((w) => w.id == 'cellar_b');
    final glow2 = wallB.overlays.firstWhere((o) => o.image.contains('glow2'));
    expect(glow2.when(s), isTrue);

    final wallC = room.walls.firstWhere((w) => w.id == 'cellar_c');
    final glow3 = wallC.overlays.firstWhere((o) => o.image.contains('glow3'));
    expect(glow3.when(s), isTrue);
  });

  test('벽면 핫스팟 총수 ≥15 (하드코어 게이트)', () {
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 부정 테스트 (브리프 6종) ──

  test('부정: 어두우면 병 라벨을 읽을 수 없다(시퀀스 진행 없음)', () {
    tap('cellar_c', 'wine3'); // 프레시 상태는 소등
    expect(s.dialog, strCellarRWineDark);
    expect(s.flag('cellar_r_wine_seq'), 0);
  });

  test('부정: 병 순서를 틀리면 리셋 + 브리프 오답 대사 그대로', () {
    s.setFlag('cellar_r_light', 1); // 라벨 판독은 점등 필수
    tap('cellar_c', 'wine3'); // 촛불 5개 — 정답 1단계
    expect(s.flag('cellar_r_wine_seq'), 1);
    tap('cellar_c', 'wine4'); // 촛불 2개 — 정답 2단계(1)가 아니라 오답
    expect(s.flag('cellar_r_wine_seq'), 0);
    expect(s.dialog, strCellarRWineWrong);
    expect(s.flag('cellar_r_wine_open'), 0);
  });

  test(
      '지식 게이트 아님: 낙서(glow3)를 본 적 없어도 5→1→3 순서로 탭하면 상자B가 열린다'
      '(현관 편지와 동일 원칙) — 판정은 병 위치가 아니라 라벨 촛불 개수 값',
      () {
    s.setFlag('cellar_r_light', 1); // 라벨 판독은 점등 필수
    tap('cellar_c', 'wine3'); // 5
    tap('cellar_c', 'wine2'); // 1
    tap('cellar_c', 'wine5'); // 3 — 리터치 후 촛불 3개는 wine5뿐(wine1은 4개)
    expect(s.flag('cellar_r_wine_open'), 1);
  });

  test('부정: 퓨즈 1개로 스위치 조작을 시도해도 클로즈업이 열리지 않는다', () {
    s.give('fuse');
    s.select('fuse');
    tap('cellar_b', 'fusebox'); // 삽입 → count=1
    expect(s.flag('cellar_r_fuse_count'), 1);
    tap('cellar_b', 'fusebox'); // 아직 부족한 상태에서 재탭(선택 아이템 없음)
    expect(s.closeupId, isNull);
    expect(s.dialog, strCellarRFuseboxOneMore);
  });

  test('부정: 스위치를 틀린 순서로 올리면 파직 리액션(사운드는 switch_click 재사용) + 리셋', () {
    flipSwitch(s, 'cellar_r_switch', 0); // △ — 정답 1단계
    expect(s.flag('cellar_r_switch_seq'), 1);
    flipSwitch(s, 'cellar_r_switch', 0); // 오답(다음 정답은 1=○)
    expect(s.flag('cellar_r_switch_seq'), 0);
    expect(s.flag('cellar_r_power'), 0);
  });

  test('부정: 어두운 상태에서 barrel을 탭해도 클로즈업이 열리지 않는다(전용 리액션)', () {
    tap('cellar_b', 'barrel');
    expect(s.closeupId, isNull);
    expect(s.dialog, strCellarTooDark);
  });

  test('부정: barrel_moved 전에는 small_door 핫스팟이 비활성', () {
    final h = findHotspot(room, 'cellar_b', 'small_door');
    expect(h.when?.call(s) ?? true, isFalse);
  });

  test('부정: 열쇠 없이 쪽문을 탭하면 잠김 대사(통은 이미 민 상태로 설정)', () {
    s.setFlag('cellar_r_barrel_moved', 1);
    tap('cellar_b', 'small_door');
    expect(s.flag('cellar_r_door_open'), 0);
    expect(s.dialog, strCellarDoorLocked);
  });

  // ── 설계 판단 검증: 전력 복구가 쪽문의 실질 관문(SwitchPanel 우회 불가) ──
  test('설계 판단: 열쇠로 잠금은 풀려도 전력 복구(cellar_r_power) 전에는 탈출할 수 없다', () {
    s.setFlag('cellar_r_barrel_moved', 1);
    s.give('key_cellar');
    s.select('key_cellar');
    tap('cellar_b', 'small_door'); // 잠금 해제
    expect(s.flag('cellar_r_door_open'), 1);
    tap('cellar_b', 'small_door'); // power=0 — 아직 못 나감
    expect(s.flag('cellar_r_done'), 0);
    expect(s.dialog, strCellarRExitNeedsPower);
    s.setFlag('cellar_r_power', 1);
    tap('cellar_b', 'small_door'); // 이제 탈출
    expect(s.flag('cellar_r_done'), 1);
  });

  group('moveBarrel', () {
    test('불 켜진 상태에서 누적되고 100에서 barrel_moved', () {
      s.setFlag('cellar_r_light', 1);
      moveBarrel(s, 60); // (60/6).round() = 10
      expect(s.flag('cellar_r_barrel_px'), 10);
      expect(s.flag('cellar_r_barrel_moved'), 0);
      for (var i = 0; i < 9; i++) {
        moveBarrel(s, 60);
      }
      expect(s.flag('cellar_r_barrel_px'), 100);
      expect(s.flag('cellar_r_barrel_moved'), 1);
      moveBarrel(s, 60); // 완료 후에도 100을 넘지 않는다(캡 유지)
      expect(s.flag('cellar_r_barrel_px'), 100);
    });

    test('불 꺼진 상태에서는 누적되지 않는다', () {
      moveBarrel(s, 600);
      expect(s.flag('cellar_r_barrel_px'), 0);
      expect(s.flag('cellar_r_barrel_moved'), 0);
    });
  });

  group('dropShelfKey', () {
    test('불 꺼지면 무시, 켜지면 낙하, 이미 떨어졌으면 재호출해도 안전', () {
      dropShelfKey(s);
      expect(s.flag('cellar_r_key_dropped'), 0);
      s.setFlag('cellar_r_light', 1);
      dropShelfKey(s);
      expect(s.flag('cellar_r_key_dropped'), 1);
      dropShelfKey(s);
      expect(s.flag('cellar_r_key_dropped'), 1);
    });
  });

  group('tapShelf (연타 폴백)', () {
    test('10회 누적 시 dropShelfKey 호출', () {
      s.setFlag('cellar_r_light', 1);
      for (var i = 0; i < 9; i++) {
        tapShelf(s);
      }
      expect(s.flag('cellar_r_shelf_taps'), 9);
      expect(s.flag('cellar_r_key_dropped'), 0);
      tapShelf(s);
      expect(s.flag('cellar_r_shelf_taps'), 10);
      expect(s.flag('cellar_r_key_dropped'), 1);
    });
  });

  group('tapWine', () {
    test('정답 순서(5,1,3)대로면 seq가 1씩 증가하고 3단계에서 wine_open', () {
      tapWine(s, 5);
      expect(s.flag('cellar_r_wine_seq'), 1);
      tapWine(s, 1);
      expect(s.flag('cellar_r_wine_seq'), 2);
      tapWine(s, 3);
      expect(s.flag('cellar_r_wine_seq'), 3);
      expect(s.flag('cellar_r_wine_open'), 1);
    });

    test('틀린 개수를 탭하면 seq가 0으로 리셋된다', () {
      tapWine(s, 5);
      tapWine(s, 3); // 2단계 정답은 1인데 3
      expect(s.flag('cellar_r_wine_seq'), 0);
    });

    test('wine_open 후에는 no-op', () {
      tapWine(s, 5);
      tapWine(s, 1);
      tapWine(s, 3);
      expect(s.flag('cellar_r_wine_open'), 1);
      tapWine(s, 5); // 완료 후 재호출
      expect(s.flag('cellar_r_wine_seq'), 3); // 그대로 — no-op
    });
  });

  group('flipSwitch', () {
    test('정답 순서(0,1,2 = △○□)대로면 seq가 1씩 증가하고 3단계에서 cellar_r_power', () {
      flipSwitch(s, 'cellar_r_switch', 0);
      expect(s.flag('cellar_r_switch_seq'), 1);
      flipSwitch(s, 'cellar_r_switch', 1);
      expect(s.flag('cellar_r_switch_seq'), 2);
      flipSwitch(s, 'cellar_r_switch', 2);
      expect(s.flag('cellar_r_switch_seq'), 3);
      expect(s.flag('cellar_r_power'), 1);
    });

    test('틀린 스위치를 탭하면 seq가 0으로 리셋된다', () {
      flipSwitch(s, 'cellar_r_switch', 0);
      flipSwitch(s, 'cellar_r_switch', 2); // 2단계 정답은 1인데 2
      expect(s.flag('cellar_r_switch_seq'), 0);
    });

    test('power 복구 후에는 no-op', () {
      flipSwitch(s, 'cellar_r_switch', 0);
      flipSwitch(s, 'cellar_r_switch', 1);
      flipSwitch(s, 'cellar_r_switch', 2);
      expect(s.flag('cellar_r_power'), 1);
      flipSwitch(s, 'cellar_r_switch', 0); // 완료 후 재호출
      expect(s.flag('cellar_r_switch_seq'), 3); // 그대로 — no-op
    });
  });

  test('배전반: 퓨즈 2개를 순서대로 끼우면 fuse_count가 1→2로 오르고 각 단계 대사가 나온다', () {
    s.give('fuse');
    s.select('fuse');
    tap('cellar_b', 'fusebox');
    expect(s.flag('cellar_r_fuse_count'), 1);
    expect(s.dialog, strCellarRFuse1In);
    expect(s.has('fuse'), isFalse);

    s.give('fuse2');
    s.select('fuse2');
    tap('cellar_b', 'fusebox');
    expect(s.flag('cellar_r_fuse_count'), 2);
    expect(s.dialog, strCellarRFuse2In);
    expect(s.has('fuse2'), isFalse);
  });

  test('부정: 퓨즈 없이 light_switch를 탭해도 불은 켜지지 않는다', () {
    tap('cellar_b', 'light_switch');
    expect(s.flag('cellar_r_light'), 0);
    expect(s.dialog, strCellarSwitchDead);
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['fuse', 'fuse2', 'key_cellar', 'note4']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('fuse2는 fuse.png 아이콘을 공유한다(신규 아이콘 없음 — 아트 의뢰서 비고)', () {
    expect(itemsById['fuse2']!.icon, 'assets/items/fuse.png');
  });

  test('힌트 3개: p_cellar_r_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_cellar_r_power', 'p_cellar_r_wine', 'p_cellar_r_exit']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('cellar_r_power', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('cellar_r_wine_open', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('cellar_r_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  testWidgets('선반 위젯: 10연타 → 열쇠 낙하 (센서 경로는 실기기 수동 검증)',
      (t) async {
    s.setFlag('cellar_r_light', 1);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: ShelfShake(ctx: c))));
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byKey(const Key('shelf_tap')));
      await t.pump();
    }
    expect(s.flag('cellar_r_key_dropped'), 1);
  });

  testWidgets('와인통 위젯: 드래그 반복 → barrel_moved', (t) async {
    s.setFlag('cellar_r_light', 1);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: BarrelDrag(ctx: c))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('barrel_drag')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('cellar_r_barrel_moved'), 1);
  });

  testWidgets('SwitchPanel 위젯: 정답 순서 탭 → 점등 대사, 오답 탭 → 파직 대사 + 리셋', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: SwitchPanel(ctx: c))));
    await t.tap(find.byKey(const Key('switch_0'))); // △ 정답
    await t.pump();
    expect(s.flag('cellar_r_switch_seq'), 1);

    await t.tap(find.byKey(const Key('switch_0'))); // 오답(같은 스위치 재탭)
    await t.pump();
    expect(s.flag('cellar_r_switch_seq'), 0);
    expect(s.dialog, strCellarRSwitchWrong);

    await t.tap(find.byKey(const Key('switch_0')));
    await t.tap(find.byKey(const Key('switch_1')));
    await t.tap(find.byKey(const Key('switch_2')));
    await t.pump();
    expect(s.flag('cellar_r_power'), 1);
    expect(s.dialog, strCellarLightOn);
  });

  testWidgets(
      '통 SceneObject: cellar_r_barrel_moved 전환 시 AnimatedPositioned가 실이동'
      '(트윈, 점프 아님 — scene_view_test 스타일)', (t) async {
    s.goScene(1); // cellar_b — 위젯 첫 빌드 전에 설정해 벽 전환 슬라이드를 건너뜀
    await t.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(width: 400, height: 600, child: SceneView(room: room, ctx: c)))));
    await t.pump();

    const barrelKey = ValueKey('assets/scenes/cellar_barrel_sprite.png');
    final origin = t.getTopLeft(find.byType(SceneView));
    final start = origin + const Offset(0.30 * 400, 0.40 * 600); // (120, 240)
    final end = origin + const Offset(0.80 * 400, 0.40 * 600); // (320, 240)

    expect(t.getTopLeft(find.byKey(barrelKey)), offsetMoreOrLessEquals(start, epsilon: 2.0));

    s.setFlag('cellar_r_barrel_moved', 1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final mid = t.getTopLeft(find.byKey(barrelKey));
    expect(mid.dx, greaterThan(start.dx));
    expect(mid.dx, lessThan(end.dx));
    expect(mid.dy, closeTo(start.dy, 2.0)); // y는 변하지 않음(수평 이동만)

    await t.pump(const Duration(milliseconds: 400)); // 누적 700ms > duration(600ms)
    expect(t.getTopLeft(find.byKey(barrelKey)), offsetMoreOrLessEquals(end, epsilon: 2.0));
  });
}
