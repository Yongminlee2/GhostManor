import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/hint_service.dart';

void main() {
  test('순차 해금: 0→1→2→3 전부 granted', () {
    final svc = HintService(GameState());
    expect(svc.unlockNext('p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 1);
    expect(svc.unlockNext('p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 2);
    expect(svc.unlockNext('p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 3);
  });

  test('3단계 이후 alreadyMax', () {
    final svc = HintService(GameState());
    svc.unlockNext('p1');
    svc.unlockNext('p1');
    svc.unlockNext('p1');
    expect(svc.unlockNext('p1'), HintOutcome.alreadyMax);
    expect(svc.unlocked('p1'), 3);
  });

  test('퍼즐별 카운터는 독립적', () {
    final svc = HintService(GameState());
    svc.unlockNext('p1');
    svc.unlockNext('p1');
    svc.unlockNext('p2');
    expect(svc.unlocked('p1'), 2);
    expect(svc.unlocked('p2'), 1);
  });
}
