"""아이폰판 아트 정합 손질 — 원본 그림(ORIG 커밋)에서 다시 만들어 assets/ 에 쓴다.

같은 결과가 다시 나오도록 입력은 언제나 ORIG 커밋의 원본이다(이미 손질한 파일을 또 손질하지 않는다).
  python3 tool/art_fix/remaster.py            # 전부
  python3 tool/art_fix/remaster.py patches    # 한 묶음만

필요: numpy, pillow, opencv-python-headless
무엇을 왜 고쳤는지는 docs/DEVLOG.md 「아이폰판 아트 정합」.
"""
import io
import json
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image

ORIG = '4962f06'  # 손질 전 마지막 커밋
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets')
RECT_LOG = {}  # 코드에 옮길 비율 좌표 기록 (build/art_fix_rects.json)


# ── 입출력 ──────────────────────────────────────────────

def orig(path):
    """ORIG 커밋의 원본을 RGBA float32(0~1) 로."""
    raw = subprocess.run(['git', 'show', f'{ORIG}:assets/{path}'], cwd=ROOT,
                         capture_output=True, check=True).stdout
    return np.asarray(Image.open(io.BytesIO(raw)).convert('RGBA'), dtype=np.float32) / 255.0


def save(path, rgba):
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8))
    if im.getchannel('A').getextrema()[0] == 255:
        im = im.convert('RGB')
    im.save(os.path.join(OUT, path), optimize=True)
    print('  ', path, im.size)


def log_rect(name, x, y, w, h, W=1024, H=1536):
    RECT_LOG[name] = [round(x / W, 4), round(y / H, 4), round(w / W, 4), round(h / H, 4)]


# ── 도구 ────────────────────────────────────────────────

def feather_rect(h, w, f):
    """가장자리 f 픽셀에서 0→1 로 부드럽게 오르는 사각 마스크."""
    yy = np.minimum(np.arange(h), np.arange(h)[::-1])[:, None]
    xx = np.minimum(np.arange(w), np.arange(w)[::-1])[None, :]
    m = np.clip(np.minimum(yy, xx) / max(f, 1), 0, 1)
    return m * m * (3 - 2 * m)


def smooth_mask(mask, grow, blur):
    m = mask.astype(np.uint8)
    if grow > 0:
        m = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (grow * 2 + 1, grow * 2 + 1)))
    m = m.astype(np.float32)
    if blur > 0:
        m = cv2.GaussianBlur(m, (0, 0), blur)
    return np.clip(m, 0, 1)


def diff_mask(a, b, th=0.10, blur_in=2.0):
    """두 그림이 눈에 띄게 다른 곳."""
    da = cv2.GaussianBlur(a[..., :3], (0, 0), blur_in)
    db = cv2.GaussianBlur(b[..., :3], (0, 0), blur_in)
    return np.abs(da - db).sum(2) > th


def patch(base, variant, x, y, w, h, feather=22, th=None, grow=10):
    """variant 의 (x,y,w,h) 를 잘라 가장자리를 base 로 녹인 오버레이(RGBA).
    th 가 있으면 두 그림이 다른 곳만 남긴다(바뀐 물건만, 다시 그려진 배경 잡티는 버림)."""
    v = variant[y:y + h, x:x + w].copy()
    a = feather_rect(h, w, feather)
    if th is not None:
        a = a * smooth_mask(diff_mask(base[y:y + h, x:x + w], v, th), grow, grow * 0.6)
    v[..., 3] = a
    return v


def soft_edges(crop, base_region, th=0.08, feather=10):
    """배경에서 잘라 만든 불투명 오버레이 — 배경과 같은 곳은 투명하게, 테두리는 녹게."""
    m = smooth_mask(diff_mask(crop, base_region, th), 8, 5)
    out = crop.copy()
    out[..., 3] = np.maximum(m, 0) * feather_rect(*crop.shape[:2], feather)
    return out


# ── 묶음 1: 장면 통째 교체 → 바뀐 물건만 덧그림 ──────────────

