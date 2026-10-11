# 尼諾拉：修腳的權重，匯出遊戲用的 models/ninola.glb
# 來源是核可的 01R2 v005 blend（只讀、不存回去），骨架、網格、材質都不動，只改兩腿踝以下的權重：
#   原本腳趾根上面的皮掛在小腿骨、三根腳趾的皮互相掛錯（外趾的骨頭管到中趾和內趾），
#   腳背一轉、腳趾一捲，皮就被扯開（tools/trex_skin_check.gd 量到走路時拉長 4.8 倍、壓到 0.11 倍）。
# 做法：踝以下的頂點照「離哪根骨頭最近」重算（距離的 4 次方反比，取最近 4 根），往上到小腿中段漸漸換回原本的權重。
# 匯出設定照 docs/image/modeling-tests/ninola-01S/2026-10-09-review-v001/export_clean.py
# 背景跑：Blender --background --factory-startup --python blender/ninola_weights.py -- --out models/ninola.glb
# ponytail: 距離權重是粗略的自動權重，關節附近夠用；要更細再到 Blender 手刷
import bpy, hashlib, os, sys
from mathutils.geometry import intersect_point_line

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, 'ninola', 'working', '01R2', '2026-10-09-v005', 'ninola_01R2_gold_slit_eye.blend')
SHA = '363eb15913ff2b7ee528a67163aa86805126e56a64514e07001cddc0ff305929'
OBJ = '01R2_Gold_Slit_Eye'
FULL, KEEP = 0.38, 0.50   # 高度（公尺）：這以下全用新權重，這以上全留原本的，中間漸變（踝關節在 0.40；帶子拉到 0.62 時踝上內側被壓到 0.12 倍）
POWER = 2   # 越小關節附近過渡越寬；4 的時候腳背和趾根交界沒有過渡，腳跟一抬皮被對摺（壓到 0.07 倍）

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
out = args[args.index('--out') + 1] if '--out' in args else None
redo = '--keep' not in args   # --keep：不改權重，只照原樣匯出（拿來確認匯出流程跟原本的一樣）

assert hashlib.sha256(open(SRC, 'rb').read()).hexdigest() == SHA, '來源 blend 不是核可版'
bpy.ops.wm.open_mainfile(filepath=SRC)
ob = bpy.data.objects[OBJ]
rig = bpy.data.objects['TrexRig']


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def seg_dist(p, h, t):
    _, f = intersect_point_line(p, h, t)
    f = min(max(f, 0.0), 1.0)
    return (p - (h + (t - h) * f)).length


if redo:
    vg = ob.vertex_groups
    changed = 0
    for side in ('l', 'r'):
        chain = ['shin', 'foot', 'dew'] + ['toe%d_%d' % (a, b) for a in (1, 2, 3) for b in (1, 2)]
        chain = [n + '_' + side for n in chain]
        segs = {n: (rig.matrix_world @ rig.data.bones[n].head_local, rig.matrix_world @ rig.data.bones[n].tail_local) for n in chain}
        for n in chain:
            if n not in vg:
                vg.new(name=n)
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            if (p.x > 0) != (side == 'l'):
                continue
            old = {vg[g.group].name: g.weight for g in v.groups if g.weight > 0}
            if sum(w for n, w in old.items() if n in chain) < 0.5:   # 不是小腿以下的皮（例如尾巴、肚子垂下來的地方）
                continue
            f = 1.0 - smooth(FULL, KEEP, p.z)
            if f <= 0:
                continue
            geo = {n: 1.0 / max(seg_dist(p, *segs[n]), 1e-4) ** POWER for n in chain}
            geo = dict(sorted(geo.items(), key=lambda x: -x[1])[:4])
            s = sum(geo.values())
            new = {n: (1 - f) * old.get(n, 0.0) for n in old}
            for n, w in geo.items():
                new[n] = new.get(n, 0.0) + f * w / s
            for n, w in new.items():
                if w < 0.01:
                    if n in old:
                        vg[n].remove([v.index])
                else:
                    vg[n].add([v.index], w, 'REPLACE')
            changed += 1
    print('reweighted verts', changed)

# 以下照 export_clean.py：網格掛到骨架下、拿掉骨頭的顯示形狀和其他物件，匯出
for o in bpy.context.scene.objects:
    o.select_set(False)
saved = ob.matrix_world.copy()
ob.parent = rig
ob.matrix_world = saved
for o in (ob, rig):
    o.hide_set(False)
    o.hide_viewport = False
    o.select_set(True)
bpy.context.view_layer.objects.active = ob
for b in rig.pose.bones:
    b.custom_shape = None
for o in list(bpy.data.objects):
    if o not in (ob, rig):
        bpy.data.objects.remove(o, do_unlink=True)
if out:
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(out), export_format='GLB', use_selection=True, export_animations=False,
                              export_skins=True, export_all_influences=True, export_yup=True)
    print('exported ->', out)
