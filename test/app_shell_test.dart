import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app({GameState? state}) =>
      GhostManorApp(initialState: state, audioEnabled: false);

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

  testWidgets(
      '클리어 흐름: foyer_done → 다음 방 → living_done → 다음 방 → study_done → 다음 방 → kitchen_done → 다음 방 → cellar_done → 다음 방 → 다락방 클리어 → 엔딩',
      (t) async {
    final s = GameState()..setFlag('entered_foyer', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text('현관'), findsOneWidget);
    s.setFlag('foyer_r_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text('거실'), findsOneWidget); // 방 4개 중 2번째 — 아직 안 끝남

    s.setFlag('living_r_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text('서재'), findsOneWidget); // 방 4개 중 3번째 — 아직 안 끝남

    s.setFlag('study_r_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text('주방'), findsOneWidget); // 방 5개 중 4번째 — 아직 안 끝남

    s.setFlag('kitchen_r_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text('지하실'), findsOneWidget); // 방 6개 중 5번째 — 아직 안 끝남

    s.setFlag('cellar_r_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text('다락방'), findsOneWidget); // 마지막 방 — 아직 안 끝남

    s.setFlag('attic_r_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text(strChapterEnd), findsOneWidget); // 마지막 방 클리어 → 엔딩
  });

  testWidgets('챕터 완료 상태로 재개하면 엔딩 화면', (t) async {
    final s = GameState()
      ..setFlag('entered_foyer', 1)
      ..setFlag('foyer_r_done', 1)
      ..setFlag('cleared_shown_foyer', 1)
      ..setFlag('entered_living', 1)
      ..setFlag('living_r_done', 1)
      ..setFlag('cleared_shown_living', 1)
      ..setFlag('entered_study', 1)
      ..setFlag('study_r_done', 1)
      ..setFlag('cleared_shown_study', 1)
      ..roomIndex = 3
      ..setFlag('entered_kitchen', 1)
      ..setFlag('kitchen_r_done', 1)
      ..setFlag('cleared_shown_kitchen', 1)
      ..roomIndex = 4
      ..setFlag('entered_cellar', 1)
      ..setFlag('cellar_r_done', 1)
      ..setFlag('cleared_shown_cellar', 1)
      ..roomIndex = 5
      ..setFlag('entered_attic', 1)
      ..setFlag('attic_r_done', 1)
      ..setFlag('cleared_shown_attic', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text(strChapterEnd), findsOneWidget);
  });

  testWidgets(
      '스트랜드된 세이브 자동 복구: 클리어 다이얼로그 못 보고 저장된 상태로 재개해도 다음 방으로 자동 전진',
      (t) async {
    // cleared_shown_living만 켜져 있고 실제 전진(goRoom)은 없었던 상태 —
    // 백버튼 dismiss나 다이얼로그 도중 프로세스 사망이 만드는 스트랜드 세이브
    // (최종 리뷰 Finding 2b).
    final s = GameState()
      ..setFlag('entered_living', 1)
      ..setFlag('living_r_done', 1)
      ..setFlag('cleared_shown_living', 1)
      ..roomIndex = 1;
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text('서재'), findsOneWidget); // 거실에 갇히지 않고 다음 방으로
    expect(find.text('거실'), findsNothing);
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
