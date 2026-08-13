import '../core/models.dart';
import 'room1_foyer.dart';
import 'room2_living.dart';
import 'room3_study.dart';
import 'room4_kitchen.dart';
import 'room5_cellar.dart';
import 'room6_attic.dart';
import 'room7_hall.dart';
import 'room8_bed.dart';
import 'room9_child.dart';
import 'room10_lab.dart';
import 'room11_seal.dart';

/// 전체 방 목록(순차 해금). 방 추가 = 여기 한 줄 (스펙 §4.3). 챕터1(현관~
/// 다락, 인덱스 0~5) 뒤에 챕터2(계단홀~봉인의 방, 인덱스 6~10)를 그대로
/// 이어붙인다 — 별도 "챕터" 개념은 코드에 없고 하나의 순차 방 목록일
/// 뿐이라, 다락 클리어가 마지막 방(현재 seal, rooms.length-1)이 아닌 한
/// main.dart의 클리어 로직(_ended/_selfHealStrandedClear 모두 roomIndex+1
/// vs rooms.length 비교)이 자동으로 다음 방(hall)으로 이어준다.
List<Room> buildAllRooms() => [
      buildFoyer(),
      buildLiving(),
      buildStudy(),
      buildKitchen(),
      buildCellar(),
      buildAttic(),
      buildHall(),
      buildBed(),
      buildChild(),
      buildLab(),
      buildSeal(),
    ];
