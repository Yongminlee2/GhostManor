import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio_service.dart';
import 'core/debug_play.dart';
import 'core/debug_shot.dart';
import 'core/game_state.dart';
import 'core/hint_service.dart';
import 'core/hint_sheet.dart';
import 'core/inventory_bar.dart';
import 'core/models.dart';
import 'core/save_service.dart';
import 'core/scene_view.dart';
import 'core/strings.dart';
import 'rooms/rooms.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await loadDebugShot();
  runApp(const GhostManorApp());
}

class GhostManorApp extends StatefulWidget {
  final GameState? initialState; // 테스트 주입: 지정 시 타이틀 건너뛰고 바로 방
  final bool audioEnabled;
  const GhostManorApp(
      {super.key, this.initialState, this.audioEnabled = true});

  @override
  State<GhostManorApp> createState() => _GhostManorAppState();
}

class _GhostManorAppState extends State<GhostManorApp> {
  final save = SaveService();
  late final audio = AudioService(enabled: widget.audioEnabled);
  late final rooms = buildAllRooms();
  GameState? playing; // null이면 타이틀
  final _captureKey = GlobalKey(); // 디버그 재생이 화면을 찍는 경계
  int _playSeq = 0;
  bool hasSave = false;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    if (debugShot == 'play') {
      loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => runDebugPlay(
          captureKey: _captureKey,
          show: (s) => setState(() {
                _playSeq++;
                playing = s;
              })));
    }
    final shot = widget.initialState ?? debugShotState();
    if (shot != null) {
      _start(shot);
      loaded = true;
    } else {
      save.load().then((s) {
        setState(() {
          hasSave = s != null;
          loaded = true;
        });
      });
    }
  }

  void _start(GameState s) {
    save.attach(s);
    audio.muted = s.flag('muted') == 1;
    setState(() => playing = s);
  }

  Future<void> _toTitle() async {
    final s = await save.load();
    setState(() {
      playing = null;
      hasSave = s != null;
    });
  }

  @override
  void dispose() {
    save.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _captureKey, child: MaterialApp(
      title: strAppTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B3E96), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF1A1226),
        // 방 클리어·설정·확인 창을 게임 색으로(기본 회색 창이 동떨어져 보였다)
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xF2241B36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFB89A5E), width: 1.2),
          ),
          titleTextStyle: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF3E9FF)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFE2C98F)),
        ),
      ),
      home: !loaded
          ? const Scaffold(body: SizedBox())
          : playing == null
              ? TitleScreen(
                  hasSave: hasSave,
                  onContinue: () async {
                    final s = await save.load();
                    if (s != null) _start(s);
                  },
                  onNewGame: (context) async {
                    if (hasSave) {
                      final ok = await _confirm(context, strNewGameConfirm);
                      if (!ok) return;
                      await save.clear();
                    }
                    _start(GameState());
                  },
                )
              : RoomScreen(
                  key: ValueKey(_playSeq),
                  state: playing!,
                  rooms: rooms,
                  audio: audio,
                  save: save,
                  onExitToTitle: _toTitle,
                ),
    ));
  }
}

Future<bool> _confirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(strCancel)),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(strOk)),
      ],
    ),
  );
  return r ?? false;
}

/// 타이틀·엔딩 공용 배경: 게임 장면 한 장을 화면에 꽉 채우고 아래로 갈수록 어둡게.
class _ArtBackdrop extends StatelessWidget {
  final String image;
  final Widget child;
  const _ArtBackdrop({required this.image, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Image.asset(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99100A18), Color(0x33100A18), Color(0xCC100A18), Color(0xF2100A18)],
            stops: [0.0, 0.35, 0.68, 1.0],
          ),
        ),
      ),
      child,
    ]);
  }
}

