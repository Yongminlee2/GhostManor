import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('저장→로드 라운드트립', () async {
    final svc = SaveService();
    final s = GameState()..setFlag('got_key', 1)..give('match');
    await svc.save(s);
    final r = await svc.load();
    expect(r!.flag('got_key'), 1);
    expect(r.has('match'), isTrue);
  });

  test('세이브 없으면 null', () async {
    expect(await SaveService().load(), isNull);
  });

  test('본 세이브 파손 시 백업 슬롯으로 복구 (스펙 §4.5)', () async {
    final svc = SaveService();
    final s = GameState()..setFlag('a', 1);
    await svc.save(s); // save=v1
    s.setFlag('a', 2);
    await svc.save(s); // bak=v1, save=v2
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SaveService.key, '{깨진 json');
    final r = await svc.load();
    expect(r!.flag('a'), 1); // 백업(v1)으로 복구
  });

  test('clear는 본·백업 모두 삭제', () async {
    final svc = SaveService();
    await svc.save(GameState());
    await svc.save(GameState());
    await svc.clear();
    expect(await svc.load(), isNull);
  });

  test('attach: 상태 변화 후 자동 저장돼 있음 (디바운스 0.5초)', () async {
    final svc = SaveService();
    final s = GameState();
    svc.attach(s);
    s.setFlag('x', 7);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final r = await svc.load();
    expect(r!.flag('x'), 7);
  });
}
