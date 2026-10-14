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
        ], idles: [
          IdleSprite(
              image: 'assets/scenes/idle_ghost.png',
              area: const Rect.fromLTWH(0.05, 0.05, 0.15, 0.15),
              when: (s) => s.flag('idle_on') == 1),
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
          Hotspot(
              id: 'give_candle',
              area: const Rect.fromLTWH(0.02, 0.85, 0.12, 0.12),
              onTap: (c) => c.give('candle')),
        ]),
        Scene(id: 'b', image: 'assets/scenes/wall_b.png'),
      ],
      closeups: {
        'cu': Scene(id: 'cu', image: 'assets/scenes/cu.png'),
      },
    );

Room _objRoom(List<SceneObject> objects) => Room(
      id: 'to',
      name: '오브젝트테스트',
      cleared: (s) => false,
      walls: [
        Scene(id: 'oa', image: 'assets/scenes/wall_a.png', objects: objects),
      ],
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

  testWidgets('새 탭·벽 이동은 지난 대사를 걷는다(새 대사는 그대로 보인다)', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    final origin = t.getTopLeft(find.byType(SceneView));
    s.say('지난 대사');
    await t.pump();
    await t.tapAt(origin + const Offset(10, 10)); // 빈 곳
    await t.pump();
    expect(s.dialog, isNull);
    s.say('지난 대사');
    await t.pump();
    await t.tap(find.byKey(const Key('arrow_right')));
    await t.pump();
    expect(s.dialog, isNull);
  });

  testWidgets('빈 곳 탭은 무반응', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    final origin = t.getTopLeft(find.byType(SceneView));
    await t.tapAt(origin + const Offset(10, 10)); // (0.025, 0.017)
    await t.pump();
    expect(s.flag('tapped'), 0);
  });

  testWidgets('화살표는 경계에서 잘림(순환 없음), 클로즈업 열면 둘 다 숨김+X로 닫기',
      (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    expect(find.byKey(const Key('arrow_left')), findsNothing);
    expect(find.byKey(const Key('arrow_right')), findsOneWidget);
    await t.tap(find.byKey(const Key('arrow_right')));
    await t.pump();
    expect(s.sceneIndex, 1);
    expect(find.byKey(const Key('arrow_right')), findsNothing);
    expect(find.byKey(const Key('arrow_left')), findsOneWidget);
    await t.tap(find.byKey(const Key('arrow_left')));
    await t.pump();
    expect(s.sceneIndex, 0);
    s.openCloseup('cu');
    await t.pump();
    expect(find.byKey(const Key('arrow_left')), findsNothing);
    expect(find.byKey(const Key('arrow_right')), findsNothing);
    await t.tap(find.byKey(const Key('closeup_close')));
    await t.pump();
    expect(s.closeupId, isNull);
  });

  testWidgets('리플 레이어가 있어도 핫스팟 탭은 정상 처리된다', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    final origin = t.getTopLeft(find.byType(SceneView));
    await t.tapAt(origin + const Offset(200, 300)); // (0.5, 0.5) → 'big' 핫스팟
    await t.pump();
    expect(s.flag('tapped'), 1);
    expect(find.byType(SceneView), findsOneWidget);
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
    await t.pump(); // 새로 마운트된 오버레이 이미지의 errorBuilder 해석에 한 프레임 더 필요
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

  testWidgets('유령 둥실(IdleSprite): cond 충족시에만 렌더 + 에셋 없으면 파일명 라벨', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    await t.pump();
    expect(find.text('idle_ghost.png'), findsNothing);
    s.setFlag('idle_on', 1);
    await t.pump();
    await t.pump(); // 새로 마운트된 이미지의 errorBuilder 해석에 한 프레임 더 필요
    expect(find.text('idle_ghost.png'), findsOneWidget);
  });

  testWidgets('아이템 지급 시 인벤토리로 날아가는 연출이 나타났다 사라진다', (t) async {
    await pump(t, SceneView(room: _testRoom(), ctx: c));
    final origin = t.getTopLeft(find.byType(SceneView));
    await t.tapAt(origin + const Offset(32, 546)); // (0.08, 0.91) → give_candle
    await t.pump();
    expect(s.has('candle'), isTrue);
    expect(find.byKey(const ValueKey('fly_1')), findsOneWidget);
    await t.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('fly_1')), findsNothing);
  });

  testWidgets('인벤토리: 레지스트리에 없는 id(구세이브 잔재)는 건너뛰고 렌더가 산다', (t) async {
    s.give('candle');
    s.inventory.add('ghost_soup'); // 제거된 구세대 아이템 id를 세이브 잔재처럼 주입
    await pump(t, InventoryBar(ctx: c));
    expect(find.byKey(const Key('inv_candle')), findsOneWidget);
    expect(find.byKey(const Key('inv_ghost_soup')), findsNothing);
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

  testWidgets('SceneObject: visible 조건 위양성/위음성 + 없는 에셋은 파일명 라벨', (t) async {
    final room = _objRoom([
      SceneObject(
        image: 'assets/scenes/obj_test.png',
        area: (s) => const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2),
        visible: (s) => s.flag('obj_visible') == 1,
      ),
    ]);
    await pump(t, SceneView(room: room, ctx: c));
    await t.pump();
    expect(find.text('obj_test.png'), findsNothing);
    s.setFlag('obj_visible', 1);
    await t.pump();
    await t.pump(); // 새로 마운트된 이미지의 errorBuilder 해석에 한 프레임 더 필요
    expect(find.text('obj_test.png'), findsOneWidget);
  });

  testWidgets('SceneObject: 플래그로 area가 바뀌면 AnimatedPositioned로 실이동(트윈, 점프 아님)',
      (t) async {
    const rectA = Rect.fromLTWH(0.1, 0.1, 0.2, 0.2);
    const rectB = Rect.fromLTWH(0.6, 0.6, 0.2, 0.2);
    final room = _objRoom([
      SceneObject(
        image: 'assets/scenes/obj_move.png',
        area: (s) => s.flag('obj_moved') == 1 ? rectB : rectA,
      ),
    ]);
    await pump(t, SceneView(room: room, ctx: c));
    await t.pump();
    final origin = t.getTopLeft(find.byType(SceneView));
    final start = origin + const Offset(40, 60); // rectA @ 400x600 박스
    final end = origin + const Offset(240, 360); // rectB @ 400x600 박스
    expect(t.getTopLeft(find.byType(AnimatedPositioned)),
        offsetMoreOrLessEquals(start, epsilon: 1.0));

    s.setFlag('obj_moved', 1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final mid = t.getTopLeft(find.byType(AnimatedPositioned));
    expect(mid.dx, greaterThan(start.dx));
    expect(mid.dx, lessThan(end.dx));
    expect(mid.dy, greaterThan(start.dy));
    expect(mid.dy, lessThan(end.dy));

    await t.pump(const Duration(milliseconds: 400)); // 누적 700ms > duration(600ms)
    expect(t.getTopLeft(find.byType(AnimatedPositioned)),
        offsetMoreOrLessEquals(end, epsilon: 1.0));
  });

  testWidgets(
      'SceneObject 2개(같은 씬): image 기반 key로 서로 다른 실이동 목적지에 각자 도달(상태 혼선 방지, study_r_globe 첫 사례)',
      (t) async {
    const leftClosed = Rect.fromLTWH(0.10, 0.10, 0.15, 0.15);
    const leftOpen = Rect.fromLTWH(0.02, 0.10, 0.15, 0.15);
    const rightClosed = Rect.fromLTWH(0.30, 0.10, 0.15, 0.15);
    const rightOpen = Rect.fromLTWH(0.40, 0.10, 0.15, 0.15);
    final room = _objRoom([
      SceneObject(
        image: 'assets/scenes/obj_left.png',
        area: (s) => s.flag('opened') == 1 ? leftOpen : leftClosed,
      ),
      SceneObject(
        image: 'assets/scenes/obj_right.png',
        area: (s) => s.flag('opened') == 1 ? rightOpen : rightClosed,
      ),
    ]);
    await pump(t, SceneView(room: room, ctx: c));
    await t.pump();

    final origin = t.getTopLeft(find.byType(SceneView));
    const leftKey = ValueKey('assets/scenes/obj_left.png');
    const rightKey = ValueKey('assets/scenes/obj_right.png');

    // 닫힘: 각자 자기 이미지 키가 자기 rect에서 시작 (400x600 박스 기준).
    expect(t.getTopLeft(find.byKey(leftKey)),
        offsetMoreOrLessEquals(origin + const Offset(40, 60), epsilon: 1.0));
    expect(t.getTopLeft(find.byKey(rightKey)),
        offsetMoreOrLessEquals(origin + const Offset(120, 60), epsilon: 1.0));

    s.setFlag('opened', 1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 700)); // 트윈 완료(600ms) 대기

    // 열림: 왼쪽 키는 왼쪽으로, 오른쪽 키는 오른쪽으로 — key가 없으면 리스트
    // 위치로만 매칭돼 자리가 뒤섞일 수 있는 지점(스펙 §4-1 엔진 수정 대상).
    expect(t.getTopLeft(find.byKey(leftKey)),
        offsetMoreOrLessEquals(origin + const Offset(8, 60), epsilon: 1.0));
    expect(t.getTopLeft(find.byKey(rightKey)),
        offsetMoreOrLessEquals(origin + const Offset(160, 60), epsilon: 1.0));
  });
}
