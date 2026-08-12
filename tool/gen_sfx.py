# -*- coding: utf-8 -*-
"""절차 생성 효과음 13종 + 재질별 폴리 20종 + 방별 앰비언스 6종 (총 39,
   플레이스홀더 — CC0 음원으로 교체 가능).
   사용: python tool/gen_sfx.py  → assets/audio/*.wav 생성. 외부 의존성 없음."""
import math, wave, struct, random, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def env(i, n, a=0.02, r=0.35):
    """선형 어택 + 지수형 릴리즈 엔벨로프."""
    t = i / n
    if t < a:
        return t / a
    return math.exp(-4.0 * (t - a) / max(r, 1e-6))


def tone(freq, dur, vol=0.3, harmonics=((1, 1.0),), vib_hz=0.0, vib_amt=0.0,
         attack=0.02, release=0.35, sweep_to=None):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq
        if sweep_to is not None:
            f = freq + (sweep_to - freq) * (i / n)
        if vib_hz:
            f *= 1.0 + vib_amt * math.sin(2 * math.pi * vib_hz * t)
        phase += 2 * math.pi * f / SR
        s = sum(w * math.sin(phase * h) for h, w in harmonics)
        out.append(vol * s * env(i, n, attack, release))
    return out


def click(dur=0.012, vol=0.4, seed=1):
    rnd = random.Random(seed)
    n = int(SR * dur)
    return [vol * (rnd.random() * 2 - 1) * (1 - i / n) for i in range(n)]


def silence(dur):
    return [0.0] * int(SR * dur)


def mix(*layers):
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples)
        w.writeframes(frames)
    print(name + ".wav", len(samples) / SR, "s")


ORGAN = ((1, 1.0), (2, 0.5), (3, 0.25))  # 오르간풍 배음

os.makedirs(OUT, exist_ok=True)

# ── 재질별 폴리 노이즈 헬퍼 ──────────────────────────────────────────


def noise(dur, vol=0.3, seed=1, lp=0.0):
    """화이트 노이즈. lp>0이면 원폴 저역통과(y += lp*(x-y))로 어둡게 물들인다 —
       lp가 작을수록 더 어둡다(나무·천 질감), 0이면 원본 그대로(밝음)."""
    rnd = random.Random(seed)
    n = int(SR * dur)
    out = []
    y = 0.0
    for _ in range(n):
        x = rnd.random() * 2 - 1
        if lp > 0:
            y += lp * (x - y)
            out.append(vol * y)
        else:
            out.append(vol * x)
    return out


def burst(dur, vol=0.3, seed=1, lp=0.0, a=0.02, r=0.35):
    """env() 엔벨로프를 씌운 성형 노이즈 — 노크·스웰·러블 등 폴리 전반에 쓴다."""
    n = int(SR * dur)
    raw = noise(dur, 1.0, seed, lp)
    return [vol * raw[i] * env(i, n, a, r) for i in range(n)]


def overlay(base, clip, t):
    """base(리스트, 제자리 수정)의 t초 지점에 clip을 더해 얹는다 — 앰비언스에
       틱·드립 같은 짧은 이벤트를 배치할 때 쓴다. 경계 밖 샘플은 잘린다."""
    start = int(t * SR)
    for i, v in enumerate(clip):
        j = start + i
        if 0 <= j < len(base):
            base[j] += v


def fade_edges(samples, t=0.05):
    """루프 경계 클릭 방지: 시작·끝 t초를 선형 페이드."""
    n = int(SR * t)
    out = list(samples)
    ln = len(out)
    for i in range(min(n, ln)):
        g = i / n
        out[i] *= g
        out[ln - 1 - i] *= g
    return out


def jitter_gain(n, seed, hz=35, lo=0.35, hi=1.0):
    """샘플-홀드 랜덤 게인 시퀀스 — 부스럭거리는 진폭 흔들림(paper_rustle 등)."""
    rnd = random.Random(seed)
    step = max(1, int(SR / hz))
    out = []
    g = 1.0
    for i in range(n):
        if i % step == 0:
            g = rnd.uniform(lo, hi)
        out.append(g)
    return out


