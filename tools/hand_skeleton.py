# /// script
# requires-python = ">=3.10,<3.13"
# dependencies = ["mediapipe", "opencv-python"]
# ///
"""抓圖片裡手的骨架（每隻手 21 個點），畫成疊圖＋輸出 json。
  uv run tools/hand_skeleton.py 圖片.png
  uv run tools/hand_skeleton.py --grid 2x3 圖片.png   # 多格拼圖：切成 2 列 3 欄一格一格抓（整張丟會漏）
  uv run tools/hand_skeleton.py 影片.mov                # 影片：每秒抽 10 格、前後格追蹤
輸出：圖片_skel.png（影片是 _skel.mp4）、_skel.json：
  joints = 像素座標 x, y（z 是相對手腕的深度，越負越靠鏡頭）
  dirs   = 每節骨頭的方向（手自己的座標，左手已鏡射成右手），給 blender/hand_check.py 擺 rig、比對用
  arm    = 前臂（手腕、往手肘方向的末端，像素）：膚色區塊估的，畫面上是白色粗線
"""
import json, sys, urllib.request
from pathlib import Path

import cv2
import mediapipe as mp
from mediapipe.tasks.python import vision, BaseOptions

MODEL = Path(__file__).with_name("hand_landmarker.task")
MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task"

# mediapipe 的 21 點順序，名字對齊 blender/hands.py 骨架（rig_points）：每個點 = 那節骨頭的頭，_tip = 指尖。
# 拇指的 Proximal 是掌骨那節（從手腕旁邊的 CMC 關節長出去），跟 rig 一樣
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")
SEGS = ("_Proximal", "_Intermediate", "_Distal")
NAMES = ["Hand"] + [f + s for f in FINGERS for s in SEGS + ("_tip",)]
BONES = [(0, 1), (0, 5), (5, 9), (9, 13), (13, 17), (0, 17)] + \
        [(b + i, b + i + 1) for b in (1, 5, 9, 13, 17) for i in range(3)]
COLORS = [(255, 255, 255), (0, 128, 255), (0, 255, 0), (255, 255, 0), (255, 0, 255), (0, 0, 255)]  # 掌、拇、食、中、無名、小


VIDEO_FPS = 10  # ponytail: 固定每秒 10 格，要抓快動作再調高


def make_detector(video: bool):
    if not MODEL.exists():
        urllib.request.urlretrieve(MODEL_URL, MODEL)
    # ponytail: 門檻全壓到 0.1——遊戲畫面的手常被畫面邊緣切掉，預設 0.5 會漏掉大半
    return vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(MODEL)), num_hands=2,
        min_hand_detection_confidence=0.1, min_hand_presence_confidence=0.1, min_tracking_confidence=0.1,
        running_mode=vision.RunningMode.VIDEO if video else vision.RunningMode.IMAGE))


def _sub(a, b): return [x - y for x, y in zip(a, b)]
def _dot(a, b): return sum(x * y for x, y in zip(a, b))
def _cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def _unit(a):
    n = _dot(a, a) ** 0.5 or 1.0
    return [x / n for x in a]


