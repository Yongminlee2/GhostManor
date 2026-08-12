// 챕터 1 통합 테스트: 하나의 GameState/GameCtx로 6개 방(현관→거실→서재→주방→
// 지하실→다락)을 순서대로 클리어한다. 방 사이 교차 아이템 흐름(거실→서재 기름,
// 방2~5→다락 악보 카드 4장)이 실제로 이어지는지 검증하는 유일한 전체 테스트다
// (Task 7 브리프). 아무것도 수동으로 지급하지 않는다 — solve* 함수들이 서로에게
// 넘겨주는 것만으로 끝까지 클리어되어야 챕터 무결성이 증명된다.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/rooms.dart';
import 'solutions.dart';

void main() {
  test('챕터 1: 6개 방 연속 클리어 (현관→거실→서재→주방→지하실→다락)', () {
    final s = GameState();
    final c = GameCtx(s, AudioService(enabled: false));
    final rooms = buildAllRooms();
    expect(rooms.length, 6);

    Room room = rooms[0];
    solveFoyer(s, c, room);
    expect(room.cleared(s), isTrue);
    s.goRoom(1);

    room = rooms[1];
    solveLiving(s, c, room);
    expect(room.cleared(s), isTrue);
    s.goRoom(2);

    // 서재 시작 전: 거실 비밀 공간에서 얻은 기름(oil)을 그대로 들고 있어야 한다.
    expect(s.has('oil'), isTrue);

    room = rooms[2];
    solveStudy(s, c, room);
    expect(room.cleared(s), isTrue);
    s.goRoom(3);

    room = rooms[3];
    solveKitchen(s, c, room);
    expect(room.cleared(s), isTrue);
    s.goRoom(4);

    room = rooms[4];
    solveCellar(s, c, room);
    expect(room.cleared(s), isTrue);
    s.goRoom(5);

    // 다락 시작 전: 방 2~5에서 각각 얻은 악보 카드 4장이 전부 모여 있어야 한다.
    expect(s.has('note1'), isTrue);
    expect(s.has('note2'), isTrue);
    expect(s.has('note3'), isTrue);
    expect(s.has('note4'), isTrue);

    room = rooms[5];
    solveAttic(s, c, room);
    expect(room.cleared(s), isTrue);
    expect(s.flag('attic_r_done'), 1);
  });
}
