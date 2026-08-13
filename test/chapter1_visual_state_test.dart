import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';
import 'package:ghostmanor/rooms/room2_living.dart';
import 'package:ghostmanor/rooms/room3_study.dart';
import 'package:ghostmanor/rooms/room4_kitchen.dart';
import 'package:ghostmanor/rooms/room5_cellar.dart';
import 'package:ghostmanor/rooms/room6_attic.dart';

Scene wall(Room room, String id) => room.walls.firstWhere((s) => s.id == id);

String background(Scene scene, GameState state) =>
    scene.imageFor?.call(state) ?? scene.image!;

bool visible(SceneOverlay overlay, GameState state) => overlay.when(state);

void main() {
  test(
    'legacy kitchen pot softlock save restores still-needed ingredients',
    () {
      final state = GameState.fromJson({
        'flags': {
          'entered_kitchen': 1,
          'kitchen_r_got_bottle': 1,
          'kitchen_r_got_mushroom': 1,
          'kitchen_r_got_kettle': 1,
          'kitchen_r_ice_looted': 1,
          'kitchen_r_pot_stage': 0,
        },
        'inventory': <String>[],
        'selectedItem': null,
        'roomIndex': 3,
        'sceneIndex': 0,
      });

      expect(
        state.inventory,
        containsAll(['water_bottle', 'mushroom', 'herb', 'kettle_singing']),
      );
    },
  );

  test('현관 수집품은 획득 뒤 빈 상태 이미지로 전환된다', () {
    final state = GameState();
    final room = buildFoyer();
    final mailbox = room.closeups['mailbox']!;
    final empty = mailbox.overlays.singleWhere(
      (o) => o.image.endsWith('foyer_mailbox_empty.png'),
    );
    expect(visible(empty, state), isFalse);
    state.setFlag('foyer_r_got_letter', 1);
    expect(visible(empty, state), isTrue);
  });

  test('거실 금고는 보상 지급 뒤 빈 금고판만 표시한다', () {
    final state = GameState()..setFlag('living_r_safe_open', 1);
    final scene = wall(buildLiving(), 'living_c');
    final shown = scene.overlays
        .where((o) => visible(o, state))
        .map((o) => o.image)
        .toList();
    expect(shown, contains('assets/scenes/living_c_safe_empty.png'));
    expect(shown, isNot(contains('assets/scenes/living_c_safe_open.png')));
  });

  test('서재 지구본 열쇠 제거판은 움직이는 반쪽 아래의 배경으로 교체된다', () {
    final state = GameState();
    final scene = wall(buildStudy(), 'study_b');
    expect(background(scene, state), 'assets/scenes/study_b_plate.png');
    state.setFlag('study_r_got_key', 1);
    expect(background(scene, state), 'assets/scenes/study_b_plate_empty.png');
    expect(scene.objects, hasLength(2));
  });

  test('주방 병·버섯·부지깽이는 각각 획득 상태에 맞는 벽면을 쓴다', () {
    final state = GameState();
    final room = buildKitchen();
    final a = wall(room, 'kitchen_a');
    final c = wall(room, 'kitchen_c');
    expect(background(a, state), 'assets/scenes/kitchen_a.png');
    state.setFlag('kitchen_r_got_bottle', 1);
    expect(background(a, state), 'assets/scenes/kitchen_a_no_bottle.png');
    state.setFlag('kitchen_r_got_mushroom', 1);
    expect(background(a, state), 'assets/scenes/kitchen_a_empty.png');
    state.setFlag('kitchen_r_got_bottle', 0);
    expect(background(a, state), 'assets/scenes/kitchen_a_empty_jar.png');
    state.setFlag('kitchen_r_got_poker', 1);
    expect(background(c, state), 'assets/scenes/kitchen_c_no_poker.png');
  });

  test('지하실 선반 열쇠 낙하 뒤 원래 선반에서는 사라진다', () {
    final state = GameState();
    final scene = wall(buildCellar(), 'cellar_a');
    expect(background(scene, state), 'assets/scenes/cellar_a.png');
    state.setFlag('cellar_r_key_dropped', 1);
    expect(background(scene, state), 'assets/scenes/cellar_a_key_removed.png');
  });

  test('지하실 야광 퓨즈 표시는 획득 뒤 꺼지고, 열린 상자는 어둠막 아래다', () {
    final state = GameState();
    final room = buildCellar();
    final a = wall(room, 'cellar_a');
    final glow = a.overlays.singleWhere(
      (o) => o.image.endsWith('cellar_a_glow.png'),
    );
    expect(visible(glow, state), isTrue);
    state.setFlag('cellar_r_got_fuse', 1);
    expect(visible(glow, state), isFalse);

    final c = wall(room, 'cellar_c');
    final emptyIndex = c.overlays.indexWhere(
      (o) => o.image.endsWith('cellar_c_boxb_empty.png'),
    );
    final darkIndex = c.overlays.indexWhere(
      (o) => o.image.endsWith('cellar_c_dark.png'),
    );
    expect(emptyIndex, lessThan(darkIndex));
  });

  test('다락 궤짝 상태판은 작은 칸에 찌그러뜨리지 않고 전체 벽면으로 합성한다', () {
    final scene = wall(buildAttic(), 'attic_c');
    final chestStates = scene.overlays.where(
      (o) => o.image.contains('attic_c_chest_'),
    );
    for (final overlay in chestStates) {
      expect(overlay.area, const Rect.fromLTWH(0, 0, 1, 1));
    }
  });
}