def wind_bed(dur, vol, seed, lp=0.05, swell_hz=0.08):
    """아주 느린 진폭 스웰이 있는 어두운 바람 노이즈 — 방별 앰비언스 공통 베이스."""
    n = int(SR * dur)
    raw = noise(dur, 1.0, seed, lp)
    return [vol * raw[i] * (0.55 + 0.45 * math.sin(2 * math.pi * swell_hz * i / SR))
            for i in range(n)]


def make_drip(freq, gap, repeats, seed):
    """물방울: 핑 + 감쇠 메아리(repeats회, gap초 간격) — 싱크대/지하실용."""
    ping = tone(freq, 0.12, 0.16, attack=0.002, release=0.25)
    out = list(ping)
    for rep in range(1, repeats):
        overlay(out, [v * (0.5 ** rep) for v in ping], rep * gap)
    return out

# 아이템 획득: 밝은 2연속 상승 블립
write("pickup", cat(tone(660, 0.07, 0.28, attack=0.01, release=0.5),
                    tone(880, 0.09, 0.28, attack=0.01, release=0.5)))

# 조합 성공: 상승 아르페지오 3음
write("combine", cat(tone(523, 0.09, 0.25), tone(659, 0.09, 0.25),
                     tone(784, 0.16, 0.27, release=0.6)))

# 잠금 해제: 클릭 + 밝은 차임
write("unlock", mix(cat(click(0.012, 0.5, 3), silence(0.25)),
                    cat(silence(0.02), tone(1319, 0.24, 0.22, release=0.5))))

# 잠김: 둔탁한 노크 두 번
write("locked", cat(tone(150, 0.09, 0.5, harmonics=((1, 1.0), (2, 0.3)),
                          attack=0.005, release=0.15), silence(0.06),
                    tone(140, 0.11, 0.45, harmonics=((1, 1.0), (2, 0.3)),
                          attack=0.005, release=0.15)))

# 문 열림: 낮은 삐걱 스윕 + 덜컹
write("door_open", mix(tone(180, 0.42, 0.3, harmonics=((1, 1.0), (3, 0.2)),
                             vib_hz=11, vib_amt=0.06, sweep_to=90, release=0.5),
                       cat(silence(0.34), tone(80, 0.1, 0.4, attack=0.005,
                                               release=0.2))))

# 시계 틱: 짧은 우드블록
write("clock_tick", mix(click(0.008, 0.35, 5),
                        tone(900, 0.045, 0.22, attack=0.002, release=0.12)))

# 반짝: 아주 높은 4음 셋잇단
write("sparkle", cat(tone(1319, 0.06, 0.18), tone(1568, 0.06, 0.18),
                     tone(1976, 0.06, 0.18), tone(2637, 0.14, 0.2, release=0.7)))

# 유령 웃음: 흔들리는 상승 워블
write("ghost_giggle", tone(360, 0.4, 0.22, harmonics=((1, 1.0), (2, 0.35)),
                            vib_hz=9, vib_amt=0.12, sweep_to=520, release=0.5))

# 오르간 도레미파
for name, f in (("note1", 262), ("note2", 294), ("note3", 330), ("note4", 349)):
    write(name, tone(f, 0.55, 0.26, harmonics=ORGAN, attack=0.04, release=0.45))

# BGM: 24초 루프 — 으스스한 저택 테마. 디튠 드론 + 뮤직박스 선율(단속적,
# 아 harmonic minor+트라이톤 1회) + 차가운 바람 + 중간의 불협 스웰 1회.
# 레이어마다 ≤0.06 피크로 아주 작게.
DUR_BGM = 24.0
_bgm_n = int(SR * DUR_BGM)

# 1) 디튠 드론: 110+110.8Hz(느린 맥놀이=불안감) + 55Hz 서브, 아주 느린 스웰(0.07Hz)
bgm = [(0.018 * math.sin(2 * math.pi * 110.0 * i / SR) +
        0.018 * math.sin(2 * math.pi * 110.8 * i / SR) +
        0.018 * math.sin(2 * math.pi * 55.0 * i / SR)) *
       (0.6 + 0.4 * math.sin(2 * math.pi * 0.07 * i / SR))
       for i in range(_bgm_n)]

