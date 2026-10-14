import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../rooms/rooms.dart';
import 'game_state.dart';

/// 시뮬레이터 화면 확인용(디버그 빌드 전용). 이 맥의 시뮬레이터는 탭이 앱에
/// 닿지 않아서, 실행 인자 `-SHOT <값>`(AppDelegate 의 디버그 채널이 UserDefaults 에서
/// 읽어 준다, tool/art_check/shots.py) 또는 `--dart-define=SHOT=...` 로 열 화면을 정한다.
/// 정식 빌드에선 kDebugMode 가 상수 false 라 통째로 빠진다.
///
///   SHOT=title                       타이틀
///   SHOT=end                         엔딩
///   SHOT=living/1                    거실 두 번째 벽면
///   SHOT=attic/2/chest               다락방 세 번째 벽면에서 클로즈업 chest
///   SHOT=living/0/-/living_r_candle2=1,living_r_fireplace_lit=1/oil,note1
///        (방/벽면/클로즈업 또는 -/플래그/인벤토리)
String debugShot = '';

/// main() 에서 runApp 전에 한 번 부른다. 정식 빌드에선 아무것도 안 한다.
Future<void> loadDebugShot() async {
  if (!kDebugMode) return;
  debugShot = const String.fromEnvironment('SHOT');
  if (debugShot.isNotEmpty) return;
  // 채널은 엔진이 뜬 뒤 AppDelegate 가 등록한다 — main() 이 더 빠르면 잠깐 기다렸다 다시 묻는다.
  for (var i = 0; i < 40; i++) {
    try {
      debugShot = await const MethodChannel('ghostmanor/debug').invokeMethod<String>('shot') ?? '';
      break;
    } on MissingPluginException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint('debug_shot: $e');
      break;
    }
  }
}

GameState? debugShotState() {
  if (debugShot.isEmpty || debugShot == 'title') return null;
  final rooms = buildAllRooms();
  final s = GameState();
  // 모든 방 첫 진입 대사를 건너뛴다 — 스크린샷에 대사 창이 끼지 않게.
  for (final r in rooms) {
    s.flags['entered_${r.id}'] = 1;
  }
  if (debugShot == 'end') {
    s.roomIndex = rooms.length - 1;
    for (final r in rooms) {
      s.flags['cleared_shown_${r.id}'] = 1;
    }
    s.flags['attic_r_done'] = 1;
    return s;
  }
  final parts = debugShot.split('/');
  s.roomIndex = rooms.indexWhere((r) => r.id == parts[0]).clamp(0, rooms.length - 1);
  if (parts.length > 1) s.sceneIndex = int.tryParse(parts[1]) ?? 0;
  if (parts.length > 2 && parts[2] != '-' && parts[2].isNotEmpty) s.closeupId = parts[2];
  if (parts.length > 3 && parts[3].isNotEmpty) {
    for (final kv in parts[3].split(',')) {
      final i = kv.indexOf('=');
      if (i > 0) s.flags[kv.substring(0, i)] = int.tryParse(kv.substring(i + 1)) ?? 1;
    }
  }
  if (parts.length > 4 && parts[4].isNotEmpty) s.inventory = parts[4].split(',');
  return s;
}
