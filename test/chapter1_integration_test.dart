// 전체 게임 통합 테스트: 하나의 GameState/GameCtx로 11개 방(현관→거실→서재→
// 주방→지하실→다락→계단홀→안방→아이 방→서고→봉인의 방)을 순서대로 클리어한다.
// 방 사이 교차 아이템 흐름(거실→서재 기름, 방2~5→다락 악보 카드 4장, 방7~10→
// 방11 emblem 4종)이 실제로 이어지는지 검증하는 유일한 전체 테스트다(챕터2
// 계획 Task 7 브리프 — 파일명은 최초 작성 시점(챕터1 전용)의 잔재이나, "하나의
// 상태로 전 방을 잇는다"는 이 파일의 역할 자체는 챕터2까지 그대로 확장된
// 것이라 별도 분리 없이 여기에 이어 쓴다). 아무것도 수동으로 지급하지 않는다
// — solve* 함수들이 서로에게 넘겨주는 것만으로 끝까지 클리어되어야 게임
// 전체의 무결성이 증명된다.
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/rooms.dart';
import 'solutions.dart';

void main() {
  test(
      '전체: 11개 방 연속 클리어 (현관→거실→서재→주방→지하실→다락→계단홀→안방→아이 방→서고→봉인의 방)',
      () {
    final s = GameState();
    final c = GameCtx(s, AudioService(enabled: false));
    final rooms = buildAllRooms();
    expect(rooms.length, 11);

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
    s.goRoom(6);

    // 챕터1→2 이음: 다락 클리어가 더 이상 마지막 방이 아니다(rooms.length가
    // 6에서 11로 늘었으므로 main.dart의 제네릭 roomIndex+1 vs rooms.length
    // 비교가 자동으로 다음 방(계단홀)으로 이어준다 — 별도 하드코딩 없음).
    room = rooms[6];
    solveHall(s, c, room);
    expect(room.cleared(s), isTrue);
    expect(s.has('emblem_hall'), isTrue);
    s.goRoom(7);

    room = rooms[7];
    solveBed(s, c, room);
    expect(room.cleared(s), isTrue);
    expect(s.has('emblem_bed'), isTrue);
    s.goRoom(8);

    room = rooms[8];
    solveChild(s, c, room);
    expect(room.cleared(s), isTrue);
    expect(s.has('emblem_child'), isTrue);
    s.goRoom(9);

    room = rooms[9];
    solveLab(s, c, room);
    expect(room.cleared(s), isTrue);
    expect(s.has('emblem_lab'), isTrue);
    s.goRoom(10);

    // 봉인의 방 시작 전: 방7~10에서 각각 얻은 상징 4종이 전부 모여 있어야
    // 한다(제단 정답 순서 = hall→bed→child→lab).
    expect(s.has('emblem_hall'), isTrue);
    expect(s.has('emblem_bed'), isTrue);
    expect(s.has('emblem_child'), isTrue);
    expect(s.has('emblem_lab'), isTrue);

    room = rooms[10];
    solveSeal(s, c, room);
    expect(room.cleared(s), isTrue);
    expect(s.flag('f2_seal_done'), 1);
  });
}
