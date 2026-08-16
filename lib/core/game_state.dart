import 'package:flutter/foundation.dart';

/// 게임의 유일한 상태. UI는 이 객체에만 반응한다 (스펙 §4.4).
class GameState extends ChangeNotifier {
  static const currentSaveVersion = 2;
  Map<String, int> flags = {};
  List<String> inventory = [];
  String? selectedItem;
  int roomIndex = 0;
  int sceneIndex = 0;
  String? closeupId; // 일시 상태 — 저장 안 함
  String? dialog; // 일시 상태 — 저장 안 함
  String? flyItem; // 일시 상태 — 저장 안 함 (인벤토리 플라이 연출용)
  int flySeq = 0; // 일시 상태 — 저장 안 함 (증가할 때마다 새 플라이 트리거)

  int flag(String key) => flags[key] ?? 0;

  void setFlag(String key, int value) {
    flags[key] = value;
    notifyListeners();
  }

  void addFlag(String key, [int delta = 1]) => setFlag(key, flag(key) + delta);

  bool has(String itemId) => inventory.contains(itemId);

  void give(String itemId) {
    inventory.add(itemId);
    flyItem = itemId;
    flySeq++;
    notifyListeners();
  }

  void take(String itemId) {
    inventory.remove(itemId);
    if (selectedItem == itemId) selectedItem = null;
    notifyListeners();
  }

  void select(String? itemId) {
    selectedItem = itemId;
    notifyListeners();
  }

  void say(String? text) {
    dialog = text;
    notifyListeners();
  }

  void openCloseup(String id) {
    closeupId = id;
    notifyListeners();
  }

  void closeCloseup() {
    closeupId = null;
    notifyListeners();
  }

  void goScene(int index) {
    sceneIndex = index;
    closeupId = null;
    notifyListeners();
  }

  void goRoom(int index) {
    roomIndex = index;
    sceneIndex = 0;
    closeupId = null;
    dialog = null;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'saveVersion': currentSaveVersion,
    'flags': flags,
    'inventory': inventory,
    'selectedItem': selectedItem,
    'roomIndex': roomIndex,
    'sceneIndex': sceneIndex,
  };

  static GameState fromJson(Map<String, dynamic> json) {
    final s = GameState();
    s.flags = Map<String, int>.from(json['flags'] as Map);
    s.inventory = List<String>.from(json['inventory'] as List);
    s.selectedItem = json['selectedItem'] as String?;
    s.roomIndex = json['roomIndex'] as int;
    s.sceneIndex = json['sceneIndex'] as int;
    s._repairKitchenPotSoftlock();
    return s;
  }

  /// 구버전 냄비 로직(오답 시 단계 초기화)이 만든 챕터 1 세이브를 보정한다.
  /// 이미 획득처를 턴 재료 중 저장된 단계에서 아직 필요한 것만 되돌려준다.
  void _repairKitchenPotSoftlock() {
    final stage = flag('kitchen_r_pot_stage');
    if (stage >= 4 || flag('entered_kitchen') == 0) return;

    void restore(String itemId, bool sourceCollected, int requiredAfterStage) {
      if (!sourceCollected || stage >= requiredAfterStage || has(itemId)) {
        return;
      }
      inventory.add(itemId);
    }

    final bottleWasConverted =
        flag('kitchen_r_got_bottle') >= 1 && !has('empty_bottle');
    restore('water_bottle', bottleWasConverted, 1);
    restore('mushroom', flag('kitchen_r_got_mushroom') >= 1, 2);
    restore('herb', flag('kitchen_r_ice_looted') >= 1, 3);
    restore('kettle_singing', flag('kitchen_r_got_kettle') >= 1, 4);
  }
}
