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

  testWidgets('클리어 흐름: foyer_done → 클리어 다이얼로그 → 다음 방 → 거실 클리어 → 엔딩', (t) async {
    final s = GameState()..setFlag('entered_foyer', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text('현관'), findsOneWidget);
    s.setFlag('foyer_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text('거실'), findsOneWidget); // 방 2개째 — 아직 안 끝남

    s.setFlag('living_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text(strChapterEnd), findsOneWidget); // 마지막 방 클리어 → 엔딩
  });

  testWidgets('챕터 완료 상태로 재개하면 엔딩 화면', (t) async {
    final s = GameState()
      ..setFlag('entered_foyer', 1)
      ..setFlag('foyer_done', 1)
      ..setFlag('cleared_shown_foyer', 1)
      ..roomIndex = 1
      ..setFlag('entered_living', 1)
      ..setFlag('living_done', 1)
      ..setFlag('cleared_shown_living', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text(strChapterEnd), findsOneWidget);
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
