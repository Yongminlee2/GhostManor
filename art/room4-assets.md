# 주방(room4_kitchen) 에셋 의뢰 목록

공통 접두어는 style-guide.md 참조. 완성 파일은 그대로 아래 경로에 저장 (코드 수정 불필요).

## 씬 (1024×1536)
| 파일 | 내용 |
|---|---|
| assets/scenes/kitchen_a.png | 화덕·조리대·국자 벽. 왼쪽 아래 조리대 위에 빈 유리병 하나(counter 0.06,0.60,0.20,0.14), 중앙에 푸른 유령불이 일렁이는 오래된 화덕(stove 0.34,0.50,0.26,0.26), 오른쪽에 커다란 국자를 든 요리사 유령 "국자"가 텅 빈 냄비를 젓고 있음(gukja 0.68,0.34,0.22,0.36 부근 — 별도 오버레이 없이 이 배경 그림 한 장에 함께 그린다), 위쪽에 말린 버섯이 담긴 항아리(jar 0.34,0.20,0.14,0.16) |
| assets/scenes/kitchen_b.png | 찬장·싱크대·뒷문 벽. 왼쪽 아래 이끼 낀 초록빛 물이 고인 싱크대(sink 0.06,0.52,0.20,0.18), 위쪽에 나란히 닫힌 찬장 문 네 개(왼쪽부터 cupboard1 0.34,0.28,0.10,0.14 / cupboard2 0.46,0.28,0.10,0.14 / cupboard3 0.58,0.28,0.10,0.14 / cupboard4 0.70,0.28,0.10,0.14 — **네 문은 서로 겉모습이 완전히 동일해야 함, 어느 것도 시각적으로 특별해 보이면 안 됨**: 정답 문은 오직 두드리는 소리로만 구분되는 게 이 퍼즐의 핵심), 오른쪽에 녹슨 자물쇠가 걸린 잠긴 뒷문(backdoor 0.62,0.52,0.26,0.40) |

## 오버레이 — kitchen_b 벽 (좌표에 맞춰 재단)
| 파일 | 내용 | 배치 좌표(LTWH, kitchen_b 기준) |
|---|---|---|
| assets/scenes/kitchen_b_cup2_open.png | 왼쪽에서 2번째 찬장 문이 활짝 열리며 드러난 속 — 안에 노래하는 주전자가 보임 | 0.46,0.28,0.10,0.14 |
| assets/scenes/kitchen_b_door_open.png | 활짝 열린 뒷문, 안쪽은 지하로 내려가는 돌계단 | 0.62,0.52,0.26,0.40 |

kitchen_a 벽은 오버레이 없음(조리대의 병·항아리의 버섯은 챙긴 뒤에도 그림이 바뀌지 않는 정적 소품 — 대사만 달라짐, 기존 방들의 "서재 책상" 소품과 동일한 방식).

## 아이템 (512×512, 투명 배경)
| 파일 | 내용 |
|---|---|
| assets/items/empty_bottle.png | 빈 유리병 |
| assets/items/water_bottle.png | 이끼 낀 초록빛 물이 가득 든 병 |
| assets/items/mushroom.png | 말린 버섯 한 줌 — 오래되고 쪼그라든 질감 |
| assets/items/kettle_singing.png | 낡은 주전자 — 주둥이에서 작은 음표가 피어오름(노래하는 느낌을 그림으로 표현) |
| assets/items/soup_base.png | 버섯과 이끼물을 섞은 걸쭉한 수프 베이스 — 탁한 녹색, 아직 빛나거나 김이 나지 않는 평범한 상태(완성된 ghost_soup와 뚜렷이 구분) |
| assets/items/ghost_soup.png | 초록빛 김이 몽글몽글 피어오르는 그릇에 담긴 유령 수프 |
| assets/items/key_kitchen.png | 뒷문 열쇠 — 다른 방 열쇠(key_foyer, key_living, key_study)와 구별되는 투박한 디자인 |
| assets/items/note3.png | 음표 카드 — 카드 위에 해 그림과 ♪ 기호만. 글자 없음 |

## 효과음
이번 방은 신규 사운드 없음 — sparkle, unlock, locked, door_open, ghost_giggle 전부 room1-assets.md의 기존 목록에서 재사용(clock_tick은 이번 방에서 미사용).
