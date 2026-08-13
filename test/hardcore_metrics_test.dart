import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/rooms.dart';

import 'solutions.dart';

/// 리마스터 하드코어 정량 게이트 (설계 §2·§8) — 방별 테스트에 흩어진
/// 단언과 별개로, 전 방을 한 곳에서 일괄 강제한다. 여기가 깨지면
/// 어느 방이 기준 미달로 퇴행했는지 방 이름으로 바로 드러난다.
void main() {
  test('전 방: 벽면 3개 + 상호작용 밀도 ≥15 + 진입 직후 활성 ≥2', () {
    final s = GameState();
    for (final room in buildAllRooms()) {
      expect(room.walls.length, 3, reason: '${room.id}: 벽면 수');
      final hotspots =
          room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
      expect(hotspots, greaterThanOrEqualTo(15),
          reason: '${room.id}: 핫스팟 $hotspots');
      final active = room.walls
          .expand((w) => w.hotspots)
          .where((h) => h.when == null || h.when!(s))
          .length;
      expect(active, greaterThanOrEqualTo(2),
          reason: '${room.id}: 진입 직후 활성 핫스팟 $active');
    }
  });

  test('전 방: 정답 시퀀스 스텝 ≥15 (연쇄 실주행, 수동 지급 없음)', () {
    final s = GameState();
    final c = GameCtx(s, AudioService(enabled: false));
    final rooms = buildAllRooms();
    final solves = [
      solveFoyer,
      solveLiving,
      solveStudy,
      solveKitchen,
      solveCellar,
      solveAttic,
      solveHall,
      solveBed,
      solveChild,
      solveLab,
      solveSeal,
    ];
    // solveSeal은 emblem_hall/bed/child/lab을 스스로 지급하지 않는다
    // (solveStudy가 oil을 지급하지 않는 것과 동일 관례) — 이 테스트는 방을
    // 하나의 공유 상태로 순서대로 이어 도는 구조라, solveHall~solveLab이
    // 각자 클리어 시 지급하는 emblem 4종이 solveSeal 차례엔 이미 인벤토리에
    // 있다(note1~4가 solveAttic 이전에 이미 쌓여 있는 것과 동일한 이유 —
    // 별도 수동 지급 불필요).
    final steps = <String, int>{};
    for (var i = 0; i < rooms.length; i++) {
      steps[rooms[i].id] = solves[i](s, c, rooms[i]);
      if (i < rooms.length - 1) s.goRoom(i + 1);
    }
    steps.forEach((room, n) {
      expect(n, greaterThanOrEqualTo(15), reason: '$room: $n스텝');
    });
    // 챕터 총량 — 기존 세대(방당 6~10)의 2배 이상이라는 리마스터 목표선.
    // 11방 완주(챕터2 계획 Task 7)로 하한을 180으로 상향.
    final total = steps.values.fold<int>(0, (a, b) => a + b);
    expect(total, greaterThanOrEqualTo(180), reason: '챕터 합계 $total스텝');
  });
}
