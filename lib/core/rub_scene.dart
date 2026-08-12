import 'package:flutter/material.dart';
import 'models.dart';
import 'scene_view.dart';

/// 문질러서 먼지를 걷어내는 기믹 위젯 — room1 FrameCloseup을 일반화해 다른 방에서도
/// 재사용한다 (스펙 §8). cleaned가 참이면 base만, 아니면 base 위에 cover를 올리고
/// onPanUpdate 이동거리를 progressPerPx만큼 누적해 cover를 투명하게 걷어낸다.
class RubbableScene extends StatefulWidget {
  final GameCtx ctx;
  final String baseImage;
  final String coverImage;
  final Cond cleaned;
  final void Function(GameCtx c) onCleaned;
  final double progressPerPx;
  final Key? gestureKey;

  const RubbableScene({
    super.key,
    required this.ctx,
    required this.baseImage,
    required this.coverImage,
    required this.cleaned,
    required this.onCleaned,
    this.progressPerPx = 1 / 2500,
    this.gestureKey,
  });

  @override
  State<RubbableScene> createState() => _RubbableSceneState();
}

class _RubbableSceneState extends State<RubbableScene> {
  double progress = 0;
  bool _done = false; // onCleaned 원샷 가드(이번 위젯 생애 전용) — cleaned Cond는 재진입 렌더링용

  @override
  Widget build(BuildContext context) {
    final cleaned = widget.cleaned(widget.ctx.s);
    return GestureDetector(
      key: widget.gestureKey,
      behavior: HitTestBehavior.opaque,
      onPanUpdate: cleaned
          ? null
          : (d) {
              if (_done) return; // rebuild 전 연속 이벤트에도 onCleaned 중복 호출 방지
              setState(() => progress += d.delta.distance * widget.progressPerPx);
              if (progress >= 1) {
                _done = true;
                widget.onCleaned(widget.ctx);
              }
            },
      child: Stack(fit: StackFit.expand, children: [
        gameImage(widget.baseImage),
        if (!cleaned)
          Opacity(
              opacity: (1 - progress).clamp(0.0, 1.0),
              child: gameImage(widget.coverImage)),
      ]),
    );
  }
}
