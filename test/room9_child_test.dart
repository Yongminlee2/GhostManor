import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/memory_player.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/scene_view.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room9_child.dart';
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
    room = buildChild();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveChild(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('병렬 단언: 진입 직후 T1(모빌)·T2(오르골 태엽 감기) 둘 다 반응 가능', () {
    final mobile = findHotspot(room, 'child_a', 'mobile');
    final musicBox = findHotspot(room, 'child_c', 'music_box');
    expect(mobile.when?.call(s) ?? true, isTrue);
    expect(musicBox.when?.call(s) ?? true, isTrue);
    tap('child_c', 'music_box');
    expect(s.flag('f2_child_organ_wound'), 1);
  });

  test('벽면 핫스팟 총수 ≥15, 3벽 (하드코어 게이트)', () {
    expect(room.walls.length, 3);
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 회상 (Task1 규약: 핵심 해결 후 오르골 앵커 탭 → 재생, 재열람 가능) ──

  test('오르골 수리 전에는 탭해도 태엽만 감기고 회상은 재생되지 않는다', () {
    tap('child_c', 'music_box');
    expect(s.flag('f2_child_organ_wound'), 1);
    expect(s.flag('f2_child_memory'), 0);
    expect(s.closeupId, isNull);
  });

  test('회상: 오르골 수리 후 재탭 → 1회 재생(f2_child_memory=1) + 재열람 가능', () {
    s.setFlag('f2_child_organ_wound', 1);
    tap('child_c', 'music_box');
    expect(s.closeupId, 'organ');

    s.give('gear_toy');
    s.select('gear_toy');
    tap('organ', 'fix');
    expect(s.flag('f2_child_organ_fixed'), 1);
    s.closeCloseup();

    tap('child_c', 'music_box');
    expect(s.closeupId, 'memory');
    expect(s.flag('f2_child_memory'), 1);
    s.closeCloseup();

    // 재열람: 다시 탭해도 memory로 열린다(오르골 앵커).
    tap('child_c', 'music_box');
    expect(s.closeupId, 'memory');
  });

  // ── 부정 테스트 ──

  test('부정: 스위치가 틀린 채 기차를 출발시키면 전문 대사 + 스위치는 유지(재조정 가능)', () {
    tap('child_b', 'switch1'); // 인덱스0: 0→1 (정답은 0 — 틀림)
    expect(s.flag('f2_child_sw0'), 1);
    tap('child_b', 'train_start');
    expect(s.dialog, strF2ChildTrainFail);
    expect(s.flag('f2_child_train'), 0);
    expect(s.flag('f2_child_sw0'), 1, reason: '실패해도 스위치 상태는 리셋되지 않는다');
  });

  test('부정: 기차 실패 시 SceneObject rect가 원위치를 유지한다(애초에 트랙을 떠난 적이 없다)', () {
    final wallB = room.walls.firstWhere((w) => w.id == 'child_b');
    final trainObj = wallB.objects.first;
    final before = trainObj.area(s);
    tap('child_b', 'train_start'); // 스위치 기본값(전부 왼쪽)이라 실패
    expect(s.flag('f2_child_train'), 0);
    expect(trainObj.area(s), before);
  });

  test(
      '지식 게이트 아님: 모빌(child_a)을 한 번도 보지 않아도 스위치가 좌·우·좌면 기차가 성공한다'
      '(현관 편지와 동일 원칙)', () {
    tap('child_b', 'switch2'); // 인덱스1(가운데)만 오른쪽으로
    tap('child_b', 'train_start');
    expect(s.flag('f2_child_train'), 1);
  });

  test('부정: gear_toy 없이 오르골 내부를 조작해도 고쳐지지 않는다', () {
    tap('child_c', 'music_box'); // 태엽 감기
    tap('child_c', 'music_box'); // 내부 클로즈업
    expect(s.closeupId, 'organ');
    tap('organ', 'fix'); // 선택 아이템 없음
    expect(s.flag('f2_child_organ_fixed'), 0);
    expect(s.dialog, strF2ChildOrganNeedsGear);
  });

  test('부정: 열쇠 없이 문을 열면 잠김 대사(문은 안 열림)', () {
    tap('child_a', 'door');
    expect(s.dialog, strF2ChildDoorLocked);
    expect(s.flag('f2_child_door_open'), 0);
  });

  test('부정: 기차 성공 전에는 drawer 핫스팟이 비활성', () {
    final h = findHotspot(room, 'child_b', 'drawer');
    expect(h.when?.call(s) ?? true, isFalse);
  });

  // ── 서랍(찬장 콜백 — 두 번째 탭에서 지급) ──

  test('서랍: 1차는 반짝임 발견(미지급), 2차에 gear_toy 지급, 3차는 이미 빈 서랍', () {
    s.setFlag('f2_child_train', 1); // 사전조건: 기차 성공(서랍 노출)
    tap('child_b', 'drawer');
    expect(s.flag('f2_child_gear_found'), 1);
    expect(s.has('gear_toy'), isFalse);

    tap('child_b', 'drawer');
    expect(s.has('gear_toy'), isTrue);
    expect(s.dialog, strF2ChildDrawerGive);

    tap('child_b', 'drawer');
    expect(s.dialog, strF2ChildDrawerEmpty);
  });

  // ── 순수 함수 단위 테스트 ──

  group('childSwitchesSolved / tapChildSwitch', () {
    test('초기 상태(전부 왼쪽)는 오답', () {
      expect(childSwitchesSolved(s), isFalse);
    });

    test('가운데(인덱스1)만 오른쪽이면 정답', () {
      tapChildSwitch(s, 1);
      expect(childSwitchesSolved(s), isTrue);
    });

    test('토글이라 몇 번을 넘겼다 되돌려도 최종 상태만 본다', () {
      tapChildSwitch(s, 0);
      tapChildSwitch(s, 2);
      tapChildSwitch(s, 1);
      tapChildSwitch(s, 0); // 원복
      tapChildSwitch(s, 2); // 원복
      expect(childSwitchesSolved(s), isTrue);
    });

    test('정답 상태에서 다시 건드리면 즉시 오답으로 바뀐다(별도 게이트 플래그 없음 — train 성공 여부만 남는다)', () {
      tapChildSwitch(s, 1);
      expect(childSwitchesSolved(s), isTrue);
      tapChildSwitch(s, 0);
      expect(childSwitchesSolved(s), isFalse);
    });
  });

  // ── 등록·힌트 ──

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['gear_toy', 'key_f2lab', 'emblem_child']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('closeups의 key는 Scene.id와 일치(모델 assert가 이미 강제하지만 명시적으로도 확인)', () {
    for (final entry in room.closeups.entries) {
      expect(entry.key, entry.value.id);
    }
  });

  test('힌트 3개: p_f2_child_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_f2_child_train', 'p_f2_child_organ', 'p_f2_child_door']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('f2_child_train', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('f2_child_organ_fixed', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('f2_child_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  // ── 위젯 테스트 ──

  testWidgets(
      '기차 SceneObject: f2_child_train 전환 시 AnimatedPositioned가 실이동'
      '(트윈, 점프 아님 — cellar 통 테스트 스타일)', (t) async {
    s.goScene(1); // child_b — 위젯 첫 빌드 전에 설정해 벽 전환 슬라이드를 건너뜀
    await t.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(width: 400, height: 600, child: SceneView(room: room, ctx: c)))));
    await t.pump();

    const trainKey = ValueKey('assets/scenes/train_sprite.png');
    final origin = t.getTopLeft(find.byType(SceneView));
    final start = origin + const Offset(0.30 * 400, 0.83 * 600);
    final end = origin + const Offset(0.373 * 400, 0.342 * 600);

    expect(t.getTopLeft(find.byKey(trainKey)), offsetMoreOrLessEquals(start, epsilon: 2.0));

    s.setFlag('f2_child_train', 1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final mid = t.getTopLeft(find.byKey(trainKey));
    // end는 start보다 오른쪽(트랙이 우상단 터널로 굽는다)·위쪽 — 중간 지점은
    // 그 사이여야 한다(트윈, 순간 이동 아님).
    expect(mid.dx, greaterThan(start.dx));
    expect(mid.dx, lessThan(end.dx));
    expect(mid.dy, lessThan(start.dy));
    expect(mid.dy, greaterThan(end.dy));

    await t.pump(const Duration(milliseconds: 400)); // 누적 700ms > duration(600ms)
    expect(t.getTopLeft(find.byKey(trainKey)), offsetMoreOrLessEquals(end, epsilon: 2.0));
  });

  testWidgets('회상 위젯: 오르골 앵커로 열린 MemoryPlayer가 2페이지를 넘기고 닫힌다(회상3은 2페이지)', (t) async {
    s.setFlag('f2_child_organ_fixed', 1);
    tap('child_c', 'music_box');
    expect(s.closeupId, 'memory');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
                builder: (context) => room.closeups['memory']!.custom!(context, c)))));
    await t.pump();
    expect(find.text(strF2Mem3p1), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem3p2), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer)); // 마지막(2번째) 페이지 탭 → onDone → closeCloseup
    await t.pump();
    expect(s.closeupId, isNull);
  });
}
