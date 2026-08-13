import 'package:flutter/material.dart';
import 'game_state.dart';
import 'models.dart';
import 'strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 헤드리스 테스트용, 스펙 §8) ──

/// 다이얼 휠 i(0-based) 탭: 0~9 순환.
void tapDialWheel(GameState s, String flagPrefix, int i) {
  final key = '${flagPrefix}_d$i';
  s.setFlag(key, (s.flag(key) + 1) % 10);
}

/// 현재 휠 값들이 code(각 자리 '0'~'9' 문자)와 전부 일치하는지.
bool checkDialCode(GameState s, String flagPrefix, String code) {
  for (var i = 0; i < code.length; i++) {
    if (s.flag('${flagPrefix}_d$i') != int.parse(code[i])) return false;
  }
  return true;
}

/// 숫자 다이얼 자물쇠 커스텀 위젯 — 방마다 다른 자리수·정답·배경으로 재사용
/// (거실 4자리 금고, 다락 3자리 궤짝 등). 배경 이미지는 이 위젯이 그리지 않는다 —
/// 호출부가 Scene.custom에서 배경 위에 이 위젯을 겹쳐 쌓는다(스펙: 위젯은
/// "그 위에 올라앉는" 존재일 뿐, 배경 아트와 분리 — art/remaster-assets.md 참고).
/// 휠 탭마다 0~9 순환, 확인 버튼 탭 시 code와 비교: 일치하면 onOpened를 1회만
/// 호출(RubbableScene._done과 동일한 위젯 생애 가드), 불일치하면 잠김음+오답
/// 대사 후 전체 휠을 0으로 리셋.
class DialSafe extends StatefulWidget {
  final GameCtx ctx;
  final int digits;
  final String code;
  final String flagPrefix;
  final void Function(GameCtx c) onOpened;
  final String wrongSay;

  const DialSafe({
    super.key,
    required this.ctx,
    required this.digits,
    required this.code,
    required this.flagPrefix,
    required this.onOpened,
    required this.wrongSay,
  }) : assert(code.length == digits, 'code 자리수는 digits와 일치해야 함');

  @override
  State<DialSafe> createState() => _DialSafeState();
}

class _DialSafeState extends State<DialSafe> {
  bool _opened = false; // onOpened 원샷 가드(이번 위젯 생애 전용)

  void _confirm() {
    final s = widget.ctx.s;
    if (checkDialCode(s, widget.flagPrefix, widget.code)) {
      if (!_opened) {
        _opened = true;
        widget.onOpened(widget.ctx);
      }
      return;
    }
    widget.ctx.sfx('locked');
    widget.ctx.say(widget.wrongSay);
    for (var i = 0; i < widget.digits; i++) {
      s.setFlag('${widget.flagPrefix}_d$i', 0);
    }
  }

  Widget _wheel(GameState s, int i) {
    final digit = s.flag('${widget.flagPrefix}_d$i');
    return GestureDetector(
      key: Key('dial_wheel_$i'),
      onTap: () {
        tapDialWheel(s, widget.flagPrefix, i);
        widget.ctx.sfx('metal_click');
      },
      child: Container(
        width: 44,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xE6241B36),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7C5CC4)),
        ),
        child: Text('$digit',
            style: const TextStyle(color: Colors.white, fontSize: 22)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.digits; i++) _wheel(s, i),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('dial_confirm'),
              onPressed: _confirm,
              child: const Text(strOk),
            ),
          ]),
        ),
      ),
    );
  }
}
