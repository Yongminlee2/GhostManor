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
  'remote': Item('remote', '리모컨'),
  'key_living': Item('key_living', '거실 열쇠'),
  'note1': Item('note1', '음표 카드 ♪달'),
  'oil': Item('oil', '기름병'),
  'crank': Item('crank', '놋쇠 크랭크'),
  'key_study': Item('key_study', '서재 열쇠'),
  'note2': Item('note2', '음표 카드 ♪별'),
};

/// 키 = 두 id를 사전순 정렬해 '+'로 연결.
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
