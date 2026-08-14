import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'models.dart';
import 'scene_view.dart';

/// 문질러서 먼지를 걷어내는 기믹 위젯 — room1 FrameCloseup을 일반화해 다른 방에서도
/// 재사용한다 (스펙 §8). cleaned가 참이면 base만 보여준다. 아니면 base 위에 cover를
/// 올리고, 손가락이 지나간 자리마다 구멍(부드러운 원)을 뚫어 그 부분만 걷어낸다 —
/// 전체가 균일하게 옅어지던 이전 방식은 실기기에서 "지우는 느낌이 안 난다"는 평가.
/// progressFlag를 주면 누적 진행률(0~100)을 플래그로 저장해, 중간에 나갔다 돌아와도
/// 걷어낸 만큼 옅어진 상태에서 이어진다.
class RubbableScene extends StatefulWidget {
  final GameCtx ctx;
  final String baseImage;
  final String coverImage;
  final Cond cleaned;
  final void Function(GameCtx c) onCleaned;
  final double progressPerPx;
  final String? progressFlag;
  final Key? gestureKey;

  const RubbableScene({
    super.key,
    required this.ctx,
    required this.baseImage,
    required this.coverImage,
    required this.cleaned,
    required this.onCleaned,
    this.progressPerPx = 1 / 2500,
    this.progressFlag,
    this.gestureKey,
  });

  @override
  State<RubbableScene> createState() => _RubbableSceneState();
}

class _RubbableSceneState extends State<RubbableScene> {
  double progress = 0;
  bool _done = false; // onCleaned 원샷 가드(이번 위젯 생애 전용) — cleaned Cond는 재진입 렌더링용
  final List<Offset> _strokes = []; // 정규화(0..1) 좌표 — 구멍 위치
  ui.Image? _cover;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    if (widget.progressFlag != null) {
      progress = widget.ctx.s.flag(widget.progressFlag!) / 100.0;
    }
    _stream = AssetImage(widget.coverImage).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _cover = info.image);
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    super.dispose();
  }

  void _saveProgress() {
    if (widget.progressFlag == null) return;
    widget.ctx.s
        .setFlag(widget.progressFlag!, (progress.clamp(0.0, 1.0) * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = widget.cleaned(widget.ctx.s);
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      return GestureDetector(
        key: widget.gestureKey,
        behavior: HitTestBehavior.opaque,
        onPanUpdate: cleaned
            ? null
            : (d) {
                if (_done) return; // rebuild 전 연속 이벤트에도 onCleaned 중복 호출 방지
                setState(() {
                  progress += d.delta.distance * widget.progressPerPx;
                  _strokes.add(Offset(d.localPosition.dx / size.width,
                      d.localPosition.dy / size.height));
                });
                if (progress >= 1) {
                  _done = true;
                  _saveProgress();
                  widget.onCleaned(widget.ctx);
                }
              },
        onPanEnd: cleaned ? null : (_) => _saveProgress(),
        child: Stack(fit: StackFit.expand, children: [
          gameImage(widget.baseImage),
          if (!cleaned)
            _cover == null
                // 이미지 디코딩 전 한두 프레임: 이전 방식(균일 페이드)으로 폴백
                ? Opacity(
                    opacity: (1 - progress).clamp(0.0, 1.0),
                    child: gameImage(widget.coverImage))
                : CustomPaint(
                    painter: _CoverPainter(_cover!, List.of(_strokes),
                        (1 - progress * 0.55).clamp(0.0, 1.0))),
        ]),
      );
    });
  }
}

/// cover 전체를 그린 뒤 스트로크 지점마다 흐린 가장자리 원을 BlendMode.clear로
/// 지운다. 진행될수록 cover 자체도 서서히 옅어져(재진입 복원과 같은 표현)
/// 구멍+전체 페이드가 함께 걷히는 느낌을 만든다.
class _CoverPainter extends CustomPainter {
  final ui.Image cover;
  final List<Offset> strokes; // 정규화 좌표
  final double opacity;
  _CoverPainter(this.cover, this.strokes, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawImageRect(
      cover,
      Rect.fromLTWH(0, 0, cover.width.toDouble(), cover.height.toDouble()),
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    final r = size.shortestSide * 0.09;
    final hole = Paint()
      ..blendMode = BlendMode.clear
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45);
    for (final p in strokes) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), r, hole);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.strokes.length != strokes.length || old.opacity != opacity;
}
