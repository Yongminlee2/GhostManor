import 'package:flutter/widgets.dart';
import '../core/models.dart';
import '../core/strings.dart';

// ── 방 정의 ──

Room buildKitchen() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  const counterArea = Rect.fromLTWH(0.04, 0.48, 0.18, 0.18);
  const stoveArea = Rect.fromLTWH(0.20, 0.42, 0.28, 0.30);
  const gukjaArea = Rect.fromLTWH(0.68, 0.34, 0.22, 0.36);
  const jarArea = Rect.fromLTWH(0.05, 0.12, 0.16, 0.14);
  const sinkArea = Rect.fromLTWH(0.06, 0.52, 0.20, 0.18);
  const cupboard1Area = Rect.fromLTWH(0.34, 0.28, 0.10, 0.14);
  const cupboard2Area = Rect.fromLTWH(0.46, 0.28, 0.10, 0.14);
  const cupboard3Area = Rect.fromLTWH(0.58, 0.28, 0.10, 0.14);
  const cupboard4Area = Rect.fromLTWH(0.70, 0.28, 0.10, 0.14);
  const backdoorArea = Rect.fromLTWH(0.62, 0.52, 0.26, 0.40);

  // 속이 꽉 찬 찬장 문(1·3·4) 공용: 둔탁한 노크음+대사만 반복(스펙 §3.3-6 —
  // 소리로 구분되는 단서는 대사로도 묘사해 음소거 유저도 구분 가능해야 함).
  void knockDull(GameCtx c) {
    c.sfx('locked');
    c.say(strKitchenKnockDull);
  }

  return Room(
    id: 'kitchen',
    name: '주방',
    onEnter: (c) => c.say(strKitchenIntro),
    cleared: flagSet('kitchen_done'),
    walls: [
      // 벽면 A: 화덕·조리대·국자 벽
      Scene(id: 'kitchen_a', image: 'assets/scenes/kitchen_a.png', hotspots: [
        Hotspot(
            id: 'counter',
            area: counterArea,
            onTap: (c) {
              if (c.s.flag('kitchen_got_bottle') == 0) {
                c.s.setFlag('kitchen_got_bottle', 1);
                c.give('empty_bottle');
                c.say(strKitchenBottle);
              } else {
                c.say(strKitchenCounterEmpty);
              }
            }),
        Hotspot(
            id: 'stove',
            area: stoveArea,
            onTap: (c) => c.say(strKitchenStove)),
        Hotspot(
            id: 'gukja',
            area: gukjaArea,
            onTap: (c) {
              final s = c.s;
              if (c.using('ghost_soup')) {
                c.consume('ghost_soup');
                s.setFlag('kitchen_ghost_fed', 1);
                c.give('key_kitchen');
                c.give('note3');
                c.sfx('sparkle');
                c.say(strKitchenFed);
              } else if (s.flag('kitchen_ghost_fed') >= 1) {
                c.say(strKitchenGukjaHappy);
              } else {
                c.sfx('ghost_giggle');
                c.say(strKitchenGukjaAsk);
              }
            }),
        Hotspot(
            id: 'jar',
            area: jarArea,
            onTap: (c) {
              if (c.s.flag('kitchen_got_mushroom') == 0) {
                c.s.setFlag('kitchen_got_mushroom', 1);
                c.give('mushroom');
                c.say(strKitchenJar);
              } else {
                c.say(strKitchenJarEmpty);
              }
            }),
      ]),
      // 벽면 B: 찬장·싱크대·뒷문 벽
      Scene(id: 'kitchen_b', image: 'assets/scenes/kitchen_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/kitchen_b_cup2_open.png',
            area: cupboard2Area,
            when: flagSet('kitchen_hollow_found')),
        SceneOverlay(
            image: 'assets/scenes/kitchen_b_door_open.png',
            area: backdoorArea,
            when: flagSet('kitchen_door_open')),
      ], hotspots: [
        Hotspot(
            id: 'sink',
            area: sinkArea,
            onTap: (c) {
              if (c.using('empty_bottle')) {
                c.consume('empty_bottle');
                c.give('water_bottle');
                c.sfx('sparkle');
                c.say(strKitchenFill);
              } else {
                c.say(strKitchenSink);
              }
            }),
        Hotspot(id: 'cupboard1', area: cupboard1Area, onTap: knockDull),
        Hotspot(
            id: 'cupboard2',
            area: cupboard2Area,
            onTap: (c) {
              final s = c.s;
              if (s.flag('kitchen_hollow_found') == 0) {
                s.setFlag('kitchen_hollow_found', 1);
                c.sfx('unlock');
                c.say(strKitchenKnockHollow);
              } else if (s.flag('kitchen_got_kettle') == 0 &&
                  s.flag('kitchen_hollow_found') == 1) {
                s.setFlag('kitchen_got_kettle', 1);
                c.give('kettle_singing');
                c.say(strKitchenKettle);
              } else {
                c.say(strKitchenCupboardEmpty);
              }
            }),
        Hotspot(id: 'cupboard3', area: cupboard3Area, onTap: knockDull),
        Hotspot(id: 'cupboard4', area: cupboard4Area, onTap: knockDull),
        Hotspot(
            id: 'backdoor',
            area: backdoorArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('kitchen_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('kitchen_done', 1);
              } else if (c.using('key_kitchen')) {
                c.consume('key_kitchen');
                c.sfx('unlock');
                s.setFlag('kitchen_door_open', 1);
                c.say(strKitchenDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strKitchenDoorLocked);
              }
            }),
      ]),
    ],
    hints: [
      PuzzleHint(puzzleId: 'p_kitchen_soup', title: '유령 수프 만들기', steps: [
        '국자의 대사에 재료 세 가지가 다 나와요',
        '조리대의 병 + 싱크대 물, 항아리의 버섯 — 그리고 세 번째 재료는 소리로 찾아요. 인벤토리에서 둘씩 조합',
        '정답: 병을 싱크대에 사용→이끼물 병, 버섯+이끼물 병=수프 베이스, 수프 베이스+노래하는 주전자=유령 수프',
      ], solved: (s) => s.has('ghost_soup') || s.flag('kitchen_ghost_fed') >= 1),
      PuzzleHint(puzzleId: 'p_kitchen_kettle', title: '세 번째 재료', steps: [
        '찬장 문들을 하나씩 두드려 보세요. 소리가 다른 곳이 있어요',
        '"통통" 하고 속이 빈 울림이 나는 문이 정답',
        '정답: 왼쪽에서 2번째 찬장 문 — 그 안에 노래하는 주전자',
      ], solved: (s) => s.flag('kitchen_got_kettle') >= 1),
      PuzzleHint(puzzleId: 'p_kitchen_door', title: '뒷문', steps: [
        '열쇠는 국자가 갖고 있어요',
        '국자가 원하는 걸 만들어 주세요',
        '정답: 유령 수프를 선택하고 국자를 탭 → 열쇠 획득 → 뒷문',
      ], solved: (s) => s.flag('kitchen_done') >= 1),
    ],
  );
}