def bone_dirs(world: list) -> tuple[dict, bool]:
    """3D 關節（公尺）→ 每節骨頭的方向，用手自己的座標（前 = 手腕到四指根、側 = 往食指、法線 = 手背），
    跟 blender/hand_views.hand_frame 同一套，格式同 docs/image/hand_pose_grip.json，pose_ref 可以直接吃。
    左手鏡射成右手（rig 只有右手，左手是烘的時候鏡射）。回傳 (方向表, 是不是左手)"""
    P = dict(zip(NAMES, world))
    knuckles = [sum(P[f + "_Proximal"][i] for f in FINGERS[1:]) / 4 for i in range(3)]
    fwd = _unit(_sub(knuckles, P["Hand"]))
    side = _sub(P["Index_Proximal"], P["Little_Proximal"])
    side = _unit(_sub(side, [x * _dot(side, fwd) for x in fwd]))
    normal = _unit(_cross(fwd, side))   # 右手：手背；左手：掌心
    # 分左右手看手指往哪邊彎（一定往掌心）。mediapipe 的左右標籤假設畫面是自拍鏡像，遊戲畫面不能信
    curl = sum(_dot(_sub(P[f + "_tip"], P[f + "_Proximal"]), normal) for f in FINGERS[1:])
    left = curl > 0  # ponytail: 手指幾乎全直時分不出來，會當成右手
    dirs = {}
    for f in FINGERS:
        names = [f + s for s in SEGS] + [f + "_tip"]
        for a, b in zip(names, names[1:]):
            d = _sub(P[b], P[a])
            dirs[a] = [round(_dot(d, fwd), 4), round(_dot(d, side), 4), round(_dot(d, normal) * (-1 if left else 1), 4)]
            n = (sum(x * x for x in dirs[a]) ** 0.5) or 1.0
            dirs[a] = [round(x / n, 4) for x in dirs[a]]
    return dirs, left


def forearm(src, pts):
    """前臂：mediapipe 只有手（身體姿勢模型在第一人稱畫面認不出人），用膚色找。
    手掌幾個點取顏色 → 連著手腕的同色區塊 → 手腕往手指反方向、離手腕 0.3～3 個手長的那些點 → 主方向。
    回傳 (手腕, 前臂末端) 像素座標；找不到回傳 None。ponytail: 膚色門檻寫死，袖子、背景顏色太像皮膚會抓歪"""
    import numpy as np
    hsv = cv2.cvtColor(src, cv2.COLOR_BGR2HSV)
    h, w = src.shape[:2]
    wrist, mcp = np.array(pts[0][:2]), np.array(pts[9][:2])
    L = np.linalg.norm(wrist - mcp)
    if L < 5:
        return None
    samp = np.array([hsv[int(min(h - 1, max(0, pts[i][1]))), int(min(w - 1, max(0, pts[i][0])))] for i in (0, 1, 5, 9, 13, 17)], float)
    lo = np.clip(np.median(samp, 0) - (12, 70, 80), 0, 255).astype(np.uint8)
    hi = np.clip(np.median(samp, 0) + (12, 70, 80), 0, 255).astype(np.uint8)
    mask = cv2.inRange(hsv, lo, hi)
    n, lab = cv2.connectedComponents(mask)
    wx, wy = int(min(w - 1, max(0, wrist[0]))), int(min(h - 1, max(0, wrist[1])))
    k = lab[wy, wx]
    if k == 0:   # 手腕那一點剛好不是膚色：取周圍最多的區塊
        win = lab[max(0, wy - 8):wy + 9, max(0, wx - 8):wx + 9].ravel()
        win = win[win > 0]
        if not len(win):
            return None
        k = np.bincount(win).argmax()
    ys, xs = np.nonzero(lab == k)
    P = np.stack([xs, ys], 1).astype(float)
    u = (wrist - mcp) / L
    t = (P - wrist) @ u
    sel = P[(t > 0.3 * L) & (t < 3 * L)]
    if len(sel) < 50:
        return None
    c = sel.mean(0)
    _, _, vt = np.linalg.svd(sel - c, full_matrices=False)
    d = vt[0] if vt[0] @ u > 0 else -vt[0]
    end = wrist + d * min(3 * L, ((sel - wrist) @ d).max())
    return wrist, end


