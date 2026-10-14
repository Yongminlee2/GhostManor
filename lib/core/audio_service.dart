import 'package:audioplayers/audioplayers.dart';

/// 소리 없어도 게임은 돈다 — 모든 실패는 무음 폴백 (스펙 §7 정신).
class AudioService {
  final bool enabled; // 테스트에서 false: 플러그인 자체를 건드리지 않음
  bool muted = false;
  AudioPlayer? _bgm;
  AudioPlayer? _ambient;
  String? _bgmFile; // 재생 중인 곡 — 같은 곡 재요청이면 재시작하지 않는다
  String? _ambientFile;
  bool _contextSet = false;

  AudioService({this.enabled = true}) {
    if (!enabled) return;
    // 아이폰 기본 세션(playback)은 사용자가 듣던 음악을 끊고 무음 스위치를 무시한다 —
    // 게임 소리는 ambient(섞임 + 무음 스위치 따름). 안드로이드는 기본값 그대로.
    AudioPlayer.global
        .setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          ),
        )
        .catchError((_) {});
  }

  /// 기본 AudioContext는 재생마다 오디오 포커스를 독점해, 효과음이 날 때마다
  /// BGM·앰비언트가 끊긴다(실기기: 게임 중 배경음 무음). 포커스를 잡지 않게
  /// 한 번만 전역 설정 — 앱 내 플레이어끼리 자유롭게 섞인다.
  Future<void> _ensureContext() async {
    if (_contextSet) return;
    _contextSet = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
    } catch (_) {}
  }

  /// 슬롯 → 실제 파일명. 실음원은 flac 그대로, ogg 는 아이폰이 못 틀어(AVFoundation 에
  /// Vorbis 가 없다) AAC(m4a)로 바꿔 싣는다 — 안드로이드도 같은 파일을 튼다.
  /// 여기 없는 슬롯은 합성 `<슬롯>.wav`. 출처는 docs/CREDITS.md.
  static const Map<String, String> _files = {
    'ceramic_clink': 'ceramic_clink.m4a',
    'clock_tick': 'clock_tick.m4a',
    'cloth_rub': 'cloth_rub.m4a',
    'combine': 'combine.m4a',
    'door_open': 'door_open.m4a',
    'glass_clink': 'glass_clink.m4a',
    'metal_click': 'metal_click.m4a',
    'metal_drop': 'metal_drop.m4a',
    'pickup': 'pickup.m4a',
    'switch_click': 'switch_click.m4a',
    'wood_creak_open': 'wood_creak_open.m4a',
    'wood_knock_dull': 'wood_knock_dull.m4a',
    'wood_knock_hollow': 'wood_knock_hollow.m4a',
    'ambient_foyer': 'ambient_foyer.flac',
    'ambient_living': 'ambient_living.flac',
    'ambient_study': 'ambient_study.flac',
    'ambient_kitchen': 'ambient_kitchen.flac',
    'ambient_cellar': 'ambient_foyer.flac', // 루프 재사용 — 파일 중복 없이
    'ambient_attic': 'ambient_study.flac',
    // 챕터 2 (2층) — 동일한 재사용 원칙
    'ambient_hall': 'ambient_foyer.flac',
    'ambient_bed': 'ambient_living.flac',
    'ambient_child': 'ambient_kitchen.flac',
    'ambient_lab': 'ambient_study.flac',
    'ambient_seal': 'ambient_foyer.flac',
    'bgm_manor': 'bgm_manor.m4a',
  };

  static String fileFor(String name) => _files[name] ?? '$name.wav';

  Future<void> play(String name) async {
    if (!enabled || muted) return;
    AudioPlayer? p;
    try {
      await _ensureContext();
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
    final file = fileFor(name);
    if (_bgmFile == file) return; // 같은 곡이면 이어서 재생 유지
    _bgmFile = file;
    try {
      await _ensureContext();
      _bgm ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _bgm!.setVolume(0.4); // 실음원 BGM은 효과음 밑에 깔리게
      await _bgm!.play(AssetSource('audio/$file'));
      if (muted) await _bgm!.pause();
    } catch (_) {}
  }

  Future<void> playAmbient(String name) async {
    if (!enabled) return;
    final file = fileFor(name);
    // 방이 바뀌어도 같은 루프 파일이면 재시작하지 않는다(챕터 내 재사용 多).
    if (_ambientFile == file) return;
    _ambientFile = file;
    try {
      await _ensureContext();
      _ambient ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _ambient!.setVolume(0.6);
      await _ambient!.play(AssetSource('audio/$file'));
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
