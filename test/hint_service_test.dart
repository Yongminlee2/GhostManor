import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/hint_service.dart';

void main() {
  test('1단계는 무료, 광고 함수 호출 안 함', () async {
    var adCalls = 0;
    final svc = HintService(GameState(), showRewardedAd: () async {
      adCalls++;
      return true;
    });
    expect(await svc.unlockNext('p1'), HintOutcome.granted);
    expect(svc.unlocked('p1'), 1);
    expect(adCalls, 0);
  });

  test('2·3단계는 광고 성공 시 해금, 3단계 이후 alreadyMax', () async {
    final svc = HintService(GameState(), showRewardedAd: () async => true);
    await svc.unlockNext('p1'); // 1 무료
    expect(await svc.unlockNext('p1'), HintOutcome.granted); // 2
    expect(await svc.unlockNext('p1'), HintOutcome.granted); // 3
    expect(svc.unlocked('p1'), 3);
    expect(await svc.unlockNext('p1'), HintOutcome.alreadyMax);
  });

  test('광고 실패 → adFailed + 누적, 3회째부터 무료 지급 (스펙 §6)', () async {
    final s = GameState();
    final svc = HintService(s, showRewardedAd: () async => false);
    await svc.unlockNext('p1'); // 1 무료
    expect(await svc.unlockNext('p1'), HintOutcome.adFailed); // fail 1
    expect(await svc.unlockNext('p1'), HintOutcome.adFailed); // fail 2
    expect(await svc.unlockNext('p1'), HintOutcome.adFailed); // fail 3
    expect(s.flag('ad_fail'), 3);
    expect(await svc.unlockNext('p1'), HintOutcome.grantedFree); // 무료 지급
    expect(svc.unlocked('p1'), 2);
    expect(s.flag('ad_fail'), 0); // 지급 후 리셋
  });

  test('광고 성공 시 실패 카운터 리셋', () async {
    final s = GameState();
    var ok = false;
    final svc = HintService(s, showRewardedAd: () async => ok);
    await svc.unlockNext('p1'); // 1 무료
    await svc.unlockNext('p1'); // fail 1
    ok = true;
    expect(await svc.unlockNext('p1'), HintOutcome.granted);
    expect(s.flag('ad_fail'), 0);
  });
}