def collect(img, res, x0=0, y0=0, tw=None, th=None, **extra) -> list:
    """把偵測結果畫到 img 上，回傳每隻手的關節表。x0/y0/tw/th = 這次偵測的那塊區域。"""
    h, w = img.shape[:2]
    tw, th = tw or w, th or h
    src = img.copy()   # 找前臂要用沒畫線的原圖
    hands = []
    for lms, wl, side in zip(res.hand_landmarks, res.hand_world_landmarks, res.handedness):
        pts = [(x0 + p.x * tw, y0 + p.y * th, p.z * tw) for p in lms]
        dirs, left = bone_dirs([(p.x, p.y, p.z) for p in wl])
        arm = forearm(src, pts)
        hands.append({**extra, "left": left, "score": round(side[0].score, 3),
                      "joints": {n: [round(v, 1) for v in p] for n, p in zip(NAMES, pts)}, "dirs": dirs,
                      "arm": [[round(float(v), 1) for v in q] for q in arm] if arm else None})
        if arm:   # 前臂：白色粗線＋末端一個圈（大概的手肘方向）
            a0, a1 = tuple(map(int, arm[0])), tuple(map(int, arm[1]))
            cv2.line(img, a0, a1, (255, 255, 255), max(4, w // 160))
            cv2.circle(img, a1, max(6, w // 120), (255, 255, 255), 2)
        for a, b in BONES:
            c = COLORS[0] if b in (5, 9, 13, 17) and a != b - 1 else COLORS[1 + (b - 1) // 4]
            cv2.line(img, tuple(map(int, pts[a][:2])), tuple(map(int, pts[b][:2])), c, max(2, w // 300))
        for x, y, _ in pts:
            cv2.circle(img, (int(x), int(y)), max(3, w // 200), (0, 0, 0), -1)
    return hands


def to_mp(bgr):
    return mp.Image(image_format=mp.ImageFormat.SRGB, data=cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))


def run_image(path: str, rows: int, cols: int) -> None:
    det = make_detector(False)
    img = cv2.imread(path)
    h, w = img.shape[:2]
    hands = []
    for i in range(rows * cols):
        y0, x0 = i // cols * h // rows, i % cols * w // cols
        y1, x1 = (i // cols + 1) * h // rows, (i % cols + 1) * w // cols
        res = det.detect(to_mp(img[y0:y1, x0:x1].copy()))
        hands += collect(img, res, x0, y0, x1 - x0, y1 - y0, panel=i)
    stem = Path(path).with_suffix("")
    cv2.imwrite(f"{stem}_skel.png", img)
    Path(f"{stem}_skel.json").write_text(json.dumps(hands, ensure_ascii=False, indent=1))
    print(f"抓到 {len(hands)} 隻手 → {stem}_skel.png")


def run_video(path: str) -> None:
    det = make_detector(True)
    cap = cv2.VideoCapture(path)
    step = max(1, round(cap.get(cv2.CAP_PROP_FPS) / VIDEO_FPS))
    stem = Path(path).with_suffix("")
    out, frames, i = None, [], 0
    while True:
        ok, img = cap.read()
        if not ok:
            break
        if i % step == 0:
            t = i / cap.get(cv2.CAP_PROP_FPS)
            hands = collect(img, det.detect_for_video(to_mp(img), int(t * 1000)))
            frames.append({"frame": i, "time": round(t, 2), "hands": hands})
            if out is None:
                out = cv2.VideoWriter(f"{stem}_skel.mp4", cv2.VideoWriter_fourcc(*"mp4v"), VIDEO_FPS, img.shape[1::-1])
            out.write(img)
        i += 1
    out.release()
    Path(f"{stem}_skel.json").write_text(json.dumps(frames, ensure_ascii=False))
    hit = sum(bool(f["hands"]) for f in frames)
    print(f"{len(frames)} 格裡 {hit} 格有抓到手 → {stem}_skel.mp4")


if __name__ == "__main__":
    args = sys.argv[1:]
    r = c = 1
    if args and args[0] == "--grid":
        r, c = map(int, args[1].lower().split("x"))
        args = args[2:]
    for p in args:
        if Path(p).suffix.lower() in (".mov", ".mp4", ".avi", ".mkv", ".webm"):
            run_video(p)
        else:
            run_image(p, r, c)