def patches():
    """다시 그려진 장면 통째(초상화·조명까지 미세하게 달라 화면이 덜컥 바뀌었다)를
    바뀐 물건 자리만 남긴 덧그림으로. 지하실 퓨즈는 통째 그림이 와인통 스프라이트를
    덮어 통이 사라지던 결함도 같이 없어진다."""
    jobs = [
        # 이름, 바탕, 바뀐 장면, 자리(px), 다른 곳만?
        ('living_c_safe_knob.png', 'living_c.png', (30, 440, 300, 360), None),
        ('living_c_safe_open.png', 'living_c.png', (30, 440, 300, 360), None),
        ('cellar_b_fuse1.png', 'cellar_b_plate.png', (130, 460, 200, 220), None),
        ('cellar_b_fuse2.png', 'cellar_b_plate.png', (130, 460, 200, 220), None),
        ('cellar_c_boxb_open.png', 'cellar_c.png', (340, 830, 360, 250), None),
        ('attic_c_chest_open.png', 'attic_c.png', (150, 1000, 330, 300), None),
    ]
    for name, base_name, (x, y, w, h), th in jobs:
        base, var = orig('scenes/' + base_name), orig('scenes/' + name)
        save('scenes/' + name, patch(base, var, x, y, w, h, th=th))
        log_rect(name, x, y, w, h)


# ── 묶음 2: 따로 그려 안 맞던 상태 그림을 배경에서 다시 만들기 ──────

