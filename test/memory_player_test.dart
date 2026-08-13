import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/memory_player.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';

void main() {
  late GameState s;
  late GameCtx c;

  Future<void> pump(WidgetTester t, Widget child) => t.pumpWidget(MaterialApp(
      home: Center(child: SizedBox(width: 400, height: 600, child: child))));

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
  });

  // 실제 스토리 바이블 문구(회상1, 3페이지)를 그대로 사용 — 위젯 검증과 동시에
  // strings.dart 상수가 온전히 표시되는지도 확인한다.
  const pages = [
    MemoryPage('assets/scenes/memory1_1.png', strF2Mem1p1),
    MemoryPage('assets/scenes/memory1_2.png', strF2Mem1p2),
    MemoryPage('assets/scenes/memory1_3.png', strF2Mem1p3),
  ];

  testWidgets('첫 페이지: 이미지 파일명 라벨 폴백 + 자막 표시', (t) async {
    await pump(t, MemoryPlayer(ctx: c, pages: pages, onDone: () {}));
    await t.pump(); // 새로 마운트된 이미지의 errorBuilder 해석에 한 프레임 더 필요
    expect(find.text('memory1_1.png'), findsOneWidget);
    expect(find.text(strF2Mem1p1), findsOneWidget);
    expect(find.text(strMemoryTapHint), findsOneWidget);
  });

  testWidgets('탭마다 다음 페이지로 전진(이미지+자막 모두 갱신), onDone은 아직 안 불림',
      (t) async {
    var doneCount = 0;
    await pump(
        t, MemoryPlayer(ctx: c, pages: pages, onDone: () => doneCount++));
    await t.pump();

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle(); // AnimatedSwitcher 페이드(300ms) 완료까지 — Timer 無이라 안전
    expect(find.text('memory1_2.png'), findsOneWidget);
    expect(find.text(strF2Mem1p2), findsOneWidget);
    expect(find.text('memory1_1.png'), findsNothing);
    expect(doneCount, 0);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text('memory1_3.png'), findsOneWidget);
    expect(find.text(strF2Mem1p3), findsOneWidget);
    expect(doneCount, 0);
  });

  testWidgets('마지막 페이지에서 탭하면 onDone 호출, 연타해도 정확히 1회', (t) async {
    var doneCount = 0;
    await pump(
        t, MemoryPlayer(ctx: c, pages: pages, onDone: () => doneCount++));
    await t.pump();

    await t.tap(find.byType(MemoryPlayer)); // p1 → p2
    await t.pumpAndSettle();
    await t.tap(find.byType(MemoryPlayer)); // p2 → p3(마지막)
    await t.pumpAndSettle();
    expect(doneCount, 0);

    // 마지막 페이지에서 연타 — rebuild 없이 연속 탭해도 onDone은 한 번만.
    await t.tap(find.byType(MemoryPlayer));
    await t.tap(find.byType(MemoryPlayer));
    await t.tap(find.byType(MemoryPlayer));
    await t.pump();
    expect(doneCount, 1);
  });

  testWidgets('페이지 1장짜리 회상: 첫 탭이 곧 마지막 탭 → onDone 즉시 1회',
      (t) async {
    var doneCount = 0;
    const onePage = [MemoryPage('assets/scenes/memoryX.png', '단 한 장뿐인 회상.')];
    await pump(t,
        MemoryPlayer(ctx: c, pages: onePage, onDone: () => doneCount++));
    await t.pump();
    await t.tap(find.byType(MemoryPlayer));
    await t.pump();
    expect(doneCount, 1);
  });
}