# 2) 차가운 바람: 강한 저역통과 노이즈, 아주 느린 진폭 요동
bgm = mix(bgm, wind_bed(DUR_BGM, 0.02, seed=90, lp=0.03, swell_hz=0.05))

# 3) 뮤직박스 선율: 라 단조 하모닉 + 트라이톤 1회, 2.5초 간격(쉼표 1회 포함).
# 얇은 배음, 긴 릴리즈로 "상자 종소리"처럼. 마지막 두 음은 살짝 아래로
# 휘어져("늘어진 테이프") 낡은 뮤직박스 느낌.
_mb_notes = [
    (1.0, 659.25, None),   # E5
    (3.5, 523.25, None),   # C5
    (6.0, 493.88, None),   # B4
    (8.5, 440.00, None),   # A4
    # 11.0 — 쉼표
    (13.5, 415.30, None),  # G#4
    (16.0, 523.25, None),  # C5
    (18.5, 622.25, 613.0),  # D#5(트라이톤) — 살짝 하강
    (21.0, 440.00, 434.0),  # A4 — 살짝 하강
]
for t0, freq, bend in _mb_notes:
    overlay(bgm, tone(freq, 2.2, 0.05, harmonics=((1, 1.0), (3, 0.15)),
                       attack=0.15, release=1.2, sweep_to=bend), t0)

# 4) 멀리서 들리는 불협 스웰: 단2도(220+233Hz)가 무음에서 3초간 부풀었다 사라짐
# — 쉼표(11초) 자리에 겹쳐 배치.
_swell = mix(tone(220, 3.0, 0.025, attack=0.55, release=0.5),
            tone(233, 3.0, 0.025, attack=0.55, release=0.5))
overlay(bgm, _swell, 10.0)

write("bgm_manor", fade_edges(bgm, 0.08))

# ── 재질별 폴리 20종 ──────────────────────────────────────────────

write("wood_slide", mix(
    burst(0.35, 0.30, seed=20, lp=0.06, a=0.45, r=0.3),
    tone(90, 0.35, 0.10, attack=0.4, release=0.35)))

write("wood_knock_dull", cat(
    mix(burst(0.06, 0.40, seed=21, lp=0.05, a=0.01, r=0.12),
        tone(120, 0.07, 0.35, attack=0.005, release=0.14)),
    silence(0.07),
    mix(burst(0.06, 0.38, seed=22, lp=0.05, a=0.01, r=0.12),
        tone(118, 0.07, 0.33, attack=0.005, release=0.14))))

write("wood_knock_hollow", mix(
    burst(0.08, 0.40, seed=23, lp=0.18, a=0.005, r=0.10),
    tone(220, 0.20, 0.28, harmonics=((1, 1.0), (2, 0.25)),
         attack=0.005, release=0.5)))

_wc_squeaks = cat(
    mix(burst(0.09, 0.22, seed=24, lp=0.10, a=0.05, r=0.2),
        tone(260, 0.09, 0.10, vib_hz=18, vib_amt=0.08, attack=0.03, release=0.2)),
    silence(0.06),
    mix(burst(0.09, 0.22, seed=25, lp=0.10, a=0.05, r=0.2),
        tone(320, 0.09, 0.10, vib_hz=20, vib_amt=0.08, attack=0.03, release=0.2)),
    silence(0.06),
    mix(burst(0.09, 0.22, seed=26, lp=0.10, a=0.05, r=0.2),
        tone(390, 0.09, 0.10, vib_hz=22, vib_amt=0.08, attack=0.03, release=0.2)))
wood_creak_open_snd = mix(
    _wc_squeaks, tone(100, 0.5, 0.14, attack=0.05, release=0.6, sweep_to=70))
write("wood_creak_open", wood_creak_open_snd)

