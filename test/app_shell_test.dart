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
      '클리어 흐름: foyer_r_done → 다음 방 → living_r_done → 다음 방 → study_r_done → 다음 방 → kitchen_r_done → 다음 방 → cellar_r_done → 다음 방 → 다락방 클리어 → 계단홀(챕터2로 이어짐, 아직 엔딩 아님)',
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
    // 다락(챕터1 마지막 콘텐츠 방)은 더 이상 목록의 마지막이 아니다 —
    // rooms.length가 6→11로 늘어난 뒤에도 _showClear/_ended는 하드코딩된
    // 인덱스가 아니라 roomIndex+1 vs rooms.length 제네릭 비교라, 클리어
    // 다이얼로그를 넘기면 챕터2 첫 방(계단홀)으로 자연히 이어진다(챕터2
    // 계획 Task 7 — "챕터1 엔딩 흐름을 챕터2 진입으로 연결").
    expect(find.text('계단홀·복도'), findsOneWidget);
    expect(find.text(strChapterEnd), findsNothing);
  });

  testWidgets('구 챕터1 완료 세이브(방 인덱스 5, attic_r_done)를 로드하면 엔딩이 아니라 방7(계단홀)로 자연 전진',
      (t) async {
    // rooms.dart가 6방뿐이던 시절 만들어진 "챕터 클리어" 세이브의 형태
    // 그대로(roomIndex=5=다락, cleared_shown_attic=1 — 그 시절엔 이 조합이
    // 곧 챕터 끝이었다). 챕터2 계획 Task 7의 명시적 요구: 이 세이브가 지금
    // 로드되면 방7로 자연 전진해야 한다. _selfHealStrandedClear는 원래
    // "다이얼로그를 못 보고 남겨진 세이브"를 복구하려고 만든 로직이지만,
    // roomIndex+1 < rooms.length 조건만 보는 제네릭 구현이라 이 구 세이브도
    // 같은 경로로 자동 복구된다 — 별도 가드 추가 없이 그대로 통과.
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
    expect(find.text('계단홀·복도'), findsOneWidget);
    expect(find.text(strChapterEnd), findsNothing);
    expect(find.text('다락방'), findsNothing);
  });

  testWidgets('봉인의 방(마지막 방) 클리어 → 진짜 엔딩 화면', (t) async {
    // 11방 전부를 실제로 풀지 않고(그 검증은 chapter1_integration_test.dart
    // 몫), 앱 셸의 클리어→전진→엔딩 배선만 직접 플래그로 확인한다 —
    // 위 '챕터 완료' 테스트가 예전에 하던 역할을 이제는 방11이 넘겨받는다.
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
      ..setFlag('entered_kitchen', 1)
      ..setFlag('kitchen_r_done', 1)
      ..setFlag('cleared_shown_kitchen', 1)
      ..setFlag('entered_cellar', 1)
      ..setFlag('cellar_r_done', 1)
      ..setFlag('cleared_shown_cellar', 1)
      ..setFlag('entered_attic', 1)
      ..setFlag('attic_r_done', 1)
      ..setFlag('cleared_shown_attic', 1)
      ..setFlag('entered_hall', 1)
      ..setFlag('f2_hall_done', 1)
      ..setFlag('cleared_shown_hall', 1)
      ..setFlag('entered_bed', 1)
      ..setFlag('f2_bed_done', 1)
      ..setFlag('cleared_shown_bed', 1)
      ..setFlag('entered_child', 1)
      ..setFlag('f2_child_done', 1)
      ..setFlag('cleared_shown_child', 1)
      ..setFlag('entered_lab', 1)
      ..setFlag('f2_lab_done', 1)
      ..setFlag('cleared_shown_lab', 1)
      ..roomIndex = 10
      ..setFlag('entered_seal', 1);
    await t.pumpWidget(app(state: s));
    await t.pumpAndSettle();
    expect(find.text('봉인의 방'), findsOneWidget);

    s.setFlag('f2_seal_done', 1);
    await t.pumpAndSettle();
    expect(find.text(strRoomClear), findsOneWidget);
    await t.tap(find.text(strNextRoom));
    await t.pumpAndSettle();
    expect(find.text(strChapterEnd), findsOneWidget);
    expect(find.text(strBackToTitle), findsOneWidget);

    await t.tap(find.text(strBackToTitle));
    await t.pumpAndSettle();
    expect(find.text(strAppTitle), findsOneWidget);
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