const _titleStyle = TextStyle(
  fontSize: 38,
  fontWeight: FontWeight.w800,
  letterSpacing: 2,
  color: Color(0xFFF3E9FF),
  shadows: [
    Shadow(color: Color(0xFF9B7BE0), blurRadius: 18),
    Shadow(color: Color(0xFF000000), blurRadius: 6, offset: Offset(0, 2)),
  ],
);

Widget _menuButton(String label, VoidCallback onPressed, {bool primary = true}) => SizedBox(
      width: 220,
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: primary ? const Color(0xFF5B3E96) : const Color(0xCC241B36),
          foregroundColor: const Color(0xFFF3E9FF),
          side: const BorderSide(color: Color(0xFFB89A5E), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );

class TitleScreen extends StatelessWidget {
  final bool hasSave;
  final VoidCallback onContinue;
  final void Function(BuildContext) onNewGame;
  const TitleScreen(
      {super.key,
      required this.hasSave,
      required this.onContinue,
      required this.onNewGame});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ArtBackdrop(
        image: 'assets/scenes/foyer_a.png',
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            const Text(strAppTitle, textAlign: TextAlign.center, style: _titleStyle),
            const SizedBox(height: 10),
            const Text(strTitleTagline,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFFCDBDE8), letterSpacing: 0.5)),
            const Spacer(flex: 5),
            if (hasSave) ...[
              _menuButton(strContinue, onContinue),
              const SizedBox(height: 14),
            ],
            _menuButton(strNewGame, () => onNewGame(context), primary: !hasSave),
            const Spacer(flex: 1),
          ]),
        ),
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  final GameState state;
  final List<Room> rooms;
  final AudioService audio;
  final SaveService save;
  final Future<void> Function() onExitToTitle;
  const RoomScreen(
      {super.key,
      required this.state,
      required this.rooms,
      required this.audio,
      required this.save,
      required this.onExitToTitle});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final GameCtx ctx = GameCtx(widget.state, widget.audio);
  late final HintService hints = HintService(widget.state);

  Room get room => widget.rooms[widget.state.roomIndex % widget.rooms.length];

  @override
  void initState() {
    super.initState();
    widget.audio.playBgm('bgm_manor');
    widget.audio.playAmbient('ambient_${room.id}');
    widget.state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selfHealStrandedClear();
      _precacheRoomImages();
      _enterRoomIfFirst();
    });
  }

  /// 구 코드 경로가 만든 스트랜드 세이브(다이얼로그 안 본 채 cleared_shown만
  /// 켜짐) 또는 다이얼로그 중 프로세스 사망을 복구 — 다이얼로그 재표시 없이
  /// 바로 다음 방으로 넘긴다 (최종 리뷰 Finding 2b). goRoom 뒤엔 새 방이
  /// cleared가 아니라서 재호출돼도 더 진행하지 않는다 — 루프 없음.
  void _selfHealStrandedClear() {
    if (debugPlaying) return;
    final s = widget.state;
    if (room.cleared(s) &&
        s.flag('cleared_shown_${room.id}') >= 1 &&
        s.roomIndex + 1 < widget.rooms.length) {
      s.goRoom(s.roomIndex + 1);
      widget.audio.playAmbient('ambient_${room.id}');
      setState(() {}); // room getter가 roomIndex 의존 — 아래 precache/enter가 새 방을 보게
    }
  }

  /// 방 진입 시 이미지 프리로드 (스펙 §4.6). 에셋 미도착이면 조용히 무시.
  void _precacheRoomImages() {
    for (final sc in [...room.walls, ...room.closeups.values]) {
      for (final path in [
        if (sc.image != null) sc.image!,
        for (final o in sc.overlays) o.image,
      ]) {
        precacheImage(AssetImage(path), context, onError: (_, _) {});
      }
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _enterRoomIfFirst() {
    final s = widget.state;
    if (s.flag('entered_${room.id}') == 0) {
      s.setFlag('entered_${room.id}', 1);
      s.setFlag('entered_at_${room.id}',
          DateTime.now().millisecondsSinceEpoch ~/ 1000);
      room.onEnter?.call(ctx);
    }
    _onStateChanged();
  }

  void _onStateChanged() {
    if (debugPlaying) return;
    final s = widget.state;
    if (room.cleared(s) && s.flag('cleared_shown_${room.id}') == 0) {
      s.setFlag('cleared_shown_${room.id}', 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showClear());
    }
  }

  /// 다이얼로그가 버튼이든 시스템 백버튼이든 어떻게 닫히든 await가 반환되면
  /// 전진한다 — 백버튼 소프트락 수정 (최종 리뷰 Finding 2a). 전진 로직을 버튼
  /// onPressed 안에서만 태우던 예전 방식은 barrierDismissible:false가 막지
  /// 못하는 백버튼 dismiss에서 방을 영영 못 넘어가는 함정이었다.
  Future<void> _showClear() async {
    widget.audio.play('door_open');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(strRoomClear),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(strNextRoom),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final s = widget.state;
    if (s.roomIndex + 1 < widget.rooms.length) {
      s.goRoom(s.roomIndex + 1);
      widget.audio.playAmbient('ambient_${room.id}');
      _precacheRoomImages();
      _enterRoomIfFirst();
    }
    setState(() {}); // 방 전환/엔딩 모두 재빌드 필요 (room getter가 roomIndex에 의존)
  }

  bool get _ended {
    final s = widget.state;
    return s.roomIndex + 1 >= widget.rooms.length &&
        room.cleared(s) &&
        s.flag('cleared_shown_${room.id}') >= 1;
  }

  Future<void> _openSettings() async {
    final s = widget.state;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(strSettings),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          StatefulBuilder(
            builder: (context, setDlg) => SwitchListTile(
              title: const Text(strMute),
              value: widget.audio.muted,
              onChanged: (v) {
                widget.audio.setMuted(v);
                s.setFlag('muted', v ? 1 : 0);
                setDlg(() {});
              },
            ),
          ),
          TextButton(
            onPressed: () async {
              final ok = await _confirm(context, strResetConfirm);
              if (!ok) return;
              await widget.save.clear();
              if (context.mounted) Navigator.pop(context);
              await widget.onExitToTitle();
            },
            child: const Text(strResetProgress,
                style: TextStyle(color: Colors.redAccent)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ended) {
      return Scaffold(
        body: _ArtBackdrop(
          image: 'assets/scenes/attic_c.png',
          child: SafeArea(
            child: Column(children: [
              const Spacer(flex: 4),
              const Text(strChapterEnd,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 21,
                      height: 1.6,
                      color: Color(0xFFF3E9FF),
                      shadows: [Shadow(color: Color(0xFF000000), blurRadius: 8)])),
              const SizedBox(height: 36),
              _menuButton(strBackToTitle, widget.onExitToTitle),
              const Spacer(flex: 1),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Row(children: [
            const SizedBox(width: 16),
            Expanded(
                child: Text(room.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton(
                key: const Key('btn_hint'),
                icon: const Icon(Icons.lightbulb_outline),
                onPressed: () => showHintSheet(context, room, hints)),
            IconButton(
                key: const Key('btn_settings'),
                icon: const Icon(Icons.settings),
                onPressed: _openSettings),
          ]),
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              // 키 큰 아이폰에선 2:3 장면 위아래가 빈다 — 지금 벽면을 흐리게 깔아 잇는다.
              AnimatedBuilder(
                animation: widget.state,
                builder: (context, _) {
                  final img = room.walls[widget.state.sceneIndex % room.walls.length].image;
                  if (img == null) return const SizedBox();
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Opacity(
                        opacity: 0.45, child: Image.asset(img, fit: BoxFit.cover)),
                  );
                },
              ),
              Center(
                child: AspectRatio(
                    aspectRatio: 2 / 3, child: SceneView(room: room, ctx: ctx)),
              ),
            ]),
          ),
          InventoryBar(ctx: ctx),
        ]),
      ),
    );
  }
}
