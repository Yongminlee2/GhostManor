"""remaster.py 가 남긴 build/art_fix_rects.json 의 비율 좌표를 방 코드의 덧그림 area 에 옮긴다.
`image: 'assets/scenes/<이름>',` 바로 다음 줄의 `area: ...,` 만 바꾼다(핫스팟은 건드리지 않는다).
  python3 tool/art_fix/apply_rects.py
"""
import glob, json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
rects = json.load(open(os.path.join(ROOT, 'build', os.environ.get('RECTS', 'art_fix_rects.json'))))
for path in glob.glob(os.path.join(ROOT, 'lib', 'rooms', '*.dart')):
    s = open(path).read()
    orig = s
    for name, r in rects.items():
        if name.startswith('obj:'):  # 움직이는 스프라이트 — 방 코드에 손으로 옮겼다
            continue
        x, y, w, h = r
        pat = re.compile(r"(image: 'assets/scenes/" + re.escape(name) + r"',\n\s*area: )([^\n]*?),\n")
        s = pat.sub(lambda m: f"{m.group(1)}const Rect.fromLTWH({x}, {y}, {w}, {h}),\n", s)
    if s != orig:
        open(path, 'w').write(s)
        print('고침', os.path.relpath(path, ROOT))
