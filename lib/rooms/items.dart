import '../core/game_state.dart';

class Item {
  final String id;
  final String name;
  const Item(this.id, this.name);
  String get icon => 'assets/items/$id.png';
}

/// 전 챕터 아이템 전역 레지스트리 (스펙 §4.3). 방 추가 시 여기에만 등록.
const Map<String, Item> itemsById = {
  'match': Item('match', '성냥'),
  'candle': Item('candle', '양초'),
  'lit_candle': Item('lit_candle', '불 켠 초'),
  'key_foyer': Item('key_foyer', '낡은 열쇠'),
  'letter1': Item('letter1', '낡은 편지'),
  'remote': Item('remote', '리모컨'),
  'key_living': Item('key_living', '거실 열쇠'),
  'note1': Item('note1', '음표 카드 ♪달'),
  'oil': Item('oil', '기름병'),
  'knob': Item('knob', '다이얼 손잡이'),
  'lens': Item('lens', '놋쇠 렌즈'),
  'key_study': Item('key_study', '서재 열쇠'),
  'note2': Item('note2', '음표 카드 ♪별'),
  'empty_bottle': Item('empty_bottle', '빈 병'),
  'water_bottle': Item('water_bottle', '이끼물 병'),
  'mushroom': Item('mushroom', '말린 버섯'),
  'kettle_singing': Item('kettle_singing', '노래하는 주전자'),
  'poker': Item('poker', '부지깽이'),
  'poker_hot': Item('poker_hot', '달군 부지깽이'),
  'herb': Item('herb', '마른 약초'),
  'key_kitchen': Item('key_kitchen', '뒷문 열쇠'),
  'note3': Item('note3', '음표 카드 ♪해'),
  'fuse': Item('fuse', '낡은 퓨즈'),
  'key_cellar': Item('key_cellar', '녹슨 열쇠'),
  'note4': Item('note4', '음표 카드 ♪구름'),
};

/// 키 = 두 id를 사전순 정렬해 '+'로 연결. 주방 리마스터로 수프는 인벤토리
/// 조합이 아니라 월드 냄비 슬롯(room4_kitchen.dart의 usePotIngredient)이 됐다 —
/// mushroom+water_bottle/kettle_singing+soup_base 항목은 삭제(설계 §4-2).
const Map<String, String> _combineTable = {
  'candle+match': 'lit_candle',
};

String? combineResult(String a, String b) {
  final ids = [a, b]..sort();
  return _combineTable['${ids[0]}+${ids[1]}'];
}

/// 성공 시 재료 2개 제거 + 결과 지급 후 true (스펙 §4.3 전역 조합 규칙).
bool tryCombine(GameState s, String a, String b) {
  final result = combineResult(a, b);
  if (result == null) return false;
  s.take(a);
  s.take(b);
  s.give(result);
  return true;
}
