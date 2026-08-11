import 'package:flutter/material.dart';
import 'models.dart';

/// 에셋 없으면 파일명 라벨 색 블록 — 아트 도착 전에도 게임 동작 (스펙 §7).
Widget gameImage(String path) => Image.asset(
      path,
      fit: BoxFit.fill,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF3A2E4F),
        alignment: Alignment.center,
        child: Text(path.split('/').last,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
    );

/// 벽면/클로즈업 렌더 + 비율 좌표 히트테스트. 부모가 2:3 박스를 보장한다.
class SceneView extends StatelessWidget {
  final Room room;
  final GameCtx ctx;
  const SceneView({super.key, required this.room, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final scene = s.closeupId != null
            ? room.closeups[s.closeupId]!
            : room.walls[s.sceneIndex % room.walls.length];
        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          Rect px(Rect r) =>
              Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
          return Stack(children: [
            if (scene.custom != null)
              Positioned.fill(child: scene.custom!(context, ctx))
            else ...[
              Positioned.fill(child: gameImage(scene.image!)),
              for (final o in scene.overlays)
                if (o.when(s))
                  Positioned.fromRect(rect: px(o.area), child: gameImage(o.image)),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final p = Offset(
                        d.localPosition.dx / w, d.localPosition.dy / h);
                    for (final hs in scene.hotspots.reversed) {
                      if ((hs.when?.call(s) ?? true) && hs.area.contains(p)) {
                        hs.onTap(ctx);
                        return;
                      }
                    }
                  },
                ),
              ),
            ],
            if (s.closeupId == null && room.walls.length > 1) ...[
              _arrow(left: true,
                  onTap: () => s.goScene(
                      (s.sceneIndex - 1 + room.walls.length) % room.walls.length)),
              _arrow(left: false,
                  onTap: () => s.goScene((s.sceneIndex + 1) % room.walls.length)),
            ],
            if (s.closeupId != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const Key('closeup_close'),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: s.closeCloseup,
                ),
              ),
            if (s.dialog != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: () => s.say(null),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xE6241B36),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7C5CC4)),
                    ),
                    child: Text(s.dialog!,
                        style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ),
              ),
          ]);
        });
      },
    );
  }

  Widget _arrow({required bool left, required VoidCallback onTap}) => Positioned(
        left: left ? 0 : null,
        right: left ? null : 0,
        top: 0,
        bottom: 0,
        child: Center(
          child: IconButton(
            key: Key(left ? 'arrow_left' : 'arrow_right'),
            icon: Icon(left ? Icons.chevron_left : Icons.chevron_right,
                color: Colors.white70, size: 40),
            onPressed: onTap,
          ),
        ),
      );
}
