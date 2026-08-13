import 'package:flutter/material.dart';
import 'game_state.dart';
import 'models.dart';
import 'scene_view.dart';
import 'strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 헤드리스 테스트용, 스펙 §8) ──

/// 정답 순서(왼쪽부터 △→○→□ = 인덱스 0,1,2 — cellar_b_switches.png의 물리
/// 배치가 이미 이 순서라 cellar_b_glow2.png의 세로 나열과 그대로 대응한다).
const switchOrder = [0, 1, 2];

/// 스위치 i(0=△,1=○,2=□) 탭. 정답 순서대로면 '${flagPrefix}_seq' +1, 3 도달
/// 시 cellar_r_power=1(전력 복구 — 판정 로직). 틀린 순서면 0으로 리셋 —
/// 개별 스위치는 별도 상태를 갖지 않고 위젯이 i<seq로 "올라간 스위치 개수"를
/// 파생 렌더하므로, 리셋되면 전부 한꺼번에 다시 내려간 것처럼 보인다(room3
/// tapBook과 동일한 진행 카운터 패턴). 이미 복구됐으면 no-op(tapBook의
/// nook_open 가드와 동일한 이유 — 완료 후 재탭이 상태를 어지럽히지 않게).
void flipSwitch(GameState s, String flagPrefix, int i) {
  if (s.flag('cellar_r_power') >= 1) return;
  final seqKey = '${flagPrefix}_seq';
  final seq = s.flag(seqKey);
  if (switchOrder[seq] == i) {
    final next = seq + 1;
    s.setFlag(seqKey, next);
    if (next == switchOrder.length) s.setFlag('cellar_r_power', 1);
  } else {
    s.setFlag(seqKey, 0);
  }
}

/// 배전반 스위치 3개 클로즈업 — DialSafe 스타일(BuildContext 무의존,
/// Timer 금지, AnimatedBuilder(animation: s)만). 스위치 자체는 상시 표시되는
/// cellar_b_switches.png(전부 내림 상태로 그려짐) 위에, 탭 가능한 3분할
/// 영역과 "올라간" 스위치를 표시하는 하이라이트만 이 위젯이 얹는다.
class SwitchPanel extends StatelessWidget {
  final GameCtx ctx;
  final String flagPrefix;
  const SwitchPanel({super.key, required this.ctx, this.flagPrefix = 'cellar_r_switch'});

  void _tap(int i) {
    final s = ctx.s;
    final beforeSeq = s.flag('${flagPrefix}_seq');
    final wasPower = s.flag('cellar_r_power') >= 1;
    flipSwitch(s, flagPrefix, i);
    ctx.sfx('switch_click');
    if (!wasPower && s.flag('cellar_r_power') >= 1) {
      ctx.say(strCellarLightOn);
    } else if (s.flag('${flagPrefix}_seq') == 0 && beforeSeq > 0) {
      ctx.say(strCellarRSwitchWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final seq = s.flag('${flagPrefix}_seq');
        return LayoutBuilder(builder: (context, box) {
          return Stack(children: [
            Positioned.fill(child: gameImage('assets/scenes/cellar_b_switches.png')),
            Positioned(
              left: box.maxWidth * 0.32,
              top: box.maxHeight * 0.37,
              width: box.maxWidth * 0.36,
              height: box.maxHeight * 0.37,
              child: Row(children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: GestureDetector(
                      key: Key('switch_$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _tap(i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: i < seq
                            ? BoxDecoration(
                                color: const Color(0x5527C93B),
                                border: Border.all(color: const Color(0xFF27C93B), width: 3),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                      ),
                    ),
                  ),
              ]),
            ),
          ]);
        });
      },
    );
  }
}
