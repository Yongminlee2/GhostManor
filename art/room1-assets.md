# 현관(room1_foyer) 에셋 의뢰 목록

공통 접두어는 style-guide.md 참조. 완성 파일은 그대로 아래 경로에 저장 (코드 수정 불필요).

## 씬 (1024×1536)
| 파일 | 내용 |
|---|---|
| assets/scenes/foyer_a.png | 저택 현관 안쪽 벽. 중앙에 잠긴 커다란 목재 문(0.36,0.28,0.28,0.44), 오른쪽 위 먼지 낀 액자(0.66,0.12,0.24,0.20), 오른쪽 아래 서랍 달린 콘솔 테이블(0.64,0.52,0.28,0.16), 왼쪽 아래 우산꽂이(0.02,0.66,0.14,0.22), 왼쪽 중간은 비워둠(유령 자리) |
| assets/scenes/foyer_b.png | 현관 입구 벽. 왼쪽 코트 걸이에 낡은 외투(0.08,0.28,0.22,0.36), 위 중앙 벽시계—시곗바늘 없이 문자판만(0.40,0.08,0.20,0.16), 중앙 현관문(0.36,0.30,0.28,0.42), 오른쪽 아래 신발장(0.66,0.56,0.30,0.26) |

## 오버레이 (씬 부분, 좌표에 맞춰 재단)
| 파일 | 내용 | 배치 좌표(LTWH, foyer_a 기준) |
|---|---|---|
| assets/scenes/foyer_a_door_open.png | 활짝 열린 안쪽 문, 안쪽은 어두운 복도 | 0.36,0.28,0.28,0.44 |
| assets/scenes/ghost_butler.png | 코믹한 집사 유령 "고스포" — 나비넥타이, 허세 부리는 표정, 반투명. **배경 없이 유령 전신만, 배경 투명 PNG** (씬 크롭 금지 — 2026-08-12 1차본은 배경이 구워져 재생성 필요) | 0.02,0.34,0.20,0.30 |

## 클로즈업 (1024×1024)
| 파일 | 내용 |
|---|---|
| assets/scenes/foyer_shoes.png | 열린 신발장 내부, 낡은 구두들 |
| assets/scenes/foyer_shoes_candle.png | (오버레이) 구두 속에 꽂힌 양초, 좌표 0.52,0.34,0.28,0.32 |
| assets/scenes/foyer_drawer_dark.png | 열린 서랍 내부, 거의 새까만 어둠 |
| assets/scenes/foyer_drawer_lit.png | 같은 구도, 촛불에 비친 서랍 속 — 중앙(0.38,0.42,0.24,0.16)에 낡은 열쇠 |
| assets/scenes/foyer_frame_clean.png | 액자 그림: 벽난로 위 시계가 3시를 가리키는 옛 저택 그림 (바늘이 또렷하게 3시) |
| assets/scenes/foyer_frame_dust.png | 같은 크기의 뿌연 먼지 층 (아래가 안 비치는 회색 먼지) |
| assets/scenes/foyer_clock.png | 벽시계 문자판 클로즈업, 시곗바늘 없음 (바늘은 코드가 그림) |

## 아이템 (512×512, 투명 배경)
| 파일 | 내용 |
|---|---|
| assets/items/match.png | 성냥 한 갑 |
| assets/items/candle.png | 꺼진 양초 |
| assets/items/lit_candle.png | 불 켜진 양초 |
| assets/items/key_foyer.png | 낡은 놋쇠 열쇠 |

## 효과음 (Codex 아님 — CC0 사이트에서 수급, mp3)
assets/audio/: pickup, combine, unlock, locked, door_open, clock_tick, sparkle, ghost_giggle, bgm_manor(루프 BGM)
