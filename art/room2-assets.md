# 거실(room2_living) 에셋 의뢰 목록

공통 접두어는 style-guide.md 참조. 완성 파일은 그대로 아래 경로에 저장 (코드 수정 불필요).

## 씬 (1024×1536)
| 파일 | 내용 |
|---|---|
| assets/scenes/living_a.png | 거실 벽난로 벽. 벽난로 위 선반에 촛대 네 개가 나란히(촛대1 0.06,0.52,0.10,0.16 / 촛대2 0.28,0.52,0.10,0.16 / 촛대3 0.62,0.52,0.10,0.16 / 촛대4 0.84,0.52,0.10,0.16 — 전부 꺼진 상태), 중앙에 차갑게 식은 벽난로(0.30,0.48,0.40,0.34), 벽난로 위 벽돌 선반에 살짝 헐거워 보이는 벽돌 하나(비밀칸, 0.36,0.30,0.28,0.14 — 아직 닫힌 상태) |
| assets/scenes/living_b.png | 소파·TV·문 벽. 왼쪽 아래 소파 위에 쿠션(0.08,0.62,0.18,0.14), 왼쪽 위 낡은 TV—꺼진 화면(0.10,0.24,0.24,0.22), 오른쪽에 문을 막고 선 작은 유령 "부우"—겁주는 척하지만 시무룩한 표정(대략 0.62,0.30,0.20,0.30 부근에 배치, 부우 뒤로 닫힌 문 0.62,0.26,0.26,0.44) |

## 오버레이 — living_a 벽 (좌표에 맞춰 재단)
| 파일 | 내용 | 배치 좌표(LTWH, living_a 기준) |
|---|---|---|
| assets/scenes/living_a_candle1_on.png | 촛대1(맨 왼쪽)의 켜진 불꽃 | 0.06,0.52,0.10,0.16 |
| assets/scenes/living_a_candle2_on.png | 촛대2의 켜진 불꽃 | 0.28,0.52,0.10,0.16 |
| assets/scenes/living_a_candle3_on.png | 촛대3의 켜진 불꽃 | 0.62,0.52,0.10,0.16 |
| assets/scenes/living_a_candle4_on.png | 촛대4(맨 오른쪽)의 켜진 불꽃 | 0.84,0.52,0.10,0.16 |
| assets/scenes/living_a_fire.png | 벽난로 안에서 활활 타오르는 불 | 0.30,0.48,0.40,0.34 |
| assets/scenes/living_a_nook_open.png | 벽돌이 덜컹 열려 드러난 벽난로 위 비밀칸 | 0.36,0.30,0.28,0.14 |

## 오버레이 — living_b 벽 (좌표에 맞춰 재단)
| 파일 | 내용 | 배치 좌표(LTWH, living_b 기준) |
|---|---|---|
| assets/scenes/living_b_boo_door.png | 문 앞을 막고 선 유령 부우 — 이불을 뒤집어쓰고 무서운 척하지만 시무룩함 | 0.60,0.28,0.24,0.34 |
| assets/scenes/living_b_boo_sofa.png | 소파에 파묻혀 TV를 보는 행복한 표정의 부우 | 0.34,0.56,0.18,0.22 |
| assets/scenes/living_b_tv_on.png | 지지직거리는 빛이 도는 켜진 TV 화면 | 0.10,0.24,0.24,0.22 |
| assets/scenes/living_b_door_open.png | 활짝 열린 문, 안쪽은 다음 방으로 이어지는 어둠 | 0.62,0.26,0.26,0.44 |

## 클로즈업 (1024×1024)
| 파일 | 내용 |
|---|---|
| assets/scenes/living_tv.png | 지지직거리는 TV 화면 클로즈업. 화면 속에 촛대 네 개 그림이 나란히 그려져 있고, 그중 2번째와 4번째만 불이 켜져 있음(촛대 퍼즐의 정답 단서 — 관찰 전용, 핫스팟 없음) |

## 아이템 (512×512, 투명 배경)
| 파일 | 내용 |
|---|---|
| assets/items/remote.png | TV 리모컨 |
| assets/items/key_living.png | 거실 열쇠 |
| assets/items/note1.png | 음표 카드 — 카드 위에 달 그림과 ♪ 기호만. 글자 없음 |
| assets/items/oil.png | 기름병 |

## 효과음
이번 방은 신규 사운드 없음 — clock_tick, sparkle, ghost_giggle, door_open, unlock, locked 전부 room1-assets.md의 기존 목록에서 재사용.
