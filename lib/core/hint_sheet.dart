import 'package:flutter/material.dart';

import 'hint_service.dart';
import 'manor_theme.dart';
import 'models.dart';
import 'strings.dart';

void showHintSheet(BuildContext context, Room room, HintService hints) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF21142E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: manorGold, width: 1.4)),
            boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 24)],
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B557B),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: manorPanelSoft,
                      border: Border.all(color: manorGold),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: manorGoldBright,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          strHintTitle,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${room.name}의 단서를 차근차근 살펴보세요',
                          style: const TextStyle(
                            color: manorMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const ManorRule(),
              const SizedBox(height: 12),
              for (final h in room.hints)
                _HintCard(room: room, hints: hints, hint: h, refresh: setState),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HintCard extends StatelessWidget {
  final Room room;
  final HintService hints;
  final PuzzleHint hint;
  final StateSetter refresh;

  const _HintCard({
    required this.room,
    required this.hints,
    required this.hint,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = hints.unlocked(hint.puzzleId);
    final solved = hint.solved?.call(hints.s) ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: solved ? const Color(0xE6294038) : manorPanelSoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: solved ? const Color(0xFF76B889) : const Color(0xFF5D466D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                solved ? Icons.check_circle_outline : Icons.key_outlined,
                color: solved ? const Color(0xFF9AD7A9) : manorGoldBright,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint.title,
                  style: TextStyle(
                    color: solved ? const Color(0xFFB7E4C2) : manorGoldBright,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (solved)
                const Text(
                  '해결',
                  style: TextStyle(color: Color(0xFF9AD7A9), fontSize: 11),
                ),
            ],
          ),
          for (var i = 0; i < unlocked; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF5B4370),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      hint.steps[i],
                      style: const TextStyle(
                        color: manorCream,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (unlocked < 3) _nextStepControl(room, hints, hint, refresh),
        ],
      ),
    );
  }
}

/// 다음 힌트 단계: 시간 잠금 중이면 남은 시간 표시, 열렸으면 기존 버튼.
Widget _nextStepControl(
  Room room,
  HintService hints,
  PuzzleHint h,
  StateSetter setState,
) {
  final remain = hints.lockRemaining(room.id, hints.unlocked(h.puzzleId) + 1);
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: remain > 0
        ? Row(
            children: [
              const Icon(
                Icons.hourglass_bottom,
                color: Color(0xFF887897),
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                strHintLockedIn(remain),
                style: const TextStyle(color: Color(0xFF9A899F), fontSize: 12),
              ),
            ],
          )
        : OutlinedButton.icon(
            key: Key('hint_btn_${h.puzzleId}'),
            onPressed: () {
              hints.unlockNext(room.id, h.puzzleId);
              setState(() {});
            },
            icon: const Icon(Icons.lock_open_outlined, size: 17),
            label: const Text(strHintFree),
            style: OutlinedButton.styleFrom(
              foregroundColor: manorGoldBright,
              side: const BorderSide(color: manorGold),
            ),
          ),
  );
}
