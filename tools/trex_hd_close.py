"""精修暴龍的局部特寫（除錯用）：
Blender --background --factory-startup --python tools/trex_hd_close.py -- <x> <y> <z> <寬(單位)> <side|front|back|top|q> <輸出.png> [roar]
x y z 是 Godot 座標（特寫中心）"""
import bpy, sys, os
a = sys.argv[sys.argv.index('--') + 1:]
gx, gy, gz, size, view, out = float(a[0]), float(a[1]), float(a[2]), float(a[3]), a[4], a[5]
g = {'__name__': 'close', 'BASE': os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender')}
exec(open(g['BASE'] + '/trex_hd.py').read(), g)
obs = g['build']()
if len(a) > 6 and a[6] == 'roar':
    g['pose_roar'](next(o for o in obs if o.type == 'ARMATURE'))
g['setup_studio']()
rot = {'side': (90, 0, -90), 'front': (90, 0, 180), 'back': (90, 0, 0), 'top': (0, 0, -90), 'q': (70, 0, -130)}[view]
off = {'side': (-30, 0, 0), 'front': (0, 30, 0), 'back': (0, -30, 0), 'top': (0, 0, 30), 'q': (-23, 19, 10)}[view]
c = g['B']((gx, gy, gz))
g['_render'](out, rot, (c.x + off[0], c.y + off[1], c.z + off[2]), 900, 900, 900 / size)
