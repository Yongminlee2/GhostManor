import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';

/// 자동 저장 + 백업 슬롯 (스펙 §4.5, §7).
class SaveService {
  static const key = 'save';
  static const bakKey = 'save_bak';
  Timer? _debounce;

  Future<void> save(GameState s) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(key);
    if (old != null) await prefs.setString(bakKey, old); // 직전본 백업
    await prefs.setString(key, jsonEncode(s.toJson()));
  }

  Future<GameState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [key, bakKey]) {
      final raw = prefs.getString(k);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        // 리마스터 전/초기 리마스터 세이브는 방 상태 플래그의 의미와 오브젝트
        // 배치가 달라 이어하기 시 퍼즐을 건너뛰거나 열린 문에서 시작할 수 있다.
        // 버전 없는 구 세이브는 새 게임으로 돌리고 백업 슬롯도 재사용하지 않는다.
        final version = json['saveVersion'] as int? ?? 0;
        if (version != GameState.currentSaveVersion) return null;
        return GameState.fromJson(json);
      } catch (_) {
        // 파손 → 다음 슬롯 시도
      }
    }
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(bakKey);
  }

  /// 상태 변화를 0.5초 디바운스로 자동 저장 (스펙 §4.4).
  void attach(GameState s) {
    s.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () => save(s));
    });
  }

  /// 대기 중인 디바운스 저장 취소 (위젯 teardown용).
  void dispose() => _debounce?.cancel();
}
