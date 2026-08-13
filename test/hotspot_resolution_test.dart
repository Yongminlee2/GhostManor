// 히트테스트 레이어(lib/core/scene_view.dart) 자체의 회귀망 — 기존 테스트는
// 전부 findHotspot/tapSpot으로 id를 직접 찾아 호출해 이 레이어를 우회한다
// (solutions.dart). 그래서 겹치는 rect가 서로를 가리는 버그가 스위트를 통과해도
// 숨어 있을 수 있었다 (최종 리뷰 Finding 1·3의 원인). 이 테스트는 SceneView와
// 동일한 규칙으로 각 핫스팟 중심점의 탭을 직접 풀어, 자기 자신에게 풀리는지
// 프레시 상태 기준으로 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/rooms.dart';

/// lib/core/scene_view.dart의 onTapUp과 동일한 규칙: hotspots.reversed에서
/// when 통과 + area.contains(p)인 첫 핫스팟이 탭을 가져간다.
String? _resolveTap(Scene scene, GameState s, Offset p) {
  for (final hs in scene.hotspots.reversed) {
    if ((hs.when?.call(s) ?? true) && hs.area.contains(p)) return hs.id;
  }
  return null;
}

void main() {
  // 프레시 상태에서 "자기 자신이 아닌 다른 핫스팟이 이겨야 정상"인 유일한
  // 의도된 케이스. sceneId -> {hotspotId -> 실제로 이겨야 할 핫스팟 id}.
  const exceptions = <String, Map<String, String>>{
    // living_b: TV가 꺼진 동안(tv_on==0) 부우가 문 앞을 막는 연출 — door 중심점이
    // boo 사각형 안에 있고, 뒤에 선언된 boo가 우선한다(최종 리뷰 Finding 3의 전제).
    'living_b': {'door': 'boo'},
    // bed_a: 창 앞을 감싼 커튼 rect의 중심이 창(window, 뒤에 선언) 안에
    // 들어간다 — 챕터2 방8(room8_bed.dart)에서 이미 존재하던 조합, 이번에
    // rooms.dart에 처음 등록되며 드러남. rect 재조정은 계획상 Task 9(일괄
    // 검수) 몫이라 여기서는 지금 배선이 의도한 우선순위(구체적 소품인 창이
    // 넓은 커튼보다 우선)임을 명시하는 예외로 기록.
    'bed_a': {'curtain': 'window'},
    // lab_a: 문(door)은 좌측 벽 전체를 덮는 가장 넓은 배경 rect로 먼저
    // 선언되고, 그 위에 겹치는 벽등(sconce)·촛불선반이 나중에 선언돼 우선권을
    // 가진다(room10_lab.dart 코드 주석에 명시된 의도적 z순서: "문을 가장
    // 넓게 먼저 선언하고 그 안에 겹치는 초상·벽등·촛불선반을 나중에 선언해
    // z순서로 우선권을 준다"). door·candle_shelf의 중심점이 각각 sconce·desk
    // 안에 들어가는 것은 이 설계의 자연스러운 결과다.
    'lab_a': {'door': 'sconce', 'candle_shelf': 'desk'},
    // lab_b: 좌우 책장 기둥(left_shelf/right_shelf)이 벽 전체 높이를 덮는
    // 배경 rect라, 그 중간에 박힌 촛대(left_sconce/right_sconce, 나중 선언)가
    // 우선권을 가진다 — lab_a의 door/sconce와 동일한 "넓은 배경 + 나중에
    // 박아넣는 소품" 패턴.
    'lab_b': {'left_shelf': 'left_sconce', 'right_shelf': 'right_sconce'},
    // lab_c: 열쇠고리(keyring)는 "약병 선반 뒤 그늘"이라는 서사대로 램프
    // (lamp, 나중 선언) rect 영역 안에 숨어 있다 — 은신처라는 설정 자체가
    // 겹침을 전제로 한다.
    'lab_c': {'keyring': 'lamp'},
  };

  for (final room in buildAllRooms()) {
    for (final scene in room.walls) {
      test('${room.id}/${scene.id}: 각 핫스팟 중심점은 프레시 상태에서 자기 자신에게 풀린다',
          () {
        final s = GameState();
        for (final hs in scene.hotspots) {
          if (!(hs.when?.call(s) ?? true)) continue; // 프레시 상태 비활성은 제외
          final resolved = _resolveTap(scene, s, hs.area.center);
          final expected = exceptions[scene.id]?[hs.id] ?? hs.id;
          expect(resolved, expected,
              reason:
                  '${room.id}/${scene.id}: ${hs.id} 중심점 탭이 $resolved에게 풀림 (겹치는 다른 핫스팟이 가림)');
        }
      });
    }
  }
}
