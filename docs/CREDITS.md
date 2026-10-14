# 사운드 출처 (CREDITS)

모든 실음원은 CC0(퍼블릭 도메인) 라이선스 — 저작권 표기 의무가 없으나
검증 가능성을 위해 파일별 출처를 기록한다. 나머지 슬롯은
`tool/gen_sfx.py`의 절차 생성 사운드다.

## 소스 팩

| 팩 | 제작자 | 라이선스 | 출처 |
|---|---|---|---|
| RPG Audio | Kenney | CC0 | kenney.nl/assets/rpg-audio |
| Impact Sounds | Kenney | CC0 | kenney.nl/assets/impact-sounds |
| Interface Sounds | Kenney | CC0 | kenney.nl/assets/interface-sounds |
| Fantasy Sound Effects (Tinysized SFX) | Vehicle | CC0 | opengameart.org/content/fantasy-sound-effects-tinysized-sfx |
| 4 Atmospheric Ghostly Loops | Independent.nu (Johannes Pinter) | CC0 | opengameart.org/content/4-atmospheric-ghostly-loops |
| Horror Atmosphere | SubspaceAudio (Juhani Junkala) | CC0 | opengameart.org/content/horror-atmosphere |

## 파일별 매핑

| assets/audio | 원본 파일 | 팩 |
|---|---|---|
| bgm_manor.m4a | Juhani Junkala - Post Apocalyptic Wastelands [Loop Ready].ogg | Horror Atmosphere |
| ambient_foyer.flac | atmoseerie01 | 4 Atmospheric Ghostly Loops |
| ambient_living.flac | atmoseerie02 | 4 Atmospheric Ghostly Loops |
| ambient_study.flac | atmoseerie03 | 4 Atmospheric Ghostly Loops |
| ambient_kitchen.flac | atmoseerie04 | 4 Atmospheric Ghostly Loops |
| (ambient_cellar → ambient_foyer.flac 재사용, ambient_attic → ambient_study.flac 재사용) | | |
| book_flip.wav | book-page-01.wav | Tinysized |
| bottle_fill.wav | water-vial-fill-01.wav | Tinysized |
| fire_ignite.wav | match-light-01.wav | Tinysized |
| liquid_pour.wav | water-pour-01.wav | Tinysized |
| locked.wav | handcuffs-metal-lock-01.wav | Tinysized |
| metal_key.wav | keyhole-lockbox-turn-01.wav | Tinysized |
| paper_rustle.wav | book-page-02.wav | Tinysized |
| sparkle.wav | chimes-wood-rattle.wav (첫 2.3초 발췌·페이드) | Tinysized |
| unlock.wav | handcuffs-metal-open-01.wav | Tinysized |
| wood_slide.wav | drawer-open-01.wav | Tinysized |
| uncork.wav | bottle-glass-uncork-01.wav | Tinysized |
| pot_stir.wav | wood-bowl-spoon-01.wav | Tinysized |
| paper_tear.wav | cover-paper-tear-01.wav | Tinysized |
| pills_shake.wav | bottle-pills-shake-01.wav | Tinysized |
| floor_creak.wav | floor-creak-01.wav | Tinysized |
| ceramic_clink.m4a | impactPlate_light_000.ogg | Impact Sounds |
| glass_clink.m4a | impactGlass_light_000.ogg | Impact Sounds |
| metal_drop.m4a | impactMetal_medium_000.ogg | Impact Sounds |
| wood_knock_dull.m4a | impactWood_medium_000.ogg | Impact Sounds |
| wood_knock_hollow.m4a | impactPlank_medium_000.ogg | Impact Sounds |
| clock_tick.m4a | tick_001.ogg | Interface Sounds |
| combine.m4a | confirmation_001.ogg | Interface Sounds |
| switch_click.m4a | switch_001.ogg | Interface Sounds |
| cloth_rub.m4a | cloth2.ogg | RPG Audio |
| door_open.m4a | doorOpen_1.ogg | RPG Audio |
| metal_click.m4a | metalClick.ogg | RPG Audio |
| pickup.m4a | handleSmallLeather.ogg | RPG Audio |
| wood_creak_open.m4a | creak1.ogg | RPG Audio |

## 자체 제작 슬롯 (절차 합성 v2)

ghost_giggle, note1~4, organ_chord, organ_wrong, stone_drag, tv_static,
music_box(+broken), phonograph, clock_chime
— 어울리는 CC0 실음원이 없어 `tool/gen_sfx.py`에서 직접 설계·합성:
파이프 오르간(디튠 2랭크+드로바 배음+홀 잔향), 유령 웃음(처프 4연속+숨),
브라운 노이즈 끌기(그레인 저더), 브라운관 노이즈(플러터+험+크래클),
오르골 벨(비조화 부분음), 축음기 크랙클, 괘종 3연타.

> 2026-10-14: 아이폰이 Ogg Vorbis 를 못 틀어 `.ogg` 실음원을 같은 음원 그대로 AAC(`.m4a`)로 바꿔 실었다(oggdec → afconvert, BGM 160kbps·효과음 128kbps). 원본 파일명 열은 받은 그대로다.
