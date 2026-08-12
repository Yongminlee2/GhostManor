import '../core/models.dart';
import 'room1_foyer.dart';
import 'room2_living.dart';
import 'room3_study.dart';
import 'room4_kitchen.dart';

/// 챕터 1 방 목록 (순차 해금). 방 추가 = 여기 한 줄 (스펙 §4.3).
List<Room> buildAllRooms() =>
    [buildFoyer(), buildLiving(), buildStudy(), buildKitchen()];
