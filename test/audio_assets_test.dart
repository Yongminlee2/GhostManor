import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';

/// 코드가 부르는 모든 사운드 슬롯이 실제 자산 파일로 해석되는지 —
/// 파일명 매핑이 깨지면(오타·삭제) 기기에서 무음 폴백으로 조용히 죽기 때문에
/// 여기서 잡는다.
void main() {
  const slots = [
    // sfx
    'book_flip', 'bottle_fill', 'ceramic_clink', 'clock_tick', 'cloth_rub',
    'combine', 'door_open', 'fire_ignite', 'ghost_giggle', 'glass_clink',
    'liquid_pour', 'locked', 'metal_click', 'metal_drop', 'metal_key',
    'note1', 'note2', 'note3', 'note4', 'organ_chord', 'organ_wrong',
    'paper_rustle', 'pickup', 'sparkle', 'stone_drag', 'switch_click',
    'tv_static', 'unlock', 'wood_creak_open', 'wood_knock_dull',
    'wood_knock_hollow', 'wood_slide',
    // 리마스터 신규 슬롯
    'uncork', 'pot_stir', 'paper_tear', 'pills_shake', 'floor_creak',
    // 루프
    'bgm_manor', 'ambient_foyer', 'ambient_living', 'ambient_study',
    'ambient_kitchen', 'ambient_cellar', 'ambient_attic',
  ];

  test('모든 슬롯이 존재하는 자산 파일로 해석된다', () {
    final missing = <String>[];
    for (final s in slots) {
      final f = File('assets/audio/${AudioService.fileFor(s)}');
      if (!f.existsSync()) missing.add('$s -> ${AudioService.fileFor(s)}');
    }
    expect(missing, isEmpty, reason: '누락 자산: $missing');
  });

  test('빈 파일 없음(0바이트 자산 방지)', () {
    for (final s in slots) {
      final f = File('assets/audio/${AudioService.fileFor(s)}');
      expect(f.lengthSync(), greaterThan(1000),
          reason: '${f.path}가 비정상적으로 작음');
    }
  });
}
