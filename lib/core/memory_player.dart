import 'package:flutter/material.dart';
import 'models.dart';
import 'scene_view.dart';
import 'strings.dart';

/// 회상 페이지 1장 — 세피아 일러스트 1장 + 자막(스토리 바이블 전문, strings.dart).
class MemoryPage {
  final String image;
  final String caption;
  const MemoryPage(this.image, this.caption);
}

/// 기억 회상 씬(설계 §2): {이미지,자막} 페이지를 탭마다 다음으로 넘기고, 마지막
/// 페이지에서 탭하면 onDone을 1회 호출한다. closeups['memory']에 Scene.custom으로
/// 얹혀 재생되는 것을 전제로 하며, onDone에서 c.s.closeCloseup()을 부르는 건
/// 호출부(방 파일) 책임 — 이 위젯은 재생만 담당한다(계획 Task1 재생 규약).
/// 정지 일러스트 슬라이드쇼라 Timer·반복 애니메이션이 필요 없다: 페이지 전환은
/// AnimatedSwitcher(유한 페이드)만으로 표현한다(pumpAndSettle 안전, 전역 제약).
/// 사진 테두리는 아트 에셋 자체의 스타일(낡은 사진 테두리, 설계 §5)이라 위젯이
/// 따로 그리지 않는다 — gameImage를 그대로 재사용.
class MemoryPlayer extends StatefulWidget {
  final GameCtx ctx;
  final List<MemoryPage> pages;
  final VoidCallback onDone;

  const MemoryPlayer({
    super.key,
    required this.ctx,
    required this.pages,
    required this.onDone,
  }) : assert(pages.length > 0, '회상 페이지는 최소 1장 필요');

  @override
  State<MemoryPlayer> createState() => _MemoryPlayerState();
}

class _MemoryPlayerState extends State<MemoryPlayer> {
  int _index = 0;
  bool _done = false; // onDone 원샷 가드(연타 방지 — DialSafe/RubbableScene과 동일 패턴)

  void _onTap() {
    if (_index < widget.pages.length - 1) {
      setState(() => _index++);
      return;
    }
    if (_done) return; // 마지막 페이지 연타에도 onDone은 한 번만
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.pages[_index];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        color: const Color(0xFF14101C), // 어두운 회상 배경
        child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 56),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_index),
                  children: [
                    Expanded(child: Center(child: gameImage(page.image))),
                    const SizedBox(height: 16),
                    Text(
                      page.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFE8DCC4), fontSize: 16, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Text(
              strMemoryTapHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