def arch_mask(w, h, arch):
    """폭 w, 높이 h 문짝 모양(위가 arch 높이만큼 둥근 아치)."""
    m = np.zeros((h, w), np.float32)
    m[arch:, :] = 1
    if arch > 0:
        cv2.ellipse(m, (w // 2, arch), (w // 2, arch), 0, 180, 360, 1, -1)
    return m


def shade(rgb, k):
    return rgb * k


def open_door(base, box, arch, hinge, interior, crop, leaf_frac=0.2, tint=(0.75, 0.7, 0.9),
              interior_gain=0.75):
    """배경의 문짝을 경첩 쪽으로 열어 젖힌 덧그림. 문틀은 그대로 두고 문짝 자리만 바꾼다.
    interior: 문 너머 그림(원본 덧그림에서 문틀 없이 잘라 씀), crop: 그 안의 (x,y,w,h)."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    m = arch_mask(w, h, arch)
    ix, iy, iw, ih = crop
    inner = cv2.resize(interior[iy:iy + ih, ix:ix + iw], (w, h), interpolation=cv2.INTER_AREA)
    rgb = inner[..., :3] * np.array(tint, np.float32) * interior_gain
    # 문 너머는 가장자리로 갈수록 어둡게(문틀 그림자)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(xx, w - 1 - xx) / (w * 0.18), 1.0)
    rgb *= (0.45 + 0.55 * edge)[..., None]
    # 젖힌 문짝: 경첩 모서리는 그대로, 반대쪽 모서리는 경첩 쪽으로 좁아지고 원근으로 짧아진다.
    leaf = base[y0:y1, x0:x1].copy()
    leaf[..., 3] = m
    lw = max(int(w * leaf_frac), 6)
    sq = h * 0.035
    if hinge == 'right':
        src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
        dst = np.float32([[w - lw, sq], [w, 0], [w, h], [w - lw, h - sq]])
    else:
        src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
        dst = np.float32([[0, 0], [lw, sq], [lw, h - sq], [0, h]])
    M = cv2.getPerspectiveTransform(src, dst)
    wl = cv2.warpPerspective(leaf, M, (w, h), flags=cv2.INTER_AREA, borderValue=(0, 0, 0, 0))
    wl[..., :3] *= 0.62  # 열린 문짝은 그늘
    # 문짝 바깥 모서리에 떨어지는 그림자
    sh = np.zeros((h, w), np.float32)
    band = int(w * 0.10)
    if hinge == 'right':
        sh[:, max(w - lw - band, 0):w - lw] = np.linspace(0, 0.55, min(band, w - lw))[None, :]
    else:
        sh[:, lw:lw + band] = np.linspace(0.55, 0, band)[None, :]
    rgb *= (1 - sh)[..., None]
    a = wl[..., 3:4]
    rgb = wl[..., :3] * a + rgb * (1 - a)
    out = np.dstack([rgb, cv2.GaussianBlur(m, (0, 0), 0.8)])
    return out


def doors():
    f_in = orig('scenes/foyer_a_door_open.png')
    k_in = orig('scenes/kitchen_b_door_open.png')
    jobs = [
        # 덧그림, 바탕, 문짝 상자(x0,y0,x1,y1), 아치 높이, 경첩, 문 너머 그림, 그 안 자르기
        ('foyer_a_door_open.png', 'foyer_a.png', (392, 392, 638, 1128), 105, 'left', f_in, (78, 0, 105, 676), {}),
        ('living_b_door_open.png', 'living_b.png', (610, 398, 912, 1084), 0, 'right', f_in, (78, 0, 105, 676),
         {'interior_gain': 0.45}),
        ('study_b_door_open.png', 'study_b.png', (608, 268, 968, 982), 40, 'right', f_in, (78, 0, 105, 676),
         {'interior_gain': 0.4, 'tint': (0.7, 0.62, 0.85)}),
        ('kitchen_b_door_open.png', 'kitchen_b.png', (680, 760, 902, 1214), 70, 'right', k_in, (24, 0, 214, 470),
         {'tint': (0.8, 0.75, 0.95)}),
    ]
    for name, base_name, box, arch, hinge, interior, crop, kw in jobs:
        base = orig('scenes/' + base_name)
        if name == 'study_b_door_open.png':
            base = orig('scenes/study_b_plate.png')
        out = open_door(base, box, arch, hinge, interior, crop, **kw)
        save('scenes/' + name, out)
        x0, y0, x1, y1 = box
        log_rect(name, x0, y0, x1 - x0, y1 - y0)


def tv_static():
    """거실 TV 지지직 — 그림 속 화면(둥근 사각형)에 정확히 맞춘다(원본은 받침대까지 덮는 다른 TV 그림이었다)."""
    x0, y0, x1, y1 = 76, 362, 338, 578          # 덧그림 자리(빛 번짐 여유 포함)
    sx0, sy0, sx1, sy1, r = 101, 387, 313, 552, 16  # 화면(그림에서 잼)
    h, w = y1 - y0, x1 - x0
    scr = np.zeros((h, w), np.uint8)
    cv2.rectangle(scr, (sx0 - x0 + r, sy0 - y0), (sx1 - x0 - r, sy1 - y0), 1, -1)
    cv2.rectangle(scr, (sx0 - x0, sy0 - y0 + r), (sx1 - x0, sy1 - y0 - r), 1, -1)
    for cx, cy in [(sx0 + r, sy0 + r), (sx1 - r, sy0 + r), (sx0 + r, sy1 - r), (sx1 - r, sy1 - r)]:
        cv2.circle(scr, (cx - x0, cy - y0), r, 1, -1)
    rng = np.random.default_rng(7)
    noise = rng.random((h // 2 + 1, w // 2 + 1)).astype(np.float32)
    noise = cv2.resize(noise, (w, h), interpolation=cv2.INTER_NEAREST)
    noise = 0.55 * noise + 0.45 * cv2.GaussianBlur(rng.random((h, w)).astype(np.float32), (0, 0), 0.7)
    lines = (0.85 + 0.15 * (np.arange(h) % 3 == 0))[:, None]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = (sx0 + sx1) / 2 - x0, (sy0 + sy1) / 2 - y0
    vig = 1 - 0.5 * (((yy - cy) / ((sy1 - sy0) / 2)) ** 2 + ((xx - cx) / ((sx1 - sx0) / 2)) ** 2) / 2
    v = np.clip(noise * lines * vig, 0, 1)
    col = np.dstack([0.55 + 0.35 * v, 0.5 + 0.35 * v, 0.72 + 0.28 * v]) * (0.3 + 0.6 * v)[..., None]
    a = cv2.GaussianBlur(scr.astype(np.float32), (0, 0), 1.0)
    glow = cv2.GaussianBlur(scr.astype(np.float32), (0, 0), 9) * 0.28 * feather_rect(h, w, 10)
    glow_col = np.array([0.62, 0.58, 0.85], np.float32)
    rgb = col * a[..., None] + glow_col * (1 - a[..., None])
    alpha = np.maximum(a, glow * (1 - a))
    save('scenes/living_b_tv_on.png', np.dstack([rgb, alpha]))
    log_rect('living_b_tv_on.png', x0, y0, w, h)


def flame(h, w, cx, top, fh, fw, seed=0):
    """촛불 하나: 흰-노랑 속불꽃 + 주황 겉불꽃 + 은은한 빛무리. (rgb, alpha) 를 돌려준다."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # 물방울 모양: 아래는 둥글고 위는 뾰족
    t = np.clip((yy - top) / fh, 0, 1)
    half = fw * 0.5 * np.sin(np.pi * np.clip(t, 0, 1) ** 0.75) + 0.01
    d = np.abs(xx - cx) / half
    inside = ((yy >= top) & (yy <= top + fh)).astype(np.float32)
    outer = np.clip(1.15 - d, 0, 1) * inside
    inner = np.clip(1.0 - d * 1.7, 0, 1) * inside * np.clip((t - 0.25) / 0.4, 0, 1)
    outer = cv2.GaussianBlur(outer, (0, 0), 0.9)
    inner = cv2.GaussianBlur(inner, (0, 0), 0.7)
    r2 = ((xx - cx) / (fh * 1.1)) ** 2 + ((yy - (top + fh * 0.6)) / (fh * 1.4)) ** 2
    glow = np.exp(-r2 * 2.0) * 0.45 * feather_rect(h, w, 14)
    rgb = np.zeros((h, w, 3), np.float32)
    rgb[:] = (1.0, 0.62, 0.22)
    rgb = rgb * (1 - outer[..., None]) + np.array([1.0, 0.55, 0.12]) * outer[..., None]
    rgb = rgb * (1 - inner[..., None]) + np.array([1.0, 0.97, 0.8]) * inner[..., None]
    alpha = np.clip(np.maximum(outer, glow), 0, 1)
    alpha = np.maximum(alpha, inner)
    return rgb, alpha


def candles():
    """거실 촛대 켬 — 원본은 촛대 색까지 다른 그림이라 켜면 촛대가 바뀌어 보였다.
    배경의 촛대는 그대로 두고 심지 위에 불꽃과 빛무리만 얹는다."""
    base = orig('scenes/living_a.png')
    for i, x0 in enumerate([61, 287, 635, 860], 1):
        y0, w, h = 799, 102, 246
        reg = base[y0:y0 + h, x0:x0 + w, :3]
        lum = reg.mean(2)
        sat = reg.max(2) - reg.min(2)
        wax = (lum > 0.42) & (sat < 0.18)
        wax[int(h * 0.45):] = False
        ys, xs = np.where(wax)
        top = ys.min() if len(ys) else 40
        cx = float(np.median(xs[ys < top + 12])) if len(ys) else w / 2
        # 불꽃 자리 위로 공간을 두고 다시 자른다
        pad, side = 56, 20
        H2, W2 = h + pad, w + side * 2
        rgb, a = flame(H2, W2, cx + side, top + pad - 30, 30, 12, seed=i)
        save(f'scenes/living_a_candle{i}_on.png', np.dstack([rgb, a]))
        log_rect(f'living_a_candle{i}_on.png', x0 - side, y0 - pad, W2, H2)


def fire():
    """벽난로 불 — 원본은 벽난로·러그까지 통째로 그린 다른 그림이었다.
    배경 아궁이(그림에서 잰 아치) 안 벽돌을 불빛으로 물들이고 불꽃을 넣는다. 철망은 불 앞에 남긴다."""
    base = orig('scenes/living_a.png')
    src = orig('scenes/living_a_fire.png')
    x0, y0, x1, y1 = 340, 700, 690, 1080       # 덧그림 자리(불빛 번짐 여유 포함)
    hx0, hy0, hx1, hy1, arch = 393, 761, 640, 1020, 72  # 아궁이(그림에서 잼)
    reg = base[y0:y1, x0:x1]
    h, w = y1 - y0, x1 - x0
    hole = np.zeros((h, w), np.float32)
    hole[hy0 - y0:hy1 - y0, hx0 - x0:hx1 - x0] = arch_mask(hx1 - hx0, hy1 - hy0, arch)
    holef = cv2.GaussianBlur(hole, (0, 0), 1.5)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cxh, cyh = (hx0 + hx1) / 2 - x0, hy1 - y0 - 40
    # 아궁이 안 벽돌을 불빛으로(아래 가운데가 가장 밝다)
    warm = np.exp(-(((xx - cxh) / ((hx1 - hx0) * 0.55)) ** 2 + ((yy - cyh) / ((hy1 - hy0) * 0.7)) ** 2))
    lit = reg[..., :3] * (1.0 + warm[..., None] * np.array([3.2, 1.7, 0.8])) + \
        warm[..., None] * np.array([0.10, 0.035, 0.0])
    rgb = reg[..., :3] * (1 - holef[..., None]) + np.clip(lit, 0, 1) * holef[..., None]
    # 원본 불 그림에서 불꽃만(밝고 주황) 뽑아 아궁이 바닥에 세운다
    fs = src[20:300, 100:310]
    fl = fs[..., :3]
    fa = np.clip((fl[..., 0] - fl[..., 2] - 0.18) * 2.2, 0, 1) * np.clip((fl.max(2) - 0.35) * 2, 0, 1)
    fw, fh = int((hx1 - hx0) * 0.78), int((hy1 - hy0) * 0.72)
    fl = cv2.resize(fl, (fw, fh), interpolation=cv2.INTER_AREA)
    fa = cv2.resize(fa, (fw, fh), interpolation=cv2.INTER_AREA)
    ox, oy = int((hx0 + hx1) / 2 - x0 - fw / 2), int(hy1 - y0 - 18 - fh)
    a = fa * hole[oy:oy + fh, ox:ox + fw]
    rgb[oy:oy + fh, ox:ox + fw] = fl * a[..., None] + rgb[oy:oy + fh, ox:ox + fw] * (1 - a[..., None])
    # 철망은 불 앞: 배경의 쇠붙이(주변보다 밝은 곳)를 불빛 받은 색으로 다시 얹는다
    blum = reg[..., :3].mean(2)
    med = cv2.medianBlur((blum * 255).astype(np.uint8), 15).astype(np.float32) / 255
    metal = ((blum - med) > 0.025) & (yy > 940 - y0) & (hole > 0.5)
    metal = cv2.GaussianBlur(metal.astype(np.float32), (0, 0), 0.6)
    lit_metal = np.clip(reg[..., :3] * np.array([1.9, 1.3, 0.85]), 0, 1)
    rgb = rgb * (1 - metal[..., None]) + lit_metal * metal[..., None]
    # 아궁이 밖으로 번지는 불빛(돌 테두리·바닥) — 덧그림 가장자리 전에 0 이 되게
    glow = np.exp(-(((xx - cxh) / (w * 0.42)) ** 2 + ((yy - cyh) / (h * 0.42)) ** 2)) * feather_rect(h, w, 40)
    outside = 1 - holef
    rgb = rgb * (1 - (glow * outside)[..., None]) + \
        np.clip(reg[..., :3] * np.array([1.7, 1.25, 0.95]), 0, 1) * (glow * outside)[..., None]
    alpha = np.maximum(holef, glow * 0.9)
    save('scenes/living_a_fire.png', np.dstack([rgb, np.clip(alpha, 0, 1)]))
    log_rect('living_a_fire.png', x0, y0, w, h)


def cut_sprite(with_obj, without_obj, th=0.10, grow=3):
    """물건이 있는 장면 - 없는 장면 = 물건만 남은 투명 스프라이트(배경과 같은 그림이라 색·크기가 꼭 맞다)."""
    m = diff_mask(with_obj, without_obj, th, blur_in=1.5).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    k = 1 + int(np.argmax(st[1:, 4]))
    m = (lab == k).astype(np.uint8)
    # 구멍 메우기
    ff = m.copy()
    cv2.floodFill(ff, None, (0, 0), 1)
    m = m | (1 - ff)
    a = smooth_mask(m, grow, 1.2)
    out = with_obj.copy()
    out[..., 3] = a
    return out, cv2.boundingRect(m)


def globe():
    """서재 지구본 반쪽 — 원본은 보라색의 다른 지구본이었다. study_b(지구본 있음) - study_b_plate(없음)
    으로 잘라 가운데서 둘로 나눈다. 닫히면 원래 그림과 똑같다."""
    full, plate = orig('scenes/study_b.png'), orig('scenes/study_b_plate.png')
    spr, (x, y, w, h) = cut_sprite(full, plate)
    # 공 부분만: 받침 고리 조각은 판에 그려져 있으니 원(타원) 밖은 버린다
    m = (spr[..., 3] > 0.5).astype(np.uint8)
    cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    (ex, ey), (ew, eh), ang = cv2.fitEllipse(max(cnts, key=cv2.contourArea))
    ell = np.zeros(m.shape, np.float32)
    cv2.ellipse(ell, ((ex, ey), (ew * 0.99, eh * 0.99), ang), 1, -1)
    spr[..., 3] *= cv2.GaussianBlur(ell, (0, 0), 1.0)
    ys, xs = np.where(spr[..., 3] > 0.05)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cx = int(round(ex))
    left = spr[y0:y1, x0:cx].copy()
    right = spr[y0:y1, cx:x1].copy()
    # 잘린 면은 살짝 어둡게(속이 보이는 단면)
    for half, edge in ((left, slice(-4, None)), (right, slice(0, 4))):
        half[:, edge, :3] *= 0.55
    save('scenes/study_globe_left.png', left)
    save('scenes/study_globe_right.png', right)
    RECT_LOG['obj:globe'] = {'cx': round(cx / 1024, 4), 'top': round(y0 / 1536, 4),
                             'lw': round((cx - x0) / 1024, 4), 'rw': round((x1 - cx) / 1024, 4),
                             'h': round((y1 - y0) / 1536, 4)}


def barrel():
    """지하실 와인통 — 원본 스프라이트는 다른 통이라 배경 통과 크기·모양이 달랐다.
    cellar_b(통 있음)에서 통 몸통(그림에서 잰 타원)과 받침(cellar_b_plate 와 다른 곳)만 오려 낸다.
    통 나뭇결이 뒤 문과 색이 비슷해 차이만으로는 몸통이 구멍 난다."""
    full, plate = orig('scenes/cellar_b.png'), orig('scenes/cellar_b_plate.png')
    H, W = full.shape[:2]
    m = np.zeros((H, W), np.float32)
    cv2.ellipse(m, (557, 823), (266, 302), 0, 0, 360, 1, -1)
    # 받침 다리: 통 아래 띠를 통째로(가장자리는 녹여서) — 원래 자리에선 배경과 같고, 밀면 다리째 움직인다
    d = smooth_mask(diff_mask(full, plate, 0.05, 1.5), 14, 0).astype(np.float32)
    stand = np.zeros((H, W), np.float32)
    stand[1040:1190, 400:715] = feather_rect(150, 315, 18)
    m = np.maximum(m, stand * d)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    a = cv2.GaussianBlur(m, (0, 0), 1.2)
    spr = full.copy()
    spr[..., 3] = a
    ys, xs = np.where(a > 0.05)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    save('scenes/cellar_barrel_sprite.png', spr[y0:y1, x0:x1])
    RECT_LOG['obj:barrel'] = [round(x0 / 1024, 4), round(y0 / 1536, 4),
                              round((x1 - x0) / 1024, 4), round((y1 - y0) / 1536, 4)]

def dump_area(scene_id, image):
    d = json.load(open(os.path.join(ROOT, 'build', 'scene_dump.json')))
    sc = next(x for x in d if x['id'] == scene_id)
    return sc['image'], next(o['area'] for o in sc['overlays'] if o['image'].endswith(image))


def soft():
    """배경에서 잘라 만든 불투명 덧그림 — 배경과 같은 곳은 투명, 테두리는 녹게(네모 자국 없앰).
    좌표는 그대로라 코드를 안 고친다. build/scene_dump.json 이 필요하다(tool/art_check)."""
    jobs = [('living_a', 'living_a_nook_open.png'), ('study_a', 'study_a_book_red.png'),
            ('study_a', 'study_a_book_blue.png'), ('study_a', 'study_a_book_yellow.png'),
            ('study_a', 'study_a_book_green.png'), ('study_a', 'study_a_nook_open2.png'),
            ('shoes', 'foyer_shoes_candle.png'), ('kitchen_b', 'kitchen_b_cup2_open.png'),
            ('kitchen_c', 'kitchen_c_ice1.png'), ('kitchen_c', 'kitchen_c_ice2.png'),
            ('kitchen_c', 'kitchen_c_ice3.png')]
    for sid, name in jobs:
        bimg, (x, y, w, h) = dump_area(sid, name)
        base = orig(bimg.replace('assets/', ''))
        H, W = base.shape[:2]
        ov = orig('scenes/' + name)
        oh, ow = ov.shape[:2]
        X, Y = int(round(x * W)), int(round(y * H))
        bw, bh = int(round(w * W)), int(round(h * H))
        reg = cv2.resize(base[Y:Y + bh, X:X + bw], (ow, oh), interpolation=cv2.INTER_AREA)
        save('scenes/' + name, soft_edges(ov, reg, th=0.10, feather=8))


def key_floor():
    """지하실 바닥 열쇠 — 원본은 나무판째(열쇠는 반만) 잘라 돌바닥에 붙인 네모였다.
    선반 클로즈업에 그려진 같은 열쇠를 오려 바닥에 눕히고 그림자를 단다."""
    src = orig('scenes/cellar_shelf_close.png')[405:555, 480:695]
    rgb = src[..., :3]
    key = ((rgb[..., 0] - rgb[..., 2] > 0.05) & (rgb[..., 0] > 0.28)).astype(np.uint8)
    key = cv2.morphologyEx(key, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(key)
    k = 1 + int(np.argmax(st[1:, 4]))
    key = (lab == k).astype(np.uint8)
    ff = key.copy()
    cv2.floodFill(ff, None, (0, 0), 1)
    key = key | (1 - ff) * 0  # 고리 구멍은 그대로 비워 둔다
    x, y, w, h = cv2.boundingRect(key)
    m = 10
    a = cv2.GaussianBlur(key.astype(np.float32), (0, 0), 0.7)[y:y + h, x:x + w]
    col = rgb[y:y + h, x:x + w] * np.array([1.05, 0.95, 0.8])  # 바닥 불빛(주황) 쪽으로
    a = np.pad(a, m)
    col = np.pad(col, ((m, m), (m, m), (0, 0)))
    sh = np.roll(np.roll(cv2.GaussianBlur(a, (0, 0), 3), 4, 0), 3, 1) * 0.65
    out = np.zeros(a.shape + (4,), np.float32)
    out[..., 3] = np.maximum(a, sh)
    out[..., :3] = col * (a / np.maximum(out[..., 3], 1e-4))[..., None]
    out = cv2.resize(out, (123, int(123 * out.shape[0] / out.shape[1])), interpolation=cv2.INTER_AREA)
    save('scenes/cellar_a_key_floor.png', out)
    log_rect('cellar_a_key_floor.png', 410, 1229 + 10, 123, out.shape[0])


def glows():
    """지하실 야광 낙서 — 형광 클립아트처럼 떠 보였다. 벽이 비치게 살짝 투명하게, 바깥으로 은은한 번짐."""
    for name in ['cellar_a_glow.png', 'cellar_b_glow2.png', 'cellar_b_glow_arrow.png', 'cellar_c_glow3.png']:
        g = orig('scenes/' + name)
        a = g[..., 3]
        halo = cv2.GaussianBlur(a, (0, 0), 6) * 0.45
        rgb = g[..., :3] * np.array([0.82, 1.0, 0.78]) * 0.92
        col = np.array([0.45, 1.0, 0.45], np.float32)
        na = np.maximum(a * 0.82, halo)
        mix = (a * 0.82 / np.maximum(na, 1e-4))[..., None]
        out = np.dstack([rgb * mix + col * (1 - mix), na * feather_rect(*a.shape, 4)])
        save('scenes/' + name, out)


def ghostly(img, tint, alpha_k=0.9, glow=(0.75, 0.72, 0.95), sat_k=0.6, gain=0.85):
    """유령 스프라이트를 장면 빛에 맞춘다: 채도·밝기를 낮추고, 살짝 비치게, 바깥에 옅은 빛."""
    rgb = img[..., :3]
    gray = rgb.mean(2, keepdims=True)
    rgb = (gray + (rgb - gray) * sat_k) * np.array(tint, np.float32) * gain
    a = img[..., 3]
    halo = cv2.GaussianBlur(a, (0, 0), 7) * 0.35
    body = a * alpha_k
    na = np.maximum(body, halo)
    mix = (body / np.maximum(na, 1e-4))[..., None]
    return np.dstack([rgb * mix + np.array(glow, np.float32) * (1 - mix), na])


def ghosts():
    """따로 그려 번들거리던 유령 스프라이트를 배경 그림 톤으로. 집사 고스포는 다락방 그림 속 고스포처럼
    회청색 얼굴·검은 연미복 쪽으로 색을 옮긴다."""
    b = orig('scenes/ghost_butler.png')
    hsv = cv2.cvtColor(b[..., :3], cv2.COLOR_RGB2HSV)
    hsv[..., 0] = (hsv[..., 0] * 0 + 222)  # 보라 → 회청
    hsv[..., 1] *= 0.32
    rgb = cv2.cvtColor(hsv, cv2.COLOR_HSV2RGB)
    # 어두운 옷은 더 검게(연미복)
    lum = rgb.mean(2, keepdims=True)
    rgb = np.where(lum < 0.35, rgb * 0.55, rgb)
    b = np.dstack([rgb, b[..., 3]])
    save('scenes/ghost_butler.png', ghostly(b, (0.92, 0.95, 1.0), 0.92, (0.7, 0.75, 0.9), 1.0, 0.95))
    for name in ['living_b_boo_door.png', 'living_b_boo_sofa.png']:
        save('scenes/' + name, ghostly(orig('scenes/' + name), (0.86, 0.84, 0.98), 0.86))


def icon():
    """앱 아이콘 1024(알파 없음) — 현관 아치문 앞에 부우. Flutter 기본 아이콘을 대신한다."""
    bg = orig('scenes/foyer_a.png')[300:900, 210:810]
    bg = cv2.resize(bg, (1024, 1024), interpolation=cv2.INTER_CUBIC)[..., :3]
    yy, xx = np.mgrid[0:1024, 0:1024].astype(np.float32)
    r = np.sqrt(((xx - 512) / 512) ** 2 + ((yy - 470) / 560) ** 2)
    bg = bg * np.clip(1.25 - 0.75 * r, 0.25, 1.15)[..., None]
    moon = np.exp(-(((xx - 512) / 260) ** 2 + ((yy - 430) / 300) ** 2)) * 0.22
    bg = bg + moon[..., None] * np.array([0.65, 0.55, 1.0])
    g = ghostly(orig('scenes/living_b_boo_sofa.png'), (0.95, 0.93, 1.0), 0.95, (0.8, 0.76, 1.0), 0.8, 1.05)
    gs = 700
    g = cv2.resize(g, (gs, gs), interpolation=cv2.INTER_AREA)
    ox, oy = (1024 - gs) // 2 + 20, 1024 - gs + 40
    sub = bg[oy:oy + gs, ox:ox + gs]
    h_ = min(gs, 1024 - oy)
    a = g[:h_, :, 3:4]
    bg[oy:oy + h_, ox:ox + gs] = g[:h_, :, :3] * a + sub[:h_] * (1 - a)
    out = np.dstack([np.clip(bg, 0, 1), np.ones((1024, 1024), np.float32)])
    im = Image.fromarray((out[..., :3] * 255 + 0.5).astype(np.uint8))
    p = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'Icon-1024.png')
    im.save(p, optimize=True)
    print('  ', os.path.relpath(p, ROOT))


GROUPS = {
    'patches': patches,
    'doors': doors,
    'tv': tv_static,
    'candles': candles,
    'fire': fire,
    'globe': globe,
    'barrel': barrel,
    'soft': soft,
    'key_floor': key_floor,
    'glows': glows,
    'ghosts': ghosts,
    'icon': icon,
}

if __name__ == '__main__':
    names = sys.argv[1:] or list(GROUPS)
    for n in names:
        print(n)
        GROUPS[n]()
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    p = os.path.join(ROOT, 'build', 'art_fix_rects.json')
    old = json.load(open(p)) if os.path.exists(p) else {}
    old.update(RECT_LOG)
    json.dump(old, open(p, 'w'), indent=1, ensure_ascii=False)
    print(json.dumps(RECT_LOG, ensure_ascii=False))
