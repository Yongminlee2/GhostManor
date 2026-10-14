// 챕터 1·2 정답 진행(11방)을 탭 한 번마다 기록한다 — 앱의 디버그 재생 모드(lib/core/debug_play.dart)가
// 단계마다 실제 화면을 그려 찍는다. 그림·핫스팟·대사가 진행 중에 맞는지 눈으로 보려는 것.
//   flutter test tool/art_check/play_record_test.dart   → build/play.json
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/rooms.dart';

import '../../test/solutions.dart';

void main() {
  test('play record', () {
    final s = GameState();
    final c = GameCtx(s, AudioService(enabled: false));
    final rooms = buildAllRooms();
    final steps = <Map<String, dynamic>>[];
    var lastWall = 0;
    tapSpotHook = (Room room, String sceneId, Hotspot h) {
      final wi = room.walls.indexWhere((w) => w.id == sceneId);
      if (wi >= 0) lastWall = wi;
      final shown = s.closeupId ?? room.walls[lastWall].id;
      final Rect a = h.area;
      steps.add({
        'n': steps.length,
        'room': room.id,
        'tapped': '$sceneId/${h.id}',
        'mark': shown == sceneId ? [a.left, a.top, a.width, a.height] : null,
        'flags': Map<String, int>.from(s.flags),
        'inventory': List<String>.from(s.inventory),
        'selected': s.selectedItem,
        'roomIndex': s.roomIndex,
        'sceneIndex': lastWall,
        'closeup': s.closeupId,
        'dialog': s.dialog,
      });
    };
    final solvers = [
      solveFoyer, solveLiving, solveStudy, solveKitchen, solveCellar, solveAttic,
      solveHall, solveBed, solveChild, solveLab, solveSeal,
    ];
    for (var i = 0; i < rooms.length; i++) {
      lastWall = 0;
      solvers[i](s, c, rooms[i]);
      if (i + 1 < rooms.length) s.goRoom(i + 1);
    }
    tapSpotHook = null;
    File('build/play.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(steps));
    // ignore: avoid_print
    print('steps: ${steps.length}');
  });
}
