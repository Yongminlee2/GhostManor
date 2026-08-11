import 'package:audioplayers/audioplayers.dart';

/// 소리 없어도 게임은 돈다 — 모든 실패는 무음 폴백 (스펙 §7 정신).
class AudioService {
  final bool enabled; // 테스트에서 false: 플러그인 자체를 건드리지 않음
  bool muted = false;
  AudioPlayer? _bgm;

  AudioService({this.enabled = true});

  Future<void> play(String name) async {
    if (!enabled || muted) return;
    AudioPlayer? p;
    try {
      p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p?.dispose());
      await p.play(AssetSource('audio/$name.mp3'));
    } catch (_) {
      try {
        await p?.dispose();
      } catch (_) {/* 소리 정리 실패도 무시 */}
    }
  }

  Future<void> playBgm(String name) async {
    if (!enabled) return;
    try {
      _bgm ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _bgm!.play(AssetSource('audio/$name.mp3'));
      if (muted) await _bgm!.pause();
    } catch (_) {}
  }

  Future<void> setMuted(bool m) async {
    muted = m;
    try {
      if (m) {
        await _bgm?.pause();
      } else {
        await _bgm?.resume();
      }
    } catch (_) {}
  }
}
