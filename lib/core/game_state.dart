import 'package:flutter/foundation.dart';

/// 게임의 유일한 상태. UI는 이 객체에만 반응한다 (스펙 §4.4).
class GameState extends ChangeNotifier {
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
    return s;
  }
}
