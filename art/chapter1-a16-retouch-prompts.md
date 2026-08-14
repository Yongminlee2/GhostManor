# Chapter 1 A16 retouch prompts

Galaxy A16 실기기 플레이에서 확인한 획득 후 오브젝트 잔상과 상태 이미지 이음새를 수정할 때 사용한 기록이다. 모든 이미지는 내장 ImageGen의 `precise-object-edit` 모드로 기존 파일을 입력하여 편집했다.

## 1. 현관 외투 주머니

- 입력: `assets/scenes/foyer_coat_clean.png`
- 출력: `assets/scenes/foyer_coat_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor mobile escape-room close-up state image
Primary request: Edit the supplied foyer coat close-up. Remove only the small matchbox/card-like object protruding from the coat's breast pocket, leaving the pocket naturally empty and closed.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the entire original composition, door, coat, coat rack, shoe cabinet, lighting, texture, colors, dimensions and every other pixel as closely as possible. Change only the pocket object and the tiny area directly behind it. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 2. 현관 우편함

- 입력: `assets/scenes/foyer_mailbox.png`
- 출력: `assets/scenes/foyer_mailbox_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor mobile escape-room close-up state image
Primary request: Edit the supplied open brass mailbox close-up. Remove only the sealed envelope/letter from inside the mailbox, leaving the same open mailbox visibly empty with a natural dark interior.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the mailbox, open door, ornament, wall, lighting, composition and every other pixel as closely as possible. Change only the envelope and its immediately occluded interior. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 3. 거실 열린 금고

- 입력: `assets/scenes/living_c_safe_open.png`
- 출력: `assets/scenes/living_c_safe_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied living-room wall. In the already open wall safe on the left, remove only the brass key, oil bottle, and moon music card, leaving the safe door open and the safe interior naturally empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the entire original wall, four portraits, lamps, bookcase, clock, vase, rug, safe door, lighting, exact camera and all unrelated pixels as closely as possible. Change only the three items inside the safe and the tiny area behind them. Keep the safe open. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 4. 서재 비밀 책장

- 입력: `assets/scenes/study_a_nook_open.png`
- 출력: `assets/scenes/study_a_nook_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor mobile escape-room cropped overlay state
Primary request: Edit the supplied open secret bookshelf nook crop. Remove only the round brass lens in the upper-left cubby and the music-note card beside it, leaving those exact shelf spaces naturally empty. Keep the lit candle and every book.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve exact crop, shelf geometry, candle, books, lighting, colors and all unrelated pixels as closely as possible. Change only the lens, card, and directly occluded shelf surface. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 5. 서재 지구본 받침

- 입력: `assets/scenes/study_b_plate.png`
- 출력: `assets/scenes/study_b_plate_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state plate
Primary request: Edit the supplied study wall plate. Remove only the brass key floating inside the open circular globe stand, leaving the circular stand and the empty wallpaper area inside it natural and intact.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the entire original wall, globe stand, desk, spilled ink, door, candle, shelves, camera, lighting and all unrelated pixels as closely as possible. Change only the key and the tiny area behind it. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 6. 지하실 열린 상자

- 입력: `assets/scenes/cellar_c_boxb_open.png`
- 출력: `assets/scenes/cellar_c_boxb_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied cellar wine-rack wall. In the already open wooden chest beneath the bottles, remove only the fuse and the cloud music card, leaving the chest open and visibly empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve all five wine bottles and their candle labels exactly, the ghost, rack, chest lid, lock, room, lighting and all unrelated pixels as closely as possible. Change only the two items inside the chest and their immediately occluded interior. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 7. 주방 찬장

- 입력: `assets/scenes/kitchen_b_cup2_open.png`
- 출력: `assets/scenes/kitchen_b_cup2_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor mobile escape-room cropped cupboard overlay
Primary request: Edit the supplied open narrow cupboard crop. Remove only the glowing singing kettle from inside, leaving the same cupboard door open and the shelves naturally empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the exact cupboard crop, open door, shelves, wall, lighting and all unrelated pixels as closely as possible. Change only the kettle and immediately occluded shelf area. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 8. 지하실 선반 클로즈업

- 입력: `assets/scenes/cellar_shelf_close.png`
- 출력: `assets/scenes/cellar_shelf_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor mobile escape-room 1024x1024 shelf close-up state
Primary request: Edit the supplied cellar shelf close-up. Remove only the brass key lying on the middle shelf, leaving the shelf surface naturally empty. Keep every barrel, bottle, box, cobweb, shelf and candle unchanged.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve exact crop, perspective, lighting and all unrelated pixels as closely as possible. Change only the key and its directly occluded shelf. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 9. 다락방 열린 상자

