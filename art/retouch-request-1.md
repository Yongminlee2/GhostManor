# 리터치 의뢰 1차 — 오버레이 합성 결함 8건

> 전수 합성 검사(2026-08-12)에서 발견된 결함의 재생성 목록.
> **핵심 원칙: A그룹은 반드시 아래 "입력 파일"을 이미지 입력으로 넣고, 그 그림에서
> 지정 부분만 수정(edit)한 전체 그림을 돌려받는다.** 새로 그리면 픽셀이 안 이어져
> 네모난 이음새가 생긴다 (이번 결함의 원인). 공통 스타일: style-guide.md 접두어.

## A그룹 — 전체 프레임 수정 (입력 씬을 edit, 결과는 1024×1536 전체 저장)

| 저장 파일 | 입력 파일 | 수정 지시 |
|---|---|---|
| assets/scenes/study_b_globe_open.png | assets/scenes/study_b.png | 책상 위 지구본만 반으로 갈라져 열린 상태로. 열린 틈 안에 낡은 열쇠가 살짝 보임. 다른 부분은 픽셀 그대로 유지 |
| assets/scenes/cellar_b_barrel_moved.png | assets/scenes/cellar_b.png | 커다란 와인통을 오른쪽으로 밀린 위치로 옮기고, 원래 자리 뒤 벽에 낡고 작은 나무 쪽문이 드러나게. 다른 부분 유지 |
| assets/scenes/attic_b_trunk_open.png | assets/scenes/attic_b.png | 트렁크 뚜껑이 활짝 열려 안에서 오래된 편지(유언장)가 은은한 금빛으로 빛나는 상태. **열쇠 구멍 넣지 말 것**(이 트렁크는 열쇠가 없는 설정). 다른 부분 유지 |
| assets/scenes/attic_a_cards.png | assets/scenes/attic_a.png | 오르간 건반 위 보면대 패널에 음표 카드 4장(달·별·해·구름 그림)이 나란히 꽂힌 상태. 다른 부분 유지 |

## B그룹 — 투명 스프라이트 (배경 완전 투명 PNG, 지정 크기)

| 저장 파일 | 크기 | 내용 |
|---|---|---|
| assets/scenes/cellar_a_glow.png | 246×369 | 유기적인 초록 형광 빛무리 — 상자 윤곽을 감싸는 붓칠 느낌의 발광. **직선 사각 테두리 금지** |
| assets/scenes/cellar_b_glow_arrow.png | 205×246 | 손으로 그린 듯한 초록 야광 화살표(→ 방향), 가장자리가 빛나는 스프레이 느낌. 배경 투명 |
| assets/scenes/living_b_boo_sofa.png | 184×338 | 담요를 뒤집어쓴 보라빛 유령 부우가 편안히 앉아 TV를 보는 모습 — **living_b_boo_door.png와 완전히 같은 그림체·톤** (밝은 스티커풍 금지) |
| assets/scenes/cellar_a_key_floor.png | 123×154 | 낡은 놋쇠 열쇠 하나, 바닥에 떨어진 각도, 배경 완전 투명 |

## 반영 시 코드 변경 (아트 도착 후 개발 측에서 처리)

- A그룹 4장은 전체 프레임 오버레이로 전환 (rect 0,0,1,1) — 이음새 원천 제거
- cellar_a_key_floor는 바닥 위치로 rect 이동 (벽에 떠 있던 문제)
- boo_sofa 위치 미세 조정
