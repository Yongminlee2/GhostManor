import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/hint_service.dart';

void main() {
  const roomId = 'r1';
  late GameState s;
  late int clock; // 주입 시계: 테스트가 직접 흘려보내는 epoch 초
  late HintService svc;

  setUp(() {
    s = GameState();
    clock = 1000000000;
    s.setFlag('entered_at_$roomId', clock); // 방금 진입한 상태를 시뮬레이션
    svc = HintService(s, nowEpoch: () => clock);
  });

  test('진입 직후: step1 잠김(잔여 300), unlockNext는 locked·상태 불변', () {
    expect(svc.lockRemaining(roomId, 1), 300);
    expect(svc.unlockNext(roomId, 'p1'), HintOutcome.locked);
    expect(svc.unlocked('p1'), 0);
  });

  test('301초 후: step1 granted, step2는 잔여 179로 여전히 locked', () {
    clock += 301;
    expect(svc.unlockNext(roomId, 'p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 1);
    expect(svc.lockRemaining(roomId, 2), 179);
    expect(svc.unlockNext(roomId, 'p1'), HintOutcome.locked);
    expect(svc.unlocked('p1'), 1);
  });

  test('481초 후: step2 granted', () {
    clock += 301;
    svc.unlockNext(roomId, 'p1');
    clock += 180; // 누적 481초
    expect(svc.unlockNext(roomId, 'p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 2);
  });

  test('661초 후: step3 granted, 이후 alreadyMax', () {
    clock += 301;
    svc.unlockNext(roomId, 'p1');
    clock += 180;
    svc.unlockNext(roomId, 'p1');
    clock += 180; // 누적 661초
    expect(svc.unlockNext(roomId, 'p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 3);
    expect(svc.unlockNext(roomId, 'p1'), HintOutcome.alreadyMax);
    expect(svc.unlocked('p1'), 3);
  });

  test('entered_at 미기록 방은 진입 시각=지금으로 간주 → 잔여 300', () {
    final fresh = HintService(GameState(), nowEpoch: () => clock);
    expect(fresh.lockRemaining('unseen_room', 1), 300);
  });

  test('퍼즐별 카운터는 독립적', () {
    clock += 301;
    svc.unlockNext(roomId, 'p1');
    svc.unlockNext(roomId, 'p2');
    expect(svc.unlocked('p1'), 1);
    expect(svc.unlocked('p2'), 1);
  });
}
