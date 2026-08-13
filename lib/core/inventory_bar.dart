import 'package:flutter/material.dart';
import '../rooms/items.dart';
import 'game_state.dart';
import 'manor_theme.dart';
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
        height: 96,
        decoration: const BoxDecoration(
          color: Color(0xFF21142E),
          border: Border(top: BorderSide(color: manorGold, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 9,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              margin: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF382548),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: manorGold.withValues(alpha: 0.7)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_outline, color: manorGoldBright, size: 22),
                  SizedBox(height: 5),
                  Text(
                    '소지품',
                    style: TextStyle(
                      color: manorMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: s.inventory.where(itemsById.containsKey).isEmpty
                  ? const Center(
                      child: Text(
                        '조사하며 찾은 물건이 여기에 보관됩니다',
                        style: TextStyle(
                          color: Color(0xFF806F91),
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 8,
                      ),
                      // 레지스트리에 없는 id(구버전 세이브 잔재)는 조용히 건너뛴다.
                      children: [
                        for (final id in s.inventory)
                          if (itemsById.containsKey(id)) _slot(id, s),
                      ],
                    ),
            ),
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
        width: 72,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A3658), Color(0xFF2A1C38)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? manorGoldBright : const Color(0xFF655079),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [const BoxShadow(color: Color(0x99D9A85F), blurRadius: 9)]
              : const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  item.icon,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      item.name,
                      style: const TextStyle(color: manorMuted, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: const BoxDecoration(
                color: Color(0xB3160E20),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? manorGoldBright : manorCream,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