write("book_flip", cat(
    burst(0.04, 0.30, seed=27, lp=0.30, a=0.01, r=0.08),
    silence(0.03),
    burst(0.04, 0.22, seed=28, lp=0.30, a=0.01, r=0.08),
    silence(0.03),
    burst(0.04, 0.16, seed=29, lp=0.30, a=0.01, r=0.08)))

_pr_n = int(SR * 0.4)
_pr_raw = noise(0.4, 0.28, seed=30, lp=0.20)
_pr_gain = jitter_gain(_pr_n, seed=31)
paper_rustle_snd = [_pr_raw[i] * _pr_gain[i] * env(i, _pr_n, 0.02, 0.4)
                    for i in range(_pr_n)]
write("paper_rustle", paper_rustle_snd)

write("cloth_rub", burst(0.3, 0.22, seed=32, lp=0.10, a=0.5, r=0.3))

write("glass_clink", mix(
    tone(1800, 0.12, 0.18, attack=0.002, release=0.12),
    tone(2400, 0.12, 0.12, attack=0.002, release=0.10),
    click(0.008, 0.20, seed=33)))

write("ceramic_clink", mix(
    tone(1100, 0.14, 0.18, attack=0.003, release=0.16),
    tone(1600, 0.14, 0.10, attack=0.003, release=0.13)))

write("bottle_fill", mix(
    burst(0.6, 0.16, seed=34, lp=0.15, a=0.1, r=0.6),
    tone(300, 0.6, 0.14, vib_hz=6, vib_amt=0.12, attack=0.08, release=0.6,
         sweep_to=700)))

_lp_n = int(SR * 0.5)
_lp_raw = noise(0.5, 0.18, seed=35, lp=0.18)
liquid_pour_snd = [_lp_raw[i] * (0.7 + 0.3 * math.sin(2 * math.pi * 4 * i / SR))
                   * env(i, _lp_n, 0.08, 0.5) for i in range(_lp_n)]
write("liquid_pour", liquid_pour_snd)

write("metal_key", cat(
    mix(tone(2500, 0.06, 0.14, attack=0.002, release=0.12),
        click(0.006, 0.15, seed=36)),
    silence(0.02),
    mix(tone(3100, 0.06, 0.13, attack=0.002, release=0.12),
        click(0.006, 0.14, seed=37)),
    silence(0.02),
    mix(tone(2800, 0.06, 0.13, attack=0.002, release=0.12),
        click(0.006, 0.14, seed=38))))

write("metal_click", mix(
    click(0.03, 0.35, seed=39),
    tone(1000, 0.08, 0.18, attack=0.002, release=0.12)))

write("metal_drop", cat(
    mix(click(0.02, 0.35, seed=40),
        tone(700, 0.09, 0.20, attack=0.002, release=0.14)),
    silence(0.03),
    mix(click(0.015, 0.18, seed=41),
        tone(700, 0.06, 0.11, attack=0.002, release=0.10))))

write("switch_click", cat(
    click(0.01, 0.4, seed=42), silence(0.02), click(0.008, 0.3, seed=43)))

write("stone_drag", mix(
    burst(0.7, 0.28, seed=44, lp=0.04, a=0.55, r=0.25),
    tone(60, 0.7, 0.16, attack=0.5, release=0.25)))

_tv_n = int(SR * 0.45)
_tv_raw = noise(0.45, 0.22, seed=45, lp=0.0)
_tv_gain = [0.15 if (0.25 * _tv_n < i < 0.32 * _tv_n or
                     0.55 * _tv_n < i < 0.60 * _tv_n) else 1.0
            for i in range(_tv_n)]
tv_static_snd = mix([_tv_raw[i] * _tv_gain[i] for i in range(_tv_n)],
                    tone(7000, 0.45, 0.02, attack=0.1, release=0.5))
write("tv_static", fade_edges(tv_static_snd, 0.01))

fire_ignite_snd = burst(0.5, 0.22, seed=46, lp=0.28, a=0.45, r=0.35)
_fi_rnd = random.Random(47)
for _k in range(8):
    overlay(fire_ignite_snd,
            click(0.01, 0.10 + 0.10 * _fi_rnd.random(), seed=1000 + _k),
            0.26 + _fi_rnd.random() * 0.2)
