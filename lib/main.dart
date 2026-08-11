import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/ads.dart' as ads;
import 'core/audio_service.dart';
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
  runApp(const GhostManorApp());
}

class GhostManorApp extends StatefulWidget {
  final GameState? initialState; // 테스트 주입: 지정 시 타이틀 건너뛰고 바로 방
  final Future<bool> Function()? adFn;
  final bool audioEnabled;
  const GhostManorApp(
      {super.key, this.initialState, this.adFn, this.audioEnabled = true});

  @override
  State<GhostManorApp> createState() => _GhostManorAppState();
}

class _GhostManorAppState extends State<GhostManorApp> {
  final save = SaveService();
  late final audio = AudioService(enabled: widget.audioEnabled);
  late final rooms = buildAllRooms();
  GameState? playing; // null이면 타이틀
  bool hasSave = false;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialState != null) {
      _start(widget.initialState!);
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
    return MaterialApp(
      title: strAppTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B3E96), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF1A1226),
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
                  state: playing!,
                  rooms: rooms,
                  audio: audio,
                  save: save,
                  adFn: widget.adFn ?? ads.showRewardedAd,
                  onExitToTitle: _toTitle,
                ),
    );
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
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text(strAppTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          if (hasSave)
            FilledButton(onPressed: onContinue, child: const Text(strContinue)),
          const SizedBox(height: 12),
          FilledButton.tonal(
              onPressed: () => onNewGame(context),
              child: const Text(strNewGame)),
        ]),
      ),
    );
  }
}

class RoomScreen extends StatefulWidget {
  final GameState state;
  final List<Room> rooms;
  final AudioService audio;
  final SaveService save;
  final Future<bool> Function() adFn;
  final Future<void> Function() onExitToTitle;
  const RoomScreen(
      {super.key,
      required this.state,
      required this.rooms,
      required this.audio,
      required this.save,
      required this.adFn,
      required this.onExitToTitle});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final GameCtx ctx = GameCtx(widget.state, widget.audio);
  late final HintService hints =
      HintService(widget.state, showRewardedAd: widget.adFn);

  Room get room => widget.rooms[widget.state.roomIndex % widget.rooms.length];

  @override
  void initState() {
    super.initState();
    widget.audio.playBgm('bgm_manor');
    widget.state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheRoomImages();
      _enterRoomIfFirst();
    });
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
      room.onEnter?.call(ctx);
    }
    _onStateChanged();
  }

  void _onStateChanged() {
    final s = widget.state;
    if (room.cleared(s) && s.flag('cleared_shown_${room.id}') == 0) {
      s.setFlag('cleared_shown_${room.id}', 1);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showClear());
    }
  }

  Future<void> _showClear() async {
    widget.audio.play('door_open');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(strRoomClear),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final s = widget.state;
              if (s.roomIndex + 1 < widget.rooms.length) {
                s.goRoom(s.roomIndex + 1);
                _precacheRoomImages();
                _enterRoomIfFirst();
              } else {
                setState(() => _ended = true);
              }
            },
            child: const Text(strNextRoom),
          ),
        ],
      ),
    );
  }

  bool _ended = false;

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
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text(strChapterEnd,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 22)),
            const SizedBox(height: 32),
            FilledButton(
                onPressed: widget.onExitToTitle,
                child: const Text(strBackToTitle)),
          ]),
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
            child: Center(
              child: AspectRatio(
                  aspectRatio: 2 / 3, child: SceneView(room: room, ctx: ctx)),
            ),
          ),
          InventoryBar(ctx: ctx),
        ]),
      ),
    );
  }
}
