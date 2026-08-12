import 'game_state.dart';

enum HintOutcome { granted, alreadyMax }

/// 3단계 힌트: 전부 무료. 단계별 순차 해금(방향→구체→정답).
class HintService {
  final GameState s;
  HintService(this.s);

  int unlocked(String puzzleId) => s.flag('hint_$puzzleId');

  HintOutcome unlockNext(String puzzleId) {
    final cur = unlocked(puzzleId);
    if (cur >= 3) return HintOutcome.alreadyMax;
    s.setFlag('hint_$puzzleId', cur + 1);
    return HintOutcome.granted;
  }
}
