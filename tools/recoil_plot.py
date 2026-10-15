"""後座力曲線圖：每把槍一列，左邊準心抬幾度、右邊槍模型上揚幾度。灰線＝改之前、紅線＝改之後。
資料來自 tools/recoil_trace.gd。
  python3 tools/recoil_plot.py before.json after.json out.png
"""
import json
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/STHeiti Medium.ttc"
W, H, PAD = 520, 200, 44
T_MAX = 0.6


def main(before_path, after_path, out_path):
    before = json.load(open(before_path))
    after = json.load(open(after_path))
    font = ImageFont.truetype(FONT, 16)
    small = ImageFont.truetype(FONT, 12)
    names = list(after)
    img = Image.new("RGB", (W * 2, H * len(names) + 30), "white")
    d = ImageDraw.Draw(img)
    d.text((10, 6), "灰＝改之前　紅＝改之後　橫軸 0～0.6 秒", fill="black", font=font)
    for row, name in enumerate(names):
        for col, (idx, label) in enumerate([(1, "準心抬起（度）"), (2, "槍模型上揚（度）")]):
            x0, y0 = col * W + PAD, 30 + row * H + 24
            w, h = W - PAD - 12, H - 24 - 20
            series = [s for s in (before.get(name), after[name]) if s]
            base = [s["rows"][0][2] if idx == 2 else 0.0 for s in series]
            top = max(max(r[idx] - b for r in s["rows"]) for s, b in zip(series, base)) * 1.15 or 1.0
            d.text((x0, y0 - 22), f"{name}　{label}", fill="black", font=font)
            d.rectangle([x0, y0, x0 + w, y0 + h], outline="#999")
            for k in range(1, 6):  # 每 0.1 秒一條格線
                gx = x0 + w * k / 6
                d.line([gx, y0, gx, y0 + h], fill="#eee")
                d.text((gx - 10, y0 + h + 2), f"{k / 10:.1f}", fill="#666", font=small)
            d.text((x0 - 40, y0 - 6), f"{top:.1f}", fill="#666", font=small)
            for s, b, color in zip(series, base, ["#aaa", "#d22"][-len(series):]):
                pts = [(x0 + w * r[0] / T_MAX, y0 + h - h * (r[idx] - b) / top) for r in s["rows"] if r[0] <= T_MAX]
                d.line(pts, fill=color, width=3)
    img.save(out_path)


if __name__ == "__main__":
    main(*sys.argv[1:4])
