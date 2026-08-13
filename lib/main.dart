import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio_service.dart';
import 'core/game_state.dart';
import 'core/hint_service.dart';
import 'core/hint_sheet.dart';
import 'core/inventory_bar.dart';
import 'core/manor_theme.dart';
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
  final bool audioEnabled;
  const GhostManorApp({super.key, this.initialState, this.audioEnabled = true});

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
      _loadUsableSave().then((s) {
        setState(() {
          hasSave = s != null;
          loaded = true;
        });
      });
    }
  }

  /// 로드할 수 없는 구버전 세이브가 남아 있으면 제목 화면에서 "이어하기"가
  /// 보이지 않게 하고, 새 게임 버튼도 확인창 없이 정상 시작하도록 함께 지운다.
  Future<GameState?> _loadUsableSave() async {
    final s = await save.load();
    if (s == null) await save.clear();
    return s;
  }

  void _start(GameState s) {
    save.attach(s);
    audio.muted = s.flag('muted') == 1;
    setState(() => playing = s);
  }

  Future<void> _toTitle() async {
    final s = await _loadUsableSave();
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
      theme: buildManorTheme(),
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
          child: const Text(strCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(strOk),
        ),
      ],
    ),
  );
  return r ?? false;
}

class TitleScreen extends StatelessWidget {
  final bool hasSave;
  final VoidCallback onContinue;
  final void Function(BuildContext) onNewGame;
  const TitleScreen({
    super.key,
    required this.hasSave,
    required this.onContinue,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/ui/title_manor.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x4D100817),
                  Color(0x1A100817),
                  Color(0xB30D0712),
                ],
                stops: [0, 0.52, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                child: Column(
                  children: [
                    const _TitleLockup(),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: ManorPanel(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        color: const Color(0xE6241731),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ManorRule(),
                            const SizedBox(height: 15),
                            if (hasSave) ...[
                              _TitleButton(
                                key: const Key('title_continue'),
                                label: strContinue,
                                icon: Icons.auto_stories_outlined,
                                onPressed: onContinue,
                                primary: true,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _TitleButton(
                              key: const Key('title_new_game'),
                              label: strNewGame,
                              icon: Icons.vpn_key_outlined,
                              onPressed: () => onNewGame(context),
                              primary: !hasSave,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: box.maxHeight * 0.025),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleLockup extends StatelessWidget {
  const _TitleLockup();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: manorPanel,
          border: Border.all(color: manorGold, width: 1.4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: const Icon(
          Icons.nightlight_round,
          color: manorGoldBright,
          size: 27,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        strAppTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: manorCream,
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 3)),
            Shadow(color: Color(0xFF6D45A4), blurRadius: 22),
          ],
        ),
      ),
      const SizedBox(height: 9),
      const Text(
        'GHOST MANOR',
        style: TextStyle(
          color: manorGoldBright,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 5,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
    ],
  );
}

class _TitleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  const _TitleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      label: Text(label),
      style: FilledButton.styleFrom(
        foregroundColor: primary ? manorInk : manorCream,
        backgroundColor: primary ? manorGoldBright : const Color(0xFF463253),
        side: BorderSide(
          color: primary ? manorGoldBright : manorGold,
          width: 1.2,
        ),
        elevation: primary ? 5 : 0,
      ),
    ),
  );
}

class RoomScreen extends StatefulWidget {
  final GameState state;
  final List<Room> rooms;
  final AudioService audio;
  final SaveService save;
  final Future<void> Function() onExitToTitle;
  const RoomScreen({
    super.key,
    required this.state,
    required this.rooms,
    required this.audio,
    required this.save,
    required this.onExitToTitle,
  });

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
        ...sc.alternateImages,
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
      s.setFlag(
        'entered_at_${room.id}',
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
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
        icon: const Icon(Icons.key, color: manorGoldBright, size: 30),
        title: const Text(strRoomClear),
        content: const Text(
          '묵직한 자물쇠가 풀렸습니다. 저택의 다음 공간으로 이동합니다.',
          textAlign: TextAlign.center,
        ),
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
        icon: const Icon(
          Icons.settings_outlined,
          color: manorGoldBright,
          size: 30,
        ),
        title: const Text(strSettings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(
              builder: (context, setDlg) => ManorPanel(
                padding: EdgeInsets.zero,
                color: Colors.transparent,
                child: Material(
                  color: manorPanelSoft,
                  borderRadius: BorderRadius.circular(17),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    secondary: Icon(
                      widget.audio.muted
                          ? Icons.volume_off_outlined
                          : Icons.volume_up_outlined,
                      color: manorGoldBright,
                    ),
                    title: const Text(strMute),
                    value: widget.audio.muted,
                    onChanged: (v) {
                      widget.audio.setMuted(v);
                      s.setFlag('muted', v ? 1 : 0);
                      setDlg(() {});
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final ok = await _confirm(context, strResetConfirm);
                if (!ok) return;
                await widget.save.clear();
                if (context.mounted) Navigator.pop(context);
                await widget.onExitToTitle();
              },
              child: const Text(
                strResetProgress,
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ended) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/ui/title_manor.png', fit: BoxFit.cover),
            const ColoredBox(color: Color(0xB312091A)),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ManorPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.nightlight_round,
                          color: manorGoldBright,
                          size: 42,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          strChapterEnd,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        const ManorRule(),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: widget.onExitToTitle,
                          icon: const Icon(Icons.home_outlined),
                          label: const Text(strBackToTitle),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFF21142E),
                border: Border(bottom: BorderSide(color: manorGold, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: manorGold),
                      color: manorPanelSoft,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.state.roomIndex + 1}',
                        style: const TextStyle(
                          color: manorGoldBright,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      room.name,
                      style: const TextStyle(
                        color: manorCream,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _TopBarButton(
                    key: const Key('btn_hint'),
                    icon: Icons.lightbulb_outline,
                    label: strHintTitle,
                    onPressed: () => showHintSheet(context, room, hints),
                  ),
                  _TopBarButton(
                    key: const Key('btn_settings'),
                    icon: Icons.settings_outlined,
                    label: strSettings,
                    onPressed: _openSettings,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: SceneView(room: room, ctx: ctx),
                ),
              ),
            ),
            InventoryBar(ctx: ctx),
          ],
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _TopBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: manorGoldBright),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF382548),
          side: const BorderSide(color: Color(0xFF6D527E)),
        ),
      ),
    ),
  );
}
