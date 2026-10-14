// 아트 정합 점검용: 모든 방의 벽면·클로즈업에서 배경·오버레이·오브젝트·
// 유령·핫스팟 좌표를 JSON 으로 뽑는다. tool/art_check/render.py 가 읽어
// 배경 위에 겹쳐 그린다. 일반 시험 목록에는 들어가지 않는다.
//   flutter test tool/art_check/scene_dump_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/rooms.dart';

List<double> r(Rect a) => [a.left, a.top, a.width, a.height];

void main() {
  test('scene dump', () {
    final s = GameState();
    final out = <Map<String, dynamic>>[];
    for (final room in buildAllRooms()) {
      Map<String, dynamic> scene(Scene sc, String kind) => {
            'room': room.id,
            'kind': kind,
            'id': sc.id,
            'image': sc.image,
            'custom': sc.custom != null,
            'overlays': [
              for (final o in sc.overlays) {'image': o.image, 'area': r(o.area)}
            ],
            'objects': [
              for (final o in sc.objects) {'image': o.image, 'area': r(o.area(s))}
            ],
            'idles': [
              for (final o in sc.idles) {'image': o.image, 'area': r(o.area)}
            ],
            'hotspots': [
              for (final h in sc.hotspots) {'id': h.id, 'area': r(h.area)}
            ],
          };
      for (final w in room.walls) {
        out.add(scene(w, 'wall'));
      }
      for (final c in room.closeups.values) {
        out.add(scene(c, 'closeup'));
      }
    }
    File(Platform.environment['DUMP_OUT'] ?? 'build/scene_dump.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  });
}
