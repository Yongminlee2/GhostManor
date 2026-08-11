import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 공식 테스트 보상형 유닛. 실제 ID 교체는 출시 태스크 (스펙 §9).
const rewardedTestUnitId = 'ca-app-pub-3940256099942544/5224354917';
bool _initialized = false;

/// 보상 획득 시 true. 로드/표시 실패·예외는 전부 false (HintService가 폴백 처리).
Future<bool> showRewardedAd() async {
  try {
    if (!_initialized) {
      await MobileAds.instance.initialize();
      _initialized = true;
    }
    final loader = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: rewardedTestUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => loader.complete(ad),
        onAdFailedToLoad: (_) => loader.complete(null),
      ),
    );
    final ad = await loader.future;
    if (ad == null) return false;
    var rewarded = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => rewarded = true);
    await closed.future;
    return rewarded;
  } catch (_) {
    return false;
  }
}
