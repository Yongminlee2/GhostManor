import 'package:flutter/material.dart';
import '../rooms/items.dart';
import 'game_state.dart';
import 'models.dart';

class InventoryBar extends StatelessWidget {
  final GameCtx ctx;
  const InventoryBar({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => Container(
        height: 84,
        color: const Color(0xFF241B36),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          // 레지스트리에 없는 id(구버전 세이브 잔재)는 조용히 건너뛴다 —
          // 여기서 안 거르면 아래 _slot의 강제 언랩이 렌더를 통째로 죽인다.
          children: [
            for (final id in s.inventory)
              if (itemsById.containsKey(id)) _slot(id, s),
          ],
        ),
      ),
    );
  }

  Widget _slot(String id, GameState s) {
    final item = itemsById[id]!;
    final selected = s.selectedItem == id;
    return GestureDetector(
      key: Key('inv_$id'),
      onTap: () {
        if (selected) {
          s.select(null);
          return;
        }
        final prev = s.selectedItem;
        if (prev != null && tryCombine(s, prev, id)) {
          ctx.sfx('combine');
          return;
        }
        s.select(id);
      },
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF32264C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? const Color(0xFFFFB74D) : const Color(0xFF4A3A6B),
              width: selected ? 2.5 : 1),
        ),
        child: Column(children: [
          Expanded(
            child: Image.asset(item.icon,
                errorBuilder: (_, _, _) => Center(
                    child: Text(item.name,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)))),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(item.name,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ]),
      ),
    );
  }
}
