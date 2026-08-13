import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/dial_safe.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/memory_player.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room10_lab.dart';
import 'solutions.dart';

void main() {
  late GameState s;
  late GameCtx c;
  late Room room;

  void tap(String sceneId, String hotspotId) =>
      tapSpot(room, s, c, sceneId, hotspotId);

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
    room = buildLab();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveLab(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('병렬 단언: 진입 직후 T1(책장 bookshelf)·T2(칠판 board) 둘 다 반응 가능', () {
    final bookshelf = findHotspot(room, 'lab_a', 'bookshelf');
    final board = findHotspot(room, 'lab_b', 'board');
    expect(bookshelf.when?.call(s) ?? true, isTrue);
    expect(board.when?.call(s) ?? true, isTrue);
    tap('lab_a', 'bookshelf');
    expect(s.has('cylinder1'), isTrue);
  });

  test('벽면 핫스팟 총수 ≥15, 3벽 (하드코어 게이트)', () {
    expect(room.walls.length, 3);
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 축음기 스핀들: 첫 탭은 선택 아이템과 무관하게 항상 추출 ──

  test('스핀들: 실린더3이 꽂힌 채라 첫 탭은 선택 아이템과 무관하게 추출만 한다', () {
    tap('lab_a', 'phono');
    s.select('cylinder1'); // 아직 갖고 있지 않아도 selectedItem 자체는 세팅 가능
    tap('phono', 'spindle');
    expect(s.has('cylinder3'), isTrue);
    expect(s.dialog, strF2LabSpindleExtract);
  });

  test('스핀들: 추출 후 아무것도 선택하지 않고 탭하면 빈 축 반응', () {
    tap('lab_a', 'phono');
    tap('phono', 'spindle'); // 추출
    tap('phono', 'spindle'); // 미선택
    expect(s.dialog, strF2LabSpindleEmpty);
  });

  // ── 관측 장치 기동 후 칠판↔금고 rect 상호 배타 ──

  test('장치 기동 후: board는 비활성, safe가 활성으로 뒤바뀐다(같은 rect 공유)', () {
    final board = findHotspot(room, 'lab_b', 'board');
    final safe = findHotspot(room, 'lab_b', 'safe');
    expect(board.when!.call(s), isTrue);
    expect(safe.when!.call(s), isFalse);

    s.setFlag('f2_lab_b_awake', 1);
    expect(board.when!.call(s), isFalse);
    expect(safe.when!.call(s), isTrue);
  });

  // ── 회상 (Task1 규약: 램프 점등 후 편지 재탭 → 재생, 재열람 가능) ──

  test('램프 점등 전에는 편지 탭해도 빈 편지지 반응뿐, 잉크도 회상도 없다', () {
    tap('lab_c', 'letter');
    expect(s.closeupId, 'letter');
    expect(s.dialog, strF2LabLetterBlank);
    expect(s.flag('f2_lab_letter_ink'), 0);
    expect(s.flag('f2_lab_memory'), 0);
  });

  test('램프 점등 후 첫 편지 탭: 잉크 드러남 + 편지 전문(회상은 아직)', () {
    s.setFlag('f2_lab_c_lamp', 1);
    tap('lab_c', 'letter');
    expect(s.flag('f2_lab_letter_ink'), 1);
    expect(s.dialog, strF2LabLetterFull);
    expect(s.flag('f2_lab_memory'), 0);
    expect(s.closeupId, 'letter');
  });

  test('회상4: 잉크 드러난 뒤 재탭 → 1회 재생(f2_lab_memory=1) + 재열람 가능', () {
    s.setFlag('f2_lab_c_lamp', 1);
    tap('lab_c', 'letter'); // 잉크 드러남
    s.closeCloseup();

    tap('lab_c', 'letter'); // 재탭 → 회상
    expect(s.closeupId, 'memory');
    expect(s.flag('f2_lab_memory'), 1);
    s.closeCloseup();

    tap('lab_c', 'letter'); // 재열람
    expect(s.closeupId, 'memory');
  });

  // ── 부정 테스트 ──

  test('부정: 잠긴 서랍을 맨손(아무것도 선택하지 않고)으로 열면 잠김 대사, 열리지 않는다', () {
    tap('lab_a', 'drawer');
    expect(s.dialog, strF2LabDrawerLocked);
    expect(s.flag('f2_lab_drawer_open'), 0);
    expect(s.has('cylinder2'), isFalse);
  });

  test('부정: 열쇠(key_f2seal) 없이 문을 열면 잠김 대사, 문은 안 열린다', () {
    tap('lab_a', 'door');
    expect(s.dialog, strF2LabDoorLocked);
    expect(s.flag('f2_lab_door_open'), 0);
  });

  test('부정: 칠판을 안 닦아도 약병을 정순서로 부으면 램프는 정상적으로 반응한다(지식-게이트 분리)', () {
    expect(s.flag('f2_lab_board_clean'), 0); // 칠판 미접촉
    s.give('vial_purple');
    s.give('vial_green');
    s.give('vial_amber');

    s.select('vial_purple');
    tap('lab_c', 'lamp');
    s.select('vial_green');
    tap('lab_c', 'lamp');
    s.select('vial_amber');
    tap('lab_c', 'lamp');

    expect(s.flag('f2_lab_c_lamp'), 1);
    expect(s.dialog, strF2LabLampLit);
  });

  test('지식 게이트 아님: 실린더를 하나도 재생해 보지 않아도 다이얼을 241로 맞추면 장치가 깨어난다', () {
    tap('lab_b', 'device');
    void dialTo(int wheel, int times) {
      for (var i = 0; i < times; i++) {
        tapDialWheel(s, 'f2_lab_dial', wheel);
      }
    }

    dialTo(0, 2);
    dialTo(1, 4);
    dialTo(2, 1);
    expect(checkDialCode(s, 'f2_lab_dial', '241'), isTrue);
    awakenDevice(c);
    expect(s.flag('f2_lab_b_awake'), 1);
  });

  test('부정: 약병을 잘못된 순서로 부으면 진행이 리셋되고 전용 대사가 뜬다', () {
    s.give('vial_purple');
    s.give('vial_green');
    s.give('vial_amber');

    s.select('vial_purple');
    tap('lab_c', 'lamp');
    expect(s.flag('f2_lab_lamp_stage'), 1);

    s.select('vial_amber'); // 순서 오답(둘째는 초록이어야 함)
    tap('lab_c', 'lamp');
    expect(s.flag('f2_lab_lamp_stage'), 0);
    expect(s.dialog, strF2LabLampWrong);
    expect(s.flag('f2_lab_c_lamp'), 0);
    expect(s.has('vial_amber'), isTrue, reason: '오답 시 약병은 소모되지 않는다');
  });

  // ── 순수 함수 단위 테스트 ──

  group('pourVial', () {
    test('보라 → 초록 → 호박 순서대로 넣으면 매번 true, 3단계에서 stage가 3에 도달', () {
      expect(pourVial(s, 'vial_purple'), isTrue);
      expect(s.flag('f2_lab_lamp_stage'), 1);
      expect(pourVial(s, 'vial_green'), isTrue);
      expect(s.flag('f2_lab_lamp_stage'), 2);
      expect(pourVial(s, 'vial_amber'), isTrue);
      expect(s.flag('f2_lab_lamp_stage'), 3);
    });

    test('첫 순서부터 틀리면 false + stage 0 유지', () {
      expect(pourVial(s, 'vial_green'), isFalse);
      expect(s.flag('f2_lab_lamp_stage'), 0);
    });

    test('둘째 순서에서 틀리면 false + stage가 0으로 리셋', () {
      pourVial(s, 'vial_purple');
      expect(pourVial(s, 'vial_amber'), isFalse);
      expect(s.flag('f2_lab_lamp_stage'), 0);
    });

    test('약병이 아닌 아이템/미선택은 false, 진행은 건드리지 않는다', () {
      pourVial(s, 'vial_purple');
      expect(pourVial(s, 'cylinder1'), isFalse);
      expect(pourVial(s, null), isFalse);
      expect(s.flag('f2_lab_lamp_stage'), 1, reason: '관계없는 아이템은 진행을 리셋하지 않는다');
    });

    test('이미 3단계 완료 후 추가 투입은 false(변화 없음)', () {
      pourVial(s, 'vial_purple');
      pourVial(s, 'vial_green');
      pourVial(s, 'vial_amber');
      expect(pourVial(s, 'vial_purple'), isFalse);
      expect(s.flag('f2_lab_lamp_stage'), 3);
    });
  });

  // ── 등록·힌트 ──

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in [
      'cylinder1',
      'cylinder2',
      'cylinder3',
      'keyring',
      'vial_purple',
      'vial_green',
      'vial_amber',
      'key_f2seal',
      'emblem_lab',
    ]) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('closeups의 key는 Scene.id와 일치(모델 assert가 이미 강제하지만 명시적으로도 확인)', () {
    for (final entry in room.closeups.entries) {
      expect(entry.key, entry.value.id);
    }
  });

  test('힌트 3개: p_f2_lab_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_f2_lab_dial', 'p_f2_lab_ink', 'p_f2_lab_safe']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('f2_lab_b_awake', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('f2_lab_c_lamp', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('f2_lab_seal_taken', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  // ── 위젯 테스트 ──

  testWidgets('칠판 위젯(RubbableScene): 드래그를 반복하면 닦인다', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) => room.closeups['board']!.custom!(context, c)))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('board_rub')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('f2_lab_board_clean'), 1);
  });

  testWidgets('다이얼 위젯(room 배선): 241로 맞추고 확인 → 장치 기동, 재확인해도 1회만',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) => room.closeups['device']!.custom!(context, c)))));

    Future<void> dial(int wheel, int times) async {
      for (var i = 0; i < times; i++) {
        await t.tap(find.byKey(Key('dial_wheel_$wheel')));
        await t.pump();
      }
    }

    await dial(0, 2);
    await dial(1, 4);
    await dial(2, 1);
    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();

    expect(s.flag('f2_lab_b_awake'), 1);
    expect(s.dialog, strF2LabDeviceAwake);

    await t.tap(find.byKey(const Key('dial_confirm'))); // 재확인해도 중복 지급 없음
    await t.pump();
    expect(s.flag('f2_lab_b_awake'), 1);
  });

  testWidgets('다이얼 위젯(room 배선): 오답 코드로 확인 → 개방 안 되고 전문 대사 + 휠 전체 리셋',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) => room.closeups['device']!.custom!(context, c)))));

    for (var i = 0; i < 5; i++) {
      await t.tap(find.byKey(const Key('dial_wheel_0')));
      await t.pump();
    } // 휠0=5, 나머지 0 → 241이 아님

    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();

    expect(s.flag('f2_lab_b_awake'), 0);
    expect(s.has('key_f2seal'), isFalse);
    expect(s.dialog, strF2LabDialWrong);
    expect(s.flag('f2_lab_dial_d0'), 0); // 오답 후 리셋
  });

  testWidgets('회상 위젯: 편지 앵커로 열린 MemoryPlayer가 3페이지를 넘기고 닫힌다', (t) async {
    s.setFlag('f2_lab_c_lamp', 1);
    tap('lab_c', 'letter');
    s.closeCloseup();
    tap('lab_c', 'letter');
    expect(s.closeupId, 'memory');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
                builder: (context) => room.closeups['memory']!.custom!(context, c)))));
    await t.pump();
    expect(find.text(strF2Mem4p1), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem4p2), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem4p3), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer)); // 마지막 페이지 탭 → onDone → closeCloseup
    await t.pump();
    expect(s.closeupId, isNull);
  });
}
