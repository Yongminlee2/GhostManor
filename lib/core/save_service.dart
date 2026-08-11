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
        return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
}