write("fire_ignite", fire_ignite_snd)

write("organ_wrong", mix(
    tone(262, 0.5, 0.16, harmonics=ORGAN, attack=0.02, release=0.4),
    tone(277, 0.5, 0.16, harmonics=ORGAN, attack=0.02, release=0.4),
    tone(370, 0.5, 0.14, harmonics=ORGAN, attack=0.02, release=0.4)))

write("organ_chord", mix(
    tone(262, 1.2, 0.14, harmonics=ORGAN, attack=0.15, release=0.7),
    tone(330, 1.2, 0.14, harmonics=ORGAN, attack=0.15, release=0.7),
    tone(392, 1.2, 0.13, harmonics=ORGAN, attack=0.15, release=0.7),
    tone(523, 1.2, 0.12, harmonics=ORGAN, attack=0.15, release=0.7)))

# ── 방별 앰비언스 6종 (12초 루프, 아주 작게 ≤0.05) ──────────────────

DUR_AMB = 12.0

soft_tick = mix(click(0.006, 0.12, seed=60),
                tone(900, 0.03, 0.06, attack=0.002, release=0.08))

foyer_amb = wind_bed(DUR_AMB, 0.035, seed=70)
for _k in range(12):
    overlay(foyer_amb, soft_tick, 0.5 + _k * 1.0)
write("ambient_foyer", fade_edges(foyer_amb, 0.05))

living_amb = wind_bed(DUR_AMB, 0.035, seed=71)
_fc_rnd = random.Random(80)
for _i in range(10):
    t0 = 0.5 + _fc_rnd.random() * 11.0
    overlay(living_amb, click(0.012, 0.05 + 0.04 * _fc_rnd.random(), seed=200 + _i), t0)
write("ambient_living", fade_edges(living_amb, 0.05))

study_amb = wind_bed(DUR_AMB, 0.035, seed=72)
overlay(study_amb, [0.35 * v for v in wood_creak_open_snd], 3.0)
overlay(study_amb, [0.30 * v for v in wood_creak_open_snd], 8.2)
overlay(study_amb, [0.25 * v for v in paper_rustle_snd], 6.0)
write("ambient_study", fade_edges(study_amb, 0.05))

drip_kitchen = make_drip(900, 0.09, 3, seed=81)
kitchen_amb = wind_bed(DUR_AMB, 0.035, seed=73)
overlay(kitchen_amb, drip_kitchen, 2.5)
overlay(kitchen_amb, drip_kitchen, 9.0)
write("ambient_kitchen", fade_edges(kitchen_amb, 0.05))

drip_cellar = make_drip(850, 0.16, 5, seed=82)
cellar_wind = wind_bed(DUR_AMB, 0.030, seed=74, lp=0.025)
cellar_drone = [0.05 * math.sin(2 * math.pi * 55 * i / SR)
                * (0.7 + 0.3 * math.sin(2 * math.pi * 0.06 * i / SR))
                for i in range(int(SR * DUR_AMB))]
cellar_amb = mix(cellar_wind, cellar_drone)
overlay(cellar_amb, drip_cellar, 3.5)
overlay(cellar_amb, drip_cellar, 8.5)
write("ambient_cellar", fade_edges(cellar_amb, 0.05))

attic_amb = wind_bed(DUR_AMB, 0.05, seed=75)
overlay(attic_amb, [0.30 * v for v in wood_creak_open_snd], 2.0)
overlay(attic_amb, [0.28 * v for v in wood_creak_open_snd], 6.0)
overlay(attic_amb, [0.25 * v for v in wood_creak_open_snd], 10.0)
attic_whistle = [0.015 * math.sin(2 * math.pi * 1200 * i / SR
                                   + 0.6 * math.sin(2 * math.pi * 0.3 * i / SR))
                 for i in range(int(SR * DUR_AMB))]
attic_amb = mix(attic_amb, attic_whistle)
write("ambient_attic", fade_edges(attic_amb, 0.05))

print("완료:", OUT)
