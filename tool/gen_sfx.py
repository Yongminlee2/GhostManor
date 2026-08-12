# -*- coding: utf-8 -*-
"""절차 생성 효과음 13종 (플레이스홀더 — CC0 음원으로 교체 가능).
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

# BGM: 16초 루프 — 낮은 드론 + 드문 단조 아르페지오 (아주 작게)
rnd = random.Random(7)
N = SR * 16
drone = [0.05 * math.sin(2 * math.pi * 110 * i / SR)
         * (0.7 + 0.3 * math.sin(2 * math.pi * 0.125 * i / SR)) for i in range(N)]
bgm = drone
seq = [220, 262, 330, 262, 196, 262, 330, 392]
for k, f in enumerate(seq):
    start = int(k * 2 * SR)
    note = tone(f, 1.9, 0.055, harmonics=((1, 1.0), (2, 0.3)),
                attack=0.25, release=0.9)
    for i, v in enumerate(note):
        if start + i < N:
            bgm[start + i] += v
write("bgm_manor", bgm)

print("완료:", OUT)
