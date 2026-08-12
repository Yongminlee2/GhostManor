import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';
import 'solutions.dart';

void main() {
  test('solveFoyer가 새 GameState로 현관을 클리어', () {
    final s = GameState();
    final c = GameCtx(s, AudioService(enabled: false));
    final room = buildFoyer();
    solveFoyer(s, c, room);
    expect(room.cleared(s), isTrue);
  });
}
