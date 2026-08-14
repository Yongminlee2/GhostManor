# 리터치 의뢰 5차 (상태-시각 전수 감사 결과)

공통 규칙은 `art/style-guide.md` 그대로. **전부 해당 원본을 이미지 입력으로 넣은
edit** — 지정된 부분 외에는 픽셀이 동일해야 한다. 완성본은 지정 파일명으로 저장.

## 필수 — 문 열림 그림 4장 (챕터2에 통째로 누락)

각 벽면 원본을 입력으로, **문만 안쪽으로 활짝 열린 상태**로 edit(문 너머는
어두운 복도+은은한 빛 — 챕터1 `foyer_a_door_open.png` 양식 참조).

| 신규 파일 | 원본 | 문 위치 |
|---|---|---|
| f2_hall_a_door_open.png | f2_hall_a.png | 좌측 안방 문(해골 장식+자물쇠 달린 문 — 자물쇠도 풀린 모습으로) |
| f2_bed_a_door_open.png | f2_bed_a.png | 우측 아치형 문 |
| f2_child_a_door_open.png | f2_child_a.png | 우측 손잡이 달린 문 |
| cellar_b_plate_door_open.png | cellar_b_plate.png | 중앙 쪽문(패널 문) |

## 필수 — 현관 벽시계 시침

`foyer_b.png` 상단 원형 시계는 현재 바늘이 없는 장식판이다. 시계 문자판
영역만 잘라낸 **시침 오버레이 12장**은 과하니, 대신:
- **foyer_b_clock3.png** (신규 1장): foyer_b.png 입력, 벽시계에 3시를 가리키는
  시침 하나가 생긴 상태로 edit(전체 벽면 저장). 코드는 서랍 해금 시점(3시
  도달)에만 이 벽면으로 전환한다 — 12장 대신 정답 상태 1장.

## 권장 — 소품 반응 2장

| 파일 | 내용 |
|---|---|
| study_c_lens.png | study_c.png 입력 — 망원경 접안부에 렌즈 유리 반사 하이라이트가 생긴 상태(전체 벽면) |
| f2_hall_clock_alive.png | f2_hall_clock.png(클로즈업) 입력 — 태엽이 감겨 문자판이 은은히 빛나고 진자가 움직이는 느낌의 살아난 버전 |

저장 위치: 전부 `C:\workAndroid\GhostManor\assets\scenes\`.
