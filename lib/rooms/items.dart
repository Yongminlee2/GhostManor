import '../core/game_state.dart';

class Item {
  final String id;
  final String name;
  final String? iconOverride; // 다른 아이템과 아이콘을 공유할 때만 지정
  const Item(this.id, this.name, {this.iconOverride});
  String get icon => iconOverride ?? 'assets/items/$id.png';
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
  // 지하실 리마스터: 배전반 2슬롯 중 두 번째 퓨즈 — 부품이 동일해 신규 아이콘을
  // 만들지 않고 fuse.png를 공유한다(art/remaster-assets.md 비고). 인벤토리에
  // fuse와 fuse2가 동시에 들어올 수 있어 id는 분리(InventoryBar가 Key('inv_$id')로
  // 슬롯을 구분하므로 같은 id 두 개가 동시에 있으면 위젯 키 충돌이 난다).
  'fuse2': Item('fuse2', '낡은 퓨즈', iconOverride: 'assets/items/fuse.png'),
  'key_cellar': Item('key_cellar', '녹슨 열쇠'),
  'note4': Item('note4', '음표 카드 ♪구름'),
  'shred': Item('shred', '자수 조각'),

  // ── 챕터 2: 방 7 계단홀·복도 ──
  'winder': Item('winder', '태엽 손잡이'),
  'key_f2bed': Item('key_f2bed', '리본 달린 안방 열쇠'),
  'emblem_hall': Item('emblem_hall', '사진틀 문양'),

  // ── 챕터 2: 방 8 안방 ──
  'brooch': Item('brooch', '브로치'),
  'hairpin': Item('hairpin', '머리핀'),
  'button_gh': Item('button_gh', '단추'),
  'comb': Item('comb', '빗'), // 미끼(유령 물건 아님) — 보석함이 거부한다.
  'thread_blue1': Item('thread_blue1', '파란 실타래'),
  // 파란 실 2타래가 동시에 인벤토리에 들어올 수 있어 id를 분리했다
  // (InventoryBar가 Key('inv_$id')로 슬롯을 구분 — 위 fuse/fuse2와 동일 이유).
  // 전용 아이콘은 아직 없어 thread_blue1과 같은 경로를 공유(라벨 폴백으로 동작).
  'thread_blue2':
      Item('thread_blue2', '파란 실타래', iconOverride: 'assets/items/thread_blue1.png'),
  'silver_thread': Item('silver_thread', '은실 타래'),
  'key_f2child': Item('key_f2child', '작은 장난감풍 열쇠'),
  'emblem_bed': Item('emblem_bed', '실타래 매듭 문양'),

  // ── 챕터 2: 방 9 아이 방 ──
  'gear_toy': Item('gear_toy', '작은 놋쇠 톱니'),
  'key_f2lab': Item('key_f2lab', '잉크 얼룩 묻은 서고 열쇠'),
  'emblem_child': Item('emblem_child', '톱니 문양'),
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