- 입력: `assets/scenes/attic_c_chest_open.png`
- 출력: `assets/scenes/attic_c_chest_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor mobile escape-room cropped open-chest state overlay
Primary request: Edit the supplied attic scene. Remove only the torn embroidery shred/paper-like fabric piece inside the already open small chest at lower left, leaving the chest open and visibly empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the exact entire scene, chest lid, combination lock, wall, window, embroidery frame, candles, books and all unrelated pixels as closely as possible. Change only the shred and its directly occluded chest interior. Keep chest open. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 10. 주방 병·버섯 상태 3종

- 공통 입력: `assets/scenes/kitchen_a.png`

### 10-1. 병 획득 상태

- 출력: `assets/scenes/kitchen_a_no_bottle.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied kitchen wall. Remove only the empty glass bottle standing on the far-left counter, leaving the counter surface naturally empty. Keep the mushroom jar on the upper-left shelf.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the entire original composition, ghost chef, stove, pot, blue flame, mushroom jar, cupboards, walls, lighting and all unrelated pixels as closely as possible. Change only the empty bottle and directly occluded counter. No text, numbers, logo, watermark, square seam or pasted patch.
```

### 10-2. 버섯 획득 상태

- 출력: `assets/scenes/kitchen_a_empty_jar.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied kitchen wall. Change only the glass jar on the upper-left shelf so that the jar remains in the same place but is visibly empty, with no dried mushrooms inside. Keep the empty glass bottle on the far-left counter.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 game illustration.
Constraints: preserve the entire original composition, ghost chef, stove, pot, blue flame, bottle, cupboards, walls, lighting and all unrelated pixels as closely as possible. Change only the contents of the mushroom jar. No text, numbers, logo, watermark, square seam or pasted patch.
```

### 10-3. 병·버섯 모두 획득한 상태

- 출력: `assets/scenes/kitchen_a_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied kitchen wall with exactly two inventory-state changes: remove the empty glass bottle from the far-left counter, and leave the upper-left glass jar in place but remove all dried mushrooms from inside so it is visibly empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 조명, 귀엽지만 으스스한 빅토리안 저택 모바일 game illustration.
Constraints: preserve the entire original composition, ghost chef, stove, pot, blue flame, cupboards, walls, lighting and all unrelated pixels as closely as possible. Change only those two collectible states and directly occluded surfaces. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 11. 주방 부지깽이

- 입력: `assets/scenes/kitchen_c.png`
- 출력: `assets/scenes/kitchen_c_no_poker.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied kitchen cold-room wall. Remove only the long black fireplace poker hanging vertically from the right side of the wall, including its circular handle and hooked lower tip, leaving the wallpaper behind it natural and continuous.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the entire original composition, ice-covered door, hanging sausages, recipe board, three jars, candle, rug, lighting and all unrelated pixels as closely as possible. Change only the poker and directly occluded wallpaper. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 12. 지하실 높은 선반 열쇠

- 입력: `assets/scenes/cellar_a.png`
- 출력: `assets/scenes/cellar_a_key_removed.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1536 mobile escape-room full wall state image
Primary request: Edit the supplied cellar wall. Remove only the brass key lying on the high wooden shelf near the top center, leaving the same shelf surface naturally empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the entire original composition, shelf, crates, shivering ghost, candle, barrels, bottles, floor, lighting and all unrelated pixels as closely as possible. Change only the brass key and directly occluded shelf. No new object. No text, numbers, logo, watermark, square seam or pasted patch.
```

## 13. 현관 서랍 이음새 재수정

- 입력: `assets/scenes/foyer_drawer_lit.png`
- 출력(덮어쓰기): `assets/scenes/foyer_drawer_empty.png`

```text
Use case: precise-object-edit
Asset type: GhostManor 1024x1024 mobile escape-room close-up state image
Primary request: Edit the supplied lit open foyer drawer close-up. Remove only the brass key lying in the center of the drawer, leaving the same open drawer naturally and completely empty.
Input images: Image 1 is the exact edit target.
Style/medium: 코믹 호러 카툰 스타일, 두꺼운 다크 초콜릿색 외곽선, 보라·남색 어두운 톤에 따뜻한 촛불 오렌지 포인트 조명, 귀엽지만 으스스한 낡은 빅토리안 저택 모바일 게임 일러스트.
Constraints: preserve the drawer, wooden grain, illumination, furniture, exact camera, composition, dimensions and every unrelated pixel as closely as possible. Reconstruct only the tiny wood area directly hidden by the key, matching surrounding planks seamlessly. Absolutely no rectangular patch, square seam, pasted rectangle, key fragment, new object, text, numbers, logo, or watermark.
```
