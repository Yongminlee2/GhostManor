import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
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

  test('정답 시퀀스로 클리어 가능', () {
    expect(room.cleared(s), isFalse);
    solveCellar(s, c, room);
    expect(room.cleared(s), isTrue);
  });

  test('부정: 불 켜기 전 barrel을 탭해도 클로즈업이 열리지 않는다', () {
    tap('cellar_b', 'barrel');
    expect(s.closeupId, isNull);
  });

  test('부정: 불 꺼진 상태에서 dropShelfKey는 no-op', () {
    dropShelfKey(s);
    expect(s.flag('cellar_key_dropped'), 0);
  });

  test('부정: barrel_moved 전에는 small_door 핫스팟이 비활성', () {
    final h = findHotspot(room, 'cellar_b', 'small_door');
    expect(h.when?.call(s) ?? true, isFalse);
  });

  test('부정: 퓨즈 없이 스위치를 탭해도 불은 켜지지 않는다', () {
    tap('cellar_b', 'light_switch');
    expect(s.flag('cellar_light'), 0);
  });

  group('moveBarrel', () {
    test('불 켜진 상태에서 누적되고 100에서 barrel_moved', () {
      s.setFlag('cellar_light', 1);
      moveBarrel(s, 60); // (60/6).round() = 10
      expect(s.flag('cellar_barrel_px'), 10);
      expect(s.flag('cellar_barrel_moved'), 0);
      for (var i = 0; i < 9; i++) {
        moveBarrel(s, 60);
      }
      expect(s.flag('cellar_barrel_px'), 100);
      expect(s.flag('cellar_barrel_moved'), 1);
      moveBarrel(s, 60); // 완료 후에도 100을 넘지 않는다(캡 유지)
      expect(s.flag('cellar_barrel_px'), 100);
    });

    test('불 꺼진 상태에서는 누적되지 않는다', () {
      moveBarrel(s, 600);
      expect(s.flag('cellar_barrel_px'), 0);
      expect(s.flag('cellar_barrel_moved'), 0);
    });
  });

  group('dropShelfKey', () {
    test('불 꺼지면 무시, 켜지면 낙하, 이미 떨어졌으면 재호출해도 안전', () {
      dropShelfKey(s);
      expect(s.flag('cellar_key_dropped'), 0);
      s.setFlag('cellar_light', 1);
      dropShelfKey(s);
      expect(s.flag('cellar_key_dropped'), 1);
      dropShelfKey(s);
      expect(s.flag('cellar_key_dropped'), 1);
    });
  });

  group('tapShelf (연타 폴백)', () {
    test('10회 누적 시 dropShelfKey 호출', () {
      s.setFlag('cellar_light', 1);
      for (var i = 0; i < 9; i++) {
        tapShelf(s);
      }
      expect(s.flag('cellar_shelf_taps'), 9);
      expect(s.flag('cellar_key_dropped'), 0);
      tapShelf(s);
      expect(s.flag('cellar_shelf_taps'), 10);
      expect(s.flag('cellar_key_dropped'), 1);
    });
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['fuse', 'key_cellar', 'note4']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_cellar_light', 'p_cellar_door', 'p_cellar_key']);

    s.setFlag('cellar_light', 1);
    expect(room.hints[0].solved!(s), isTrue);

    s.setFlag('cellar_barrel_moved', 1);
    expect(room.hints[1].solved!(s), isTrue);

    s.setFlag('cellar_got_key', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  testWidgets('선반 위젯: 10연타 → 열쇠 낙하 (센서 경로는 실기기 수동 검증)',
      (t) async {
    s.setFlag('cellar_light', 1);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: ShelfShake(ctx: c))));
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byKey(const Key('shelf_tap')));
      await t.pump();
    }
    expect(s.flag('cellar_key_dropped'), 1);
  });

  testWidgets('와인통 위젯: 드래그 반복 → barrel_moved', (t) async {
    s.setFlag('cellar_light', 1);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: BarrelDrag(ctx: c))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('barrel_drag')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('cellar_barrel_moved'), 1);
  });
}
