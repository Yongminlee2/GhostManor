import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../rooms/rooms.dart';
import 'debug_shot.dart';
import 'game_state.dart';

/// 디버그 재생(SHOT=play): tool/art_check/play_record_test.dart 가 남긴 단계별 상태(play.json,
/// 앱 데이터 폴더 Documents/)를 하나씩 띄우고 화면을 Documents/play/NNN.png 로 찍는다.
/// 탭이 시뮬레이터 앱에 안 닿아서, 진행 중 화면을 이렇게 본다. 정식 빌드에선 안 불린다.
Future<void> runDebugPlay({
  required GlobalKey captureKey,
  required void Function(GameState s) show,
}) async {
  const ch = MethodChannel('ghostmanor/debug');
  final home = await ch.invokeMethod<String>('home');
  final steps = (jsonDecode(File('$home/Documents/play.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final out = Directory('$home/Documents/play')..createSync(recursive: true);
  final rooms = buildAllRooms();
  debugPlaying = true;
  var lastRoom = -1;
  for (final st in steps) {
    final s = GameState()
      ..flags = Map<String, int>.from(st['flags'] as Map)
      ..inventory = List<String>.from(st['inventory'] as List)
      ..selectedItem = st['selected'] as String?
      ..roomIndex = st['roomIndex'] as int
      ..sceneIndex = st['sceneIndex'] as int
      ..closeupId = st['closeup'] as String?
      ..dialog = st['dialog'] as String?;
    for (final r in rooms) {
      s.flags['entered_${r.id}'] = 1;
    }
    final m = st['mark'] as List?;
    debugMark = m == null
        ? null
        : Rect.fromLTWH((m[0] as num).toDouble(), (m[1] as num).toDouble(),
            (m[2] as num).toDouble(), (m[3] as num).toDouble());
    show(s);
    await Future<void>.delayed(Duration(milliseconds: s.roomIndex != lastRoom ? 2200 : 1100));
    lastRoom = s.roomIndex;
    final b = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ImageByteFormat.png);
    final n = (st['n'] as int).toString().padLeft(3, '0');
    File('${out.path}/$n.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  File('${out.path}/done').writeAsStringSync('${steps.length}');
}
