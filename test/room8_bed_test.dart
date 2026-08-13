import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/memory_player.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room8_bed.dart';
import 'solutions.dart';

void main() {
  late GameState s;
  late GameCtx c;
  late Room room;

  void tap(String sceneId, String hotspotId) =>
      tapSpot(room, s, c, sceneId, hotspotId);

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
    room = buildBed();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveBed(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('병렬 단언: 진입 직후 T1(거울)·T2(리본 서랍) 둘 다 fresh 상태에서 탭 가능', () {
    final mirror = findHotspot(room, 'bed_b', 'mirror');
    final ribbons = findHotspot(room, 'bed_c', 'ribbon_drawer');
    expect(mirror.when?.call(s) ?? true, isTrue);
    expect(ribbons.when?.call(s) ?? true, isTrue);
  });

  test('벽면 핫스팟 총수 ≥15, 3벽 (하드코어 게이트)', () {
    expect(room.walls.length, 3);
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── T1 거울 차이 · 보석함 ──

  test('머리핀·브로치는 각각 한 번만 지급되고 이후엔 빈 대사', () {
    tap('bed_a', 'nightstand');
    expect(s.has('hairpin'), isTrue);
    tap('bed_a', 'nightstand');
    expect(s.dialog, strF2BedNightstandEmpty);
    expect(s.inventory.where((i) => i == 'hairpin').length, 1);

    tap('bed_b', 'brooch');
    expect(s.has('brooch'), isTrue);
    tap('bed_b', 'brooch');
    expect(s.dialog, strF2BedVanityEmpty);
  });

  test('옷장 뒤지기: 두 번 허탕 친 뒤 세 번째에 단추 발견', () {
    tap('bed_c', 'wardrobe');
    expect(s.closeupId, 'wardrobe');

    tap('wardrobe', 'search');
    expect(s.dialog, strF2BedWardrobeSearch1);
    expect(s.has('button_gh'), isFalse);

    tap('wardrobe', 'search');
    expect(s.dialog, strF2BedWardrobeSearch2);
    expect(s.has('button_gh'), isFalse);

    tap('wardrobe', 'search');
    expect(s.dialog, strF2BedWardrobeFound);
    expect(s.has('button_gh'), isTrue);

    tap('wardrobe', 'search');
    expect(s.dialog, strF2BedWardrobeEmpty);
    expect(s.inventory.where((i) => i == 'button_gh').length, 1);
  });

  test('부정: 미끼(빗)를 보석함에 넣으면 거부 전문 + 슬롯 변화 없음', () {
    s.give('comb');
    s.select('comb');
    tap('bed_b', 'jewelbox');
    expect(s.dialog, strF2BedJewelboxWrong);
    expect(s.has('comb'), isTrue); // 소모되지 않음
    expect(bedJewelboxFull(s), isFalse);
    expect(s.flag('f2_bed_jewelbox_open'), 0);
  });

  test('보석함 완성 후 재탭 시 보상이 중복 지급되지 않는다', () {
    for (final id in ['hairpin', 'brooch', 'button_gh']) {
      s.give(id);
      s.select(id);
      tap('bed_b', 'jewelbox');
    }
    expect(s.flag('f2_bed_jewelbox_open'), 1);
    expect(s.inventory.where((i) => i == 'silver_thread').length, 1);
    expect(s.inventory.where((i) => i == 'key_f2child').length, 1);

    tap('bed_b', 'jewelbox'); // 재탭
    expect(s.dialog, strF2BedJewelboxDone);
    expect(s.inventory.where((i) => i == 'silver_thread').length, 1);
  });

  // ── T2 자수 ──

  test('부정: 실 순서 오류(은실을 먼저) → 오답 전문 + 단계 리셋', () {
    s.give('silver_thread');
    s.select('silver_thread');
    tap('bed_c', 'embroidery');
    expect(s.dialog, strF2BedStitchWrong);
    expect(s.flag('f2_bed_stitch_stage'), 0);
    expect(s.has('silver_thread'), isTrue); // 소모되지 않음
  });

  test(
      '지식 게이트 아님: 리본 서랍을 한 번도 안 봐도 색 순서만 맞으면 자수 완성'
      '(현관 편지·hall 카펫과 동일 원칙)', () {
    s.give('thread_blue1');
    s.give('silver_thread');
    s.give('thread_blue2');

    s.select('thread_blue1');
    tap('bed_c', 'embroidery');
    s.select('silver_thread');
    tap('bed_c', 'embroidery');
    s.select('thread_blue2');
    tap('bed_c', 'embroidery');

    expect(s.flag('f2_bed_stitch_done'), 1);
    expect(s.flag('f2_bed_memory'), 0); // ribbon_drawer도 embroidery 재탭도 안 함
  });

  test('회상2: 자수 완성 후 자수틀 재탭 → 1회 재생(f2_bed_memory=1) + 재열람 가능', () {
    s.give('thread_blue1');
    s.give('silver_thread');
    s.give('thread_blue2');
    s.select('thread_blue1');
    tap('bed_c', 'embroidery');
    s.select('silver_thread');
    tap('bed_c', 'embroidery');
    s.select('thread_blue2');
    tap('bed_c', 'embroidery');
    expect(s.flag('f2_bed_stitch_done'), 1);

    tap('bed_c', 'embroidery');
    expect(s.closeupId, 'memory');
    expect(s.flag('f2_bed_memory'), 1);
    s.closeCloseup();

    // 재열람: 다시 탭해도 memory로 열린다(자수틀 앵커).
    tap('bed_c', 'embroidery');
    expect(s.closeupId, 'memory');
  });

  // ── 문 ──

  test('부정: key_f2child 없이 문 탭 → 잠김 대사, 안 열림', () {
    tap('bed_a', 'door');
    expect(s.dialog, strF2BedDoorLocked);
    expect(s.flag('f2_bed_door_open'), 0);
  });

  test('문 재탭 시 emblem_bed이 중복 지급되지 않는다', () {
    s.give('key_f2child');
    s.select('key_f2child');
    tap('bed_a', 'door'); // 잠금 해제
    tap('bed_a', 'door'); // 탈출
    tap('bed_a', 'door'); // 재탭
    expect(s.inventory.where((i) => i == 'emblem_bed').length, 1);
  });

  // ── 순수 함수 단위 테스트 ──

  group('putJewel / bedJewelboxFull', () {
    test('유령 물건 3개를 넣으면 순서 무관하게 가득 찬다', () {
      expect(putJewel(s, 'button_gh'), isTrue);
      expect(putJewel(s, 'brooch'), isTrue);
      expect(bedJewelboxFull(s), isFalse);
      expect(putJewel(s, 'hairpin'), isTrue);
      expect(bedJewelboxFull(s), isTrue);
    });

    test('미끼·미선택·중복 투입은 전부 false', () {
      expect(putJewel(s, 'comb'), isFalse);
      expect(putJewel(s, null), isFalse);
      expect(putJewel(s, 'brooch'), isTrue);
      expect(putJewel(s, 'brooch'), isFalse); // 중복
    });
  });

  group('stitchThread', () {
    test('파랑→은→파랑 순서면 매 단계 true, 3단계에서 완성 직전 상태', () {
      expect(stitchThread(s, 'thread_blue1'), isTrue);
      expect(stitchThread(s, 'silver_thread'), isTrue);
      expect(stitchThread(s, 'thread_blue2'), isTrue);
      expect(s.flag('f2_bed_stitch_stage'), 3);
    });

    test('순서가 틀리면 false + 0으로 리셋', () {
      stitchThread(s, 'thread_blue1'); // stage 1
      expect(stitchThread(s, 'thread_blue2'), isFalse); // 파랑 다음은 은이어야
      expect(s.flag('f2_bed_stitch_stage'), 0);
    });

    test('실이 아닌 아이템/미선택은 상태를 바꾸지 않고 false', () {
      expect(stitchThread(s, 'comb'), isFalse);
      expect(stitchThread(s, null), isFalse);
      expect(s.flag('f2_bed_stitch_stage'), 0);
    });
  });

  // ── 등록·힌트 ──

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in [
      'brooch',
      'hairpin',
      'button_gh',
      'comb',
      'thread_blue1',
      'thread_blue2',
      'silver_thread',
      'key_f2child',
      'emblem_bed',
    ]) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('closeups의 key는 Scene.id와 일치(모델 assert가 이미 강제하지만 명시적으로도 확인)', () {
    for (final entry in room.closeups.entries) {
      expect(entry.key, entry.value.id);
    }
  });

  test('힌트 3개: p_f2_bed_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_f2_bed_mirror', 'p_f2_bed_stitch', 'p_f2_bed_door']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('f2_bed_jewelbox_open', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('f2_bed_stitch_done', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('f2_bed_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  // ── 위젯 테스트 ──

  testWidgets('회상 위젯: 자수틀 재탭으로 열린 MemoryPlayer가 3페이지를 넘기고 닫힌다', (t) async {
    s.give('thread_blue1');
    s.give('silver_thread');
    s.give('thread_blue2');
    s.select('thread_blue1');
    tap('bed_c', 'embroidery');
    s.select('silver_thread');
    tap('bed_c', 'embroidery');
    s.select('thread_blue2');
    tap('bed_c', 'embroidery');
    expect(s.flag('f2_bed_stitch_done'), 1);

    tap('bed_c', 'embroidery'); // 앵커 재탭 → 회상
    expect(s.closeupId, 'memory');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
                builder: (context) => room.closeups['memory']!.custom!(context, c)))));
    await t.pump();
    expect(find.text(strF2Mem2p1), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem2p2), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem2p3), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer)); // 마지막 페이지 탭 → onDone → closeCloseup
    await t.pump();
    expect(s.closeupId, isNull);
  });
}
