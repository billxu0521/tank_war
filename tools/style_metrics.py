"""美術風格的畫面量測：遊戲截圖跟參考圖比幾個「量得出來」的指標（美術風格指南第 7、8、10 節）。
門檻不是憑感覺訂的：同一套量法先量參考圖，截圖要達到參考圖的幾成才算過。檢驗流程見 docs/美術/美術風格檢驗.md。

  python3 tools/style_metrics.py <截圖資料夾或檔案...>
  python3 tools/style_metrics.py docs/image/style_iter/v3/        # style_shots.gd 拍的那組

指標（都在 CIE Lab 色彩空間算：L＝亮度 0～100，a＝綠↔紅，b＝藍↔黃）：
  暖冷   最亮 15% 的 b 減最暗 15% 的 b：受光偏橘黃、陰影偏紫藍，差越大越對（指南：暖主光＋冷暗部）
  對比   亮度第 95 和第 5 百分位的差：明暗分得開（指南：面要有清楚明暗）
  色盤   每個像素到指南色盤（14 色）最近一色的平均色差：越小越像同一套色盤
  飽和   平均彩度：太灰像沒調色、太艷像糖果
  純黑   亮度 < 6 的像素比例：陰影不要純黑（指南第 7 節）
  前景   畫面下三分之一的亮度減中間三分之一：負的＝前景比較暗（指南第 10 節：前景更暗、更高對比）
  碎度   細碎雜點對中尺度細節的比例（§14：不要因 Noise／Facet 過多產生視覺噪音）。在 640 寬量灰階：
         「原圖減輕微模糊」是 1～2 像素的雜點（草梗、碎石點），「輕微模糊減重模糊」是筆觸、面這種大一點的形狀。
         只看邊緣總量不行：參考圖細節比遊戲多，但都是成塊的面和筆觸；遊戲的問題是碎點，所以看比例
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter, ImageStat

REF = Path(__file__).resolve().parent.parent / 'docs/image/ChatGPT 圖像 2026年10月2日 上午12_41_33.png'
# 指南第 8 節色盤
PALETTE = ['F2A34A', 'FFD06A', '9A623B', 'B47743', '3A2925', '4A3428', '3C3945', '4C4650',
           '596044', '73704A', '554D46', '80705D', 'C65A35', 'D77A3A']
W, H = 192, 108   # 縮小再量：一張幾十毫秒，結果跟原尺寸差不到 1%


def lab(rgb):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(float(v)) for v in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


PAL_LAB = [lab(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))) for h in PALETTE]


def measure(path, crop_hud=True):
    img = Image.open(path).convert('RGB')
    w, h = img.size
    if crop_hud:   # 遊戲截圖：上面的方位條、下面的血條和說明字不算
        img = img.crop((0, int(h * 0.07), w, int(h * 0.88)))
    g = img.convert('L').resize((640, int(640 * img.size[1] / img.size[0])), Image.BILINEAR)
    b1, b5 = g.filter(ImageFilter.GaussianBlur(1.2)), g.filter(ImageFilter.GaussianBlur(5))
    grain = ImageStat.Stat(ImageChops.difference(g, b1)).mean[0] / max(ImageStat.Stat(ImageChops.difference(b1, b5)).mean[0], 0.01)
    img = img.resize((W, H), Image.BILINEAR)
    px = [lab(p) for p in getattr(img, "get_flattened_data", img.getdata)()]
    ls = sorted(p[0] for p in px)
    n = len(px)
    by_l = sorted(px, key=lambda p: p[0])
    k = max(1, int(n * 0.15))
    mean = lambda arr, i: sum(p[i] for p in arr) / len(arr)
    rows = [px[i * W:(i + 1) * W] for i in range(H)]
    third = lambda a, b: [p for r in rows[a:b] for p in r]
    return {
        '暖冷': mean(by_l[-k:], 2) - mean(by_l[:k], 2),
        '對比': ls[int(n * 0.95)] - ls[int(n * 0.05)],
        '色盤': sum(min(math.dist(p, q) for q in PAL_LAB) for p in px) / n,
        '飽和': sum(math.hypot(p[1], p[2]) for p in px) / n,
        '純黑': sum(1 for p in px if p[0] < 6) / n * 100,
        '前景': mean(third(H * 2 // 3, H), 0) - mean(third(H // 3, H * 2 // 3), 0),
        '碎度': grain,
    }


# 門檻：跟參考圖比。(說明, 判斷函式(截圖值, 參考值))
RULES = {
    '暖冷': ('≥ 參考的 6 成', lambda v, r: v >= r * 0.6),
    '對比': ('≥ 參考的 75%', lambda v, r: v >= r * 0.75),
    '色盤': ('≤ 參考的 1.3 倍', lambda v, r: v <= r * 1.3),
    '飽和': ('參考的 ±40%', lambda v, r: r * 0.6 <= v <= r * 1.4),
    '純黑': ('≤ 3%', lambda v, r: v <= 3.0),
    '前景': ('≤ 參考值 + 8', lambda v, r: v <= r + 8.0),
    '碎度': ('≤ 參考的 1.15 倍', lambda v, r: v <= r * 1.15),
}


def main(args):
    files = []
    for a in args:
        p = Path(a)
        files += sorted(p.glob('*.png')) if p.is_dir() else [p]
    if not files:
        print(__doc__)
        return 2
    ref = measure(REF, crop_hud=False)
    keys = list(RULES)
    print('%-22s' % '參考圖' + ''.join('%8s' % k for k in keys))
    print('%-22s' % '' + ''.join(('%9.2f' if k == '碎度' else '%9.1f') % ref[k] for k in keys))
    print('%-22s' % '門檻' + '  '.join(RULES[k][0] for k in keys))
    misses = {k: 0 for k in keys}
    for f in files:
        m = measure(f)
        cells = ''
        for k in keys:
            ok = RULES[k][1](m[k], ref[k])
            misses[k] += not ok
            cells += ('%8.2f%s' if k == '碎度' else '%8.1f%s') % (m[k], ' ' if ok else '✗')
        print('%-22s' % f.stem[:22] + cells)
    print('不合格張數：' + '、'.join('%s %d/%d' % (k, misses[k], len(files)) for k in keys))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
