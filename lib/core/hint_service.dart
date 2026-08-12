import 'game_state.dart';

enum HintOutcome { granted, alreadyMax, locked }

/// 3단계 힌트: 전부 무료지만 방 진입 후 시간차로 해금(방향→구체→정답).
/// step1=5분, step2=8분, step3=11분 — 진입 시각(`entered_at_<roomId>`) 기준 누적.
class HintService {
  final GameState s;
  final int Function() _now;

  HintService(this.s, {int Function()? nowEpoch}) : _now = nowEpoch ?? _epochNow;

  static int _epochNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static const _lockAtSecs = [300, 480, 660]; // step1/2/3 누적 해금 시각(진입 후)

  int unlocked(String puzzleId) => s.flag('hint_$puzzleId');

  int _enteredAt(String roomId) {
    final at = s.flag('entered_at_$roomId');
    return at == 0 ? _now() : at; // 미기록 방은 진입 시각=지금으로 간주
  }

  /// step(1~3)이 열리기까지 남은 초. 0이면 이미 해금.
  int lockRemaining(String roomId, int step) {
    final remain = _lockAtSecs[step - 1] - (_now() - _enteredAt(roomId));
    return remain > 0 ? remain : 0;
  }

  HintOutcome unlockNext(String roomId, String puzzleId) {
    final cur = unlocked(puzzleId);
    if (cur >= 3) return HintOutcome.alreadyMax;
    if (lockRemaining(roomId, cur + 1) > 0) return HintOutcome.locked;
    s.setFlag('hint_$puzzleId', cur + 1);
    return HintOutcome.granted;
  }
}
