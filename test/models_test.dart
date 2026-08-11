import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';

void main() {
  GameCtx ctx(GameState s) => GameCtx(s, AudioService(enabled: false));

  test('GameCtx: give/consume/using/say/closeup이 상태에 반영', () {
    final s = GameState();
    final c = ctx(s);
    c.give('match');
    expect(s.has('match'), isTrue);
    s.select('match');
    expect(c.using('match'), isTrue);
    c.consume('match');
    expect(s.has('match'), isFalse);
    c.say('안녕');
    expect(s.dialog, '안녕');
    c.openCloseup('drawer');
    expect(s.closeupId, 'drawer');
    c.closeCloseup();
    expect(s.closeupId, isNull);
  });

  test('Hotspot: 최소 폭 8% 미만은 assert (픽셀 헌팅 금지)', () {
    expect(
        () => Hotspot(
            id: 'tiny',
            area: const Rect.fromLTWH(0, 0, 0.05, 0.5),
            onTap: (_) {}),
        throwsAssertionError);
  });

  test('AudioService: 비활성/음소거/에셋 없음 모두 안전', () async {
    final a = AudioService(enabled: false);
    await a.play('pickup'); // throw 없으면 통과
    await a.playBgm('bgm_manor');
    await a.setMuted(true);
    await a.play('pickup');
  });

  test('Scene: custom 없고 image도 없으면 assert', () {
    expect(() => Scene(id: 'x'), throwsAssertionError);
    expect(() => Scene(id: 'x', image: 'a.png'), returnsNormally);
  });
}
