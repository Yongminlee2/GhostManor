import 'package:flutter/material.dart';
import 'hint_service.dart';
import 'models.dart';
import 'strings.dart';

void showHintSheet(BuildContext context, Room room, HintService hints) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF241B36),
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(strHintTitle,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final h in room.hints) ...[
              Row(children: [
                Expanded(
                    child: Text(h.title,
                        style: const TextStyle(
                            color: Color(0xFFFFB74D), fontSize: 15))),
                if (h.solved?.call(hints.s) ?? false)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ]),
              for (var i = 0; i < hints.unlocked(h.puzzleId); i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${i + 1}. ${h.steps[i]}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              if (hints.unlocked(h.puzzleId) < 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: Key('hint_btn_${h.puzzleId}'),
                    onPressed: () async {
                      final r = await hints.unlockNext(h.puzzleId);
                      if (r == HintOutcome.adFailed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(strAdFailed)));
                      }
                      setState(() {});
                    },
                    child: Text(hints.unlocked(h.puzzleId) == 0
                        ? strHintFree
                        : strHintByAd),
                  ),
                ),
              const Divider(color: Color(0xFF4A3A6B)),
            ],
          ],
        ),
      ),
    ),
  );
}
