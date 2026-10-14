"""아트 정합 점검: scene_dump.json 을 읽어 벽면마다 [배경 | 덧그림 모두 겹침 | 핫스팟]
세 칸짜리 그림을 만든다. 덧그림이 자기 칸에 들어갈 때 얼마나 늘어나는지(가로세로 비)도 적는다.
  python3 tool/art_check/render.py build/scene_dump.json <출력 폴더>
"""
import json, os, sys
from PIL import Image, ImageDraw

dump, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
W, H = 512, 768  # 화면 칸 2:3

def load(p):
    return Image.open(p).convert('RGBA') if p and os.path.exists(p) else None

def place(canvas, img, area, w, h):
    x, y, aw, ah = area
    box = (round(x * w), round(y * h), max(1, round(aw * w)), max(1, round(ah * h)))
    canvas.alpha_composite(img.resize(box[2:]), box[:2])
    return box

report = []
for sc in json.load(open(dump)):
    if sc['custom'] or not sc['image']:
        continue
    bg = load(sc['image'])
    base = bg.resize((W, H))
    full = base.copy()
    d = ImageDraw.Draw(full)
    layers = [('obj', o) for o in sc['objects']] + [('ov', o) for o in sc['overlays']] + [('idle', o) for o in sc['idles']]
    for kind, o in layers:
        im = load(o['image'])
        if im is None:
            report.append(f"{sc['id']}: 없음 {o['image']}")
            continue
        box = place(full, im, o['area'], W, H)
        # 늘어남: 칸의 가로세로 비 / 그림의 가로세로 비 (실제 화면은 2:3 칸)
        stretch = (box[2] / box[3]) / (im.width / im.height)
        opaque = im.getchannel('A').getextrema()[0] == 255
        report.append(f"{sc['id']}: {kind} {os.path.basename(o['image'])} 늘어남 {stretch:.2f}{' 불투명' if opaque else ''}")
        d.rectangle([box[0], box[1], box[0] + box[2], box[1] + box[3]], outline=(0, 255, 255), width=1)
    hs = base.copy()
    d2 = ImageDraw.Draw(hs)
    for h in sc['hotspots']:
        x, y, aw, ah = h['area']
        d2.rectangle([x * W, y * H, (x + aw) * W, (y + ah) * H], outline=(255, 60, 60), width=2)
        d2.text((x * W + 3, y * H + 2), h['id'], fill=(255, 255, 0))
    sheet = Image.new('RGBA', (W * 3 + 20, H + 24), (30, 30, 30, 255))
    ImageDraw.Draw(sheet).text((4, 4), f"{sc['room']} / {sc['id']} ({sc['kind']}) {os.path.basename(sc['image'])} {bg.size}", fill=(255, 255, 255))
    for i, im in enumerate([base, full, hs]):
        sheet.alpha_composite(im, (i * (W + 10), 24))
    sheet.convert('RGB').save(f"{out}/{sc['room']}_{sc['id']}.jpg", quality=82)
open(f"{out}/report.txt", 'w').write('\n'.join(report))
print('\n'.join(report))
