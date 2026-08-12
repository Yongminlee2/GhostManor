import 'package:flutter/widgets.dart';
import 'audio_service.dart';
import 'game_state.dart';

typedef Cond = bool Function(GameState s);

/// 핫스팟 onTap이 받는 실행 컨텍스트. BuildContext 불필요 →
/// 방 로직을 위젯 없이 헤드리스로 테스트할 수 있다 (스펙 §8).
class GameCtx {
  final GameState s;
  final AudioService audio;
  GameCtx(this.s, this.audio);

  void say(String text) => s.say(text);
  void sfx(String name) => audio.play(name);
  void give(String itemId) {
    s.give(itemId);
    audio.play('pickup');
  }

  bool using(String itemId) => s.selectedItem == itemId;
  void consume(String itemId) => s.take(itemId);
  void openCloseup(String id) => s.openCloseup(id);
  void closeCloseup() => s.closeCloseup();
}

class Hotspot {
  final String id;
  final Rect area; // 씬 이미지 대비 비율 좌표(0~1)
  final Cond? when; // null이면 항상 활성
  final void Function(GameCtx c) onTap;

  Hotspot({required this.id, required this.area, this.when, required this.onTap})
      : assert(area.width >= 0.08, '픽셀 헌팅 금지: 핫스팟 폭은 화면의 8% 이상 (스펙 §3.4)');
}

/// 오버레이 등장 모션. 기본은 fade — 방마다 지정한 것만 slideDown/grow (스펙 §3).
enum OverlayMotion { fade, slideDown, grow }

class SceneOverlay {
  final String image; // assets/scenes/...
  final Rect area; // 비율 좌표. 전체 덮기는 Rect.fromLTWH(0,0,1,1)
  final Cond when;
  final OverlayMotion motion;
  const SceneOverlay({
    required this.image,
    required this.area,
    required this.when,
    this.motion = OverlayMotion.fade,
  });
}

/// 씬 위를 은은히 떠다니는 유령 스프라이트 (탭 불가, 장식용). area는 비율 좌표.
class IdleSprite {
  final String image;
  final Rect area;
  final Cond? when; // null이면 항상 표시
  final double bobPx; // 위아래로 떠다니는 폭(픽셀)
  IdleSprite({required this.image, required this.area, this.when, this.bobPx = 4});
}

class Scene {
  final String id;
  final String? image; // assets/scenes/... (custom 씬은 생략 가능)
  final List<SceneOverlay> overlays;
  final List<Hotspot> hotspots;
  final List<IdleSprite> idles;

  /// escape hatch: 지정 시 이미지·오버레이·핫스팟 대신 위젯에 전체 위임 (스펙 §4.3)
  final Widget Function(BuildContext context, GameCtx ctx)? custom;

  Scene({
    required this.id,
    this.image,
    this.overlays = const [],
    this.hotspots = const [],
    this.idles = const [],
    this.custom,
  }) : assert(custom != null || image != null, '씬은 image나 custom 중 하나 필수');
}

class PuzzleHint {
  final String puzzleId;
  final String title;
  final List<String> steps; // 방향→구체→정답
  final Cond? solved; // 풀린 퍼즐은 힌트 목록에 완료 표시
  PuzzleHint(
      {required this.puzzleId,
      required this.title,
      required this.steps,
      this.solved})
      : assert(steps.length == 3, '힌트는 정확히 3단계 (스펙 §6)');
}

class Room {
  final String id;
  final String name;
  final List<Scene> walls; // 좌우 화살표로 순환
  final Map<String, Scene> closeups;
  final List<PuzzleHint> hints;
  final Cond cleared; // 탈출 조건
  final void Function(GameCtx c)? onEnter; // 첫 진입 시 1회 (셸이 호출)

  Room({
    required this.id,
    required this.name,
    required this.walls,
    this.closeups = const {},
    this.hints = const [],
    required this.cleared,
    this.onEnter,
  }) : assert(
          closeups.entries.every((e) => e.key == e.value.id),
          'closeups의 key는 Scene.id와 일치해야 한다 (SceneView가 key로 조회)');
}
