import 'package:audioplayers/audioplayers.dart';

/// 소리 없어도 게임은 돈다 — 모든 실패는 무음 폴백 (스펙 §7 정신).
class AudioService {
  final bool enabled; // 테스트에서 false: 플러그인 자체를 건드리지 않음
  bool muted = false;
  AudioPlayer? _bgm;
  AudioPlayer? _ambient;

  AudioService({this.enabled = true});

  /// 슬롯 → 실제 파일명. 실음원은 원본 포맷 그대로 싣고(ogg/flac),
  /// 여기 없는 슬롯은 합성 `<슬롯>.wav`. 출처는 docs/CREDITS.md.
  static const Map<String, String> _files = {
    'ceramic_clink': 'ceramic_clink.ogg',
    'clock_tick': 'clock_tick.ogg',
    'cloth_rub': 'cloth_rub.ogg',
    'combine': 'combine.ogg',
    'door_open': 'door_open.ogg',
    'glass_clink': 'glass_clink.ogg',
    'metal_click': 'metal_click.ogg',
    'metal_drop': 'metal_drop.ogg',
    'pickup': 'pickup.ogg',
    'switch_click': 'switch_click.ogg',
    'wood_creak_open': 'wood_creak_open.ogg',
    'wood_knock_dull': 'wood_knock_dull.ogg',
    'wood_knock_hollow': 'wood_knock_hollow.ogg',
    'ambient_foyer': 'ambient_foyer.flac',
    'ambient_living': 'ambient_living.flac',
    'ambient_study': 'ambient_study.flac',
    'ambient_kitchen': 'ambient_kitchen.flac',
    'ambient_cellar': 'ambient_foyer.flac', // 루프 재사용 — 파일 중복 없이
    'ambient_attic': 'ambient_study.flac',
    'bgm_manor': 'bgm_manor.ogg',
  };

  static String fileFor(String name) => _files[name] ?? '$name.wav';

  Future<void> play(String name) async {
    if (!enabled || muted) return;
    AudioPlayer? p;
    try {
      p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p?.dispose());
      await p.play(AssetSource('audio/${fileFor(name)}'));
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
      await _bgm!.setVolume(0.4); // 실음원 BGM은 효과음 밑에 깔리게
      await _bgm!.play(AssetSource('audio/${fileFor(name)}'));
      if (muted) await _bgm!.pause();
    } catch (_) {}
  }

  Future<void> playAmbient(String name) async {
    if (!enabled) return;
    try {
      _ambient ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _ambient!.setVolume(0.6);
      await _ambient!.play(AssetSource('audio/${fileFor(name)}'));
      if (muted) await _ambient!.pause();
    } catch (_) {}
  }

  Future<void> setMuted(bool m) async {
    muted = m;
    try {
      if (m) {
        await _bgm?.pause();
        await _ambient?.pause();
      } else {
        await _bgm?.resume();
        await _ambient?.resume();
      }
    } catch (_) {}
  }
}
