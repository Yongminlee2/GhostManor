import 'game_state.dart';

enum HintOutcome { granted, grantedFree, adFailed, alreadyMax }

/// 3단계 힌트: 1단계 무료, 2·3단계 광고. 실패 누적 3회면 무료 (스펙 §6).
class HintService {
  final GameState s;
  final Future<bool> Function() showRewardedAd;
  HintService(this.s, {required this.showRewardedAd});

  int unlocked(String puzzleId) => s.flag('hint_$puzzleId');

  Future<HintOutcome> unlockNext(String puzzleId) async {
    final cur = unlocked(puzzleId);
    if (cur >= 3) return HintOutcome.alreadyMax;
    if (cur == 0) {
      s.setFlag('hint_$puzzleId', 1);
      return HintOutcome.granted;
    }
    if (s.flag('ad_fail') >= 3) {
      s.setFlag('ad_fail', 0);
      s.setFlag('hint_$puzzleId', cur + 1);
      return HintOutcome.grantedFree;
    }
    final rewarded = await showRewardedAd();
    if (!rewarded) {
      s.addFlag('ad_fail');
      return HintOutcome.adFailed;
    }
    s.setFlag('ad_fail', 0);
    s.setFlag('hint_$puzzleId', cur + 1);
    return HintOutcome.granted;
  }
}
