# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""場景的像素材質：叫 GPT 生西部風的像素圖，再加工成 16×16 的灰階無縫貼圖（一張鋪 1 公尺 = 16 格／公尺）。
貼圖只管明暗（跟材質原本的顏色相乘，見 main.gd 的 PIXEL_RULES、facet.gdshader 的 pixel_tex），物件的顏色不會被換掉。
  uv run tools/make_pixel_tex.py wood_h           # 生一種（沒有原圖才叫 GPT）
  uv run tools/make_pixel_tex.py all              # 全部
  REGEN=1 uv run tools/make_pixel_tex.py wood_h   # 重新叫 GPT 生原圖
原圖存 assets/textures/pixel/raw/（留著，改加工參數不用重新生），成品 assets/textures/pixel/<名字>.png。
API key 讀 ~/.config/openai/key。
"""
import base64, json, math, os, sys, urllib.request
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/textures/pixel"
RAW = OUT / "raw"
SIZE = 16          # 一張幾格（一張鋪 1 公尺）
LEVELS = 5         # 明暗分幾階
LO = 0.45          # 最暗那階（2026-10-09 使用者：像素風格強烈點，0.62 → 0.45）（白 = 原色）：太暗的話物件整體會被壓黑，顏色看不出來
MODEL = os.environ.get("IMAGE_MODEL", "gpt-image-1")

STYLE = ("seamless tileable pixel art texture, 16x16 pixel grid scaled up, flat orthographic top-down view of a surface, "
         "fills the entire square edge to edge, no border, no perspective, no objects, no shadows from outside, "
         "limited palette, crisp hard pixels, no anti-aliasing, wild west 1890s, retro game, no text, no labels, no frame")
# 名字 → (提示, 轉幾度[, {覆蓋 LEVELS／LO／MED}])：轉 90 是同一張的直條版
KINDS = {
    "wood_h": ("exactly 4 weathered horizontal wooden planks stacked, equal height, thin dark gap line between planks, wood grain and a few knots", 0),
    "wood_v": ("exactly 4 weathered horizontal wooden planks stacked, equal height, thin dark gap line between planks, wood grain and a few knots", 90),
    "bark":   ("rough tree bark and log surface, vertical fibrous grooves", 0, {"LEVELS": 3, "LO": 0.78}),   # 斜的樹枝每面投影方向不同，對比高會變迷彩格（第二輪審查）
    "stone":  ("rough stone wall, irregular fieldstones with mortar between them", 0),
    "roof":   ("wooden roof shingles, overlapping rows", 0),
    "hay":    ("dry hay straw, tangled stalks", 0),
    "metal":  ("rusty iron surface, rust blotches, scratches and pitting, no ridges, no rivets", 0),   # 波浪板鋪開像條碼
    # 房子外牆（橫板、直板共用一個材質，見 main.gd PIXEL_RULES）：不能有方向的紋路，只要舊木頭的斑駁
    "weathered": ("weathered old wood board surface seen up close, faint long vertical grain streaks, a few small knots and nail holes, low contrast, no plank seams", 0, {"LO": 0.6, "MED": 0.72}),   # 第三輪：沒方向的高對比方塊斑像磚、像花崗岩
    # 草（grass.gdshader 的草葉、flora 的草叢）：直的細葉一根根並排
    "blades": ("dry prairie grass blades close-up, many thin vertical blades side by side, some lighter tips", 0, {"LO": 0.6}),
    # 樹冠、灌木的芯（墊在葉片卡底下的暗色多面體）：貼一層葉叢的像素圖，近看露出來時是一團葉子、不是一顆平滑的方塊
    "foliage": ("dense mass of small leaves seen up close, leafy clusters, dark gaps between leaves", 0, {"LO": 0.55}),
    # 地面多幾種（2026-10-09，GPT 建議，docs/image/ground/gpt_suggestions.json）：terrain.gdshader 照每個頂點的權重疊上去
    "gravel": ("loose gravel and small pebbles on dry ground, many small stones, even coverage", 0, {"LO": 0.55}),
    "clay": ("cracked dry clay mud, polygon crack pattern, dry desert lakebed", 0, {"CELLS": 9}),   # 程式畫龜裂紋（GPT 圖縮到 16 格裂縫連不起來，變成棋盤，審查兩輪）
    "mud": ("damp dark soil with small puddles, footprints and leaf litter, forest floor", 0, {"LO": 0.72}),
    "outcrop": ("flat exposed bedrock with cracks and small rock chips, rocky ground seen from above", 0, {"CELLS": 4}),
    "plaster": ("old adobe plaster wall, small cracks and chips", 0),
    "grass":  ("dry prairie ground densely covered with short dry grass blades, dirt specks and pebbles, even coverage everywhere, no empty areas", 0, {"LO": 0.7, "MED": 0.72}),   # 第三輪：0.6 近看像棋盤   # 深色點太重像撒胡椒
    "dirt":   ("packed dry dirt road, small pebbles and fine cracks, even uniform coverage, no large patches or stripes", 0, {"LO": 0.7, "MED": 0.72}),
}


def generate(name: str, prompt: str) -> Path:
    raw = RAW / f"{name.split('_')[0] if name in ('wood_h', 'wood_v') else name}.png"
    if raw.exists() and not os.environ.get("REGEN"):
        return raw
    key = (Path.home() / ".config/openai/key").read_text().strip()
    body = json.dumps({"model": MODEL, "prompt": f"{prompt}. {STYLE}", "size": "1024x1024", "n": 1}).encode()
    req = urllib.request.Request("https://api.openai.com/v1/images/generations", body,
                                 {"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        data = json.load(r)["data"][0]
    img = base64.b64decode(data["b64_json"]) if "b64_json" in data else urllib.request.urlopen(data["url"]).read()
    RAW.mkdir(parents=True, exist_ok=True)
    raw.write_bytes(img)
    return raw


def seamless(im: Image.Image) -> Image.Image:
    """左右、上下接得起來：移半張，接縫跑到中間，再拿原圖蓋回去中間那塊（邊緣淡出）。
    ponytail: 簡單交叉淡化，縮到 16 格再分階之後看不出模糊；圖本身花紋太規則的話中間還是可能看到接痕"""
    w, h = im.size
    shifted = Image.new(im.mode, im.size)
    shifted.paste(im.crop((w // 2, h // 2, w, h)), (0, 0))
    shifted.paste(im.crop((0, h // 2, w // 2, h)), (w - w // 2, 0))
    shifted.paste(im.crop((w // 2, 0, w, h // 2)), (0, h - h // 2))
    shifted.paste(im.crop((0, 0, w // 2, h // 2)), (w - w // 2, h - h // 2))
    mask = Image.new("L", im.size)
    px = mask.load()
    for y in range(h):
        for x in range(w):
            d = min(x, w - 1 - x, y, h - 1 - y) / (min(w, h) * 0.25)
            px[x, y] = int(255 * min(1.0, d))
    return Image.composite(im, shifted, mask)


CROP = 0.04       # 四邊各切掉多少：GPT 常會畫一圈外框
DARK_Q = 0.3      # 縮到 16 格時每格取偏暗的值（第幾百分位）：取平均的話木板縫、石縫這種細線會被洗掉


def shrink(im: Image.Image, n: int) -> Image.Image:
    w, h = im.size
    px = im.load()
    out = Image.new("L", (n, n))
    for gy in range(n):
        for gx in range(n):
            vals = sorted(px[x, y] for y in range(gy * h // n, (gy + 1) * h // n) for x in range(gx * w // n, (gx + 1) * w // n))
            out.putpixel((gx, gy), vals[int(len(vals) * DARK_Q)])
    return out


MED = 0.55        # 中位數推到哪：越高，深色的格子越少（地面、外牆用高一點，深色點太多像雜訊）


def cells(n: int, seed: int, size: int = 32) -> Image.Image:
    """龜裂紋：環面上撒 n 個點分格（Voronoi，左右上下接得起來），格子交界畫 1 格寬的裂縫（0.6），格子裡 0.94～1。
    32×32 一張鋪 2 公尺（terrain.gdshader 乘 0.5），一樣是 16 格／公尺"""
    import random
    r = random.Random(seed)
    pts = [(r.uniform(0, size), r.uniform(0, size)) for _ in range(n)]
    def owner(x, y):
        best, bi = 1e9, 0
        for i, (px, py) in enumerate(pts):
            dx = min(abs(x - px), size - abs(x - px))
            dy = min(abs(y - py), size - abs(y - py))
            d = dx * dx + dy * dy
            if d < best:
                best, bi = d, i
        return bi
    own = [[owner(x + 0.5, y + 0.5) for x in range(size)] for y in range(size)]
    im = Image.new("L", (size, size))
    for y in range(size):
        for x in range(size):
            crack = own[y][x] != own[y][(x + 1) % size] or own[y][x] != own[(y + 1) % size][x]
            im.putpixel((x, y), round(255 * (0.6 if crack else r.choice((0.94, 0.97, 1.0, 1.0)))))
    return im


def lines(raw: Path, dark: float) -> Image.Image:
    """裂縫線模式（乾裂土、岩盤）：原圖最暗的一成多當裂縫（1 格寬、亮度 dark），其餘是亮的土塊（0.92～1，一點細雜點）"""
    im = ImageOps.grayscale(Image.open(raw).convert("RGB"))
    w, h = im.size
    im = im.crop((int(w * CROP), int(h * CROP), int(w * (1 - CROP)), int(h * (1 - CROP)))).resize((256, 256), Image.LANCZOS)
    im = shrink(im, SIZE)
    vals = sorted(im.get_flattened_data())
    cut = vals[int(len(vals) * 0.18)]
    mid = vals[len(vals) // 2]
    return im.point([round(255 * (dark if v <= cut else (0.92 if v < mid else 1.0))) for v in range(256)])


def process(raw: Path, rot: int, levels: int = LEVELS, lo: float = LO, med_to: float = MED) -> Image.Image:
    im = ImageOps.grayscale(Image.open(raw).convert("RGB"))
    w, h = im.size
    im = im.crop((int(w * CROP), int(h * CROP), int(w * (1 - CROP)), int(h * (1 - CROP)))).resize((256, 256), Image.LANCZOS)
    if os.environ.get("BLEND"):   # ponytail: 預設不做接縫淡化（會把木板線糊掉）；花紋不規則、接痕明顯的再開
        im = seamless(im)
    if rot:
        im = im.rotate(rot)
    im = shrink(im, SIZE)
    # 拉開對比，再把中位數推到中間：equalize 遇到幾乎一樣亮的圖（鐵、土）會整張變同一階；只 autocontrast 的話木紋大部分變最亮那階
    im = ImageOps.autocontrast(im, cutoff=3)
    med = sorted(im.get_flattened_data())[SIZE * SIZE // 2] / 255
    if 0.02 < med < 0.98:
        g = math.log(med_to) / math.log(med)
        im = im.point([round(255 * (v / 255) ** g) for v in range(256)])
    # 分 LEVELS 階，映到 LO～1（白 = 原色）
    lut = [round((lo + (1 - lo) * min(levels - 1, v * levels // 256) / (levels - 1)) * 255) for v in range(256)]
    return im.point(lut)


def main() -> None:
    names = list(KINDS) if sys.argv[1:] == ["all"] else sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    for n in names:
        prompt, rot, *opt = KINDS[n]
        o = opt[0] if opt else {}
        img = cells(o["CELLS"], hash(n) % 1000 + 7) if "CELLS" in o else lines(generate(n, prompt), o["LINES"]) if "LINES" in o else \
            process(generate(n, prompt), rot, o.get("LEVELS", LEVELS), o.get("LO", LO), o.get("MED", MED))
        img.save(OUT / f"{n}.png")
        mean = sum(img.get_flattened_data()) / (img.size[0] * img.size[1]) / 255
        print(f"{n}: 平均亮度 {mean:.2f} → {OUT / (n + '.png')}")


if __name__ == "__main__":
    main()
