"""재생 화면 묶음: <폴더>/NNN.png 를 6장씩 한 장으로, 단계 번호·탭한 핫스팟을 위에 적는다.
  python3 tool/art_check/play_sheet.py <폴더> build/play.json
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
d, pj = sys.argv[1], sys.argv[2]
steps = json.load(open(pj))
try:
    font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 15)
except Exception:
    font = ImageFont.load_default()
W, H = 300, 600
for k in range(0, len(steps), 6):
    grp = steps[k:k + 6]
    S = Image.new('RGB', (len(grp) * (W + 6), H + 24), (0, 0, 0))
    dr = ImageDraw.Draw(S)
    for i, st in enumerate(grp):
        p = f"{d}/{st['n']:03d}.png"
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert('RGB')
        im = im.resize((W, int(W * im.height / im.width)))
        S.paste(im.crop((0, 0, W, H)), (i * (W + 6), 24))
        dr.text((i * (W + 6) + 3, 3), f"{st['n']} {st['tapped']}", fill=(255, 220, 0), font=font)
    S.save(f"{d}/sheet{k // 6:02d}.jpg", quality=82)
print('묶음', (len(steps) + 5) // 6)
