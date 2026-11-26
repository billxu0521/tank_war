"""Blender 背景模式。將 r009 原網格按實物分件，另製一組成脊散草垛。"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
sys.path.insert(0, str(Path(__file__).parent))
from source_meshes import read_parts

project, out = map(Path, sys.argv[sys.argv.index("--")+1:])
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
paint = bpy.data.materials.new("FarmMatte")
paint.use_nodes = True
shader = paint.node_tree.nodes.get("Principled BSDF")
shader.inputs["Roughness"].default_value = .87
attr = paint.node_tree.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "FarmPaint"
paint.node_tree.links.new(attr.outputs["Color"], shader.inputs["Base Color"])
library = {}
recipes = {}
palette = dict(h_log0="b58756", h_log1="785138", h_log2="caa06d", c_log_end="d6ad7c",
               h_iron="414744",h_post="48685a",wood="b58756",wood2="caa06d",cut="d6ad7c",oak="b58756",
               iron="414744",heart="785138")
def linear(hexcode):
    x = np.array([int(hexcode[i:i+2],16)/255 for i in (0,2,4)])
    return np.r_[np.where(x<.04045,x/12.92,((x+.055)/1.055)**2.4),1]
def register(recipe, pieces, seats=(), convex=False):
    verts = np.concatenate([p["vertices"] for p in pieces]).astype(float)
    colors = []
    faces = []
    offset = 0
    for item in pieces:
        faces.extend(tuple(int(k)+offset for k in f) for f in item["faces"])
        offset += len(item["vertices"])
        c = item["colors"]
        if item["mat"] in palette:
            c = np.tile(linear(palette[item["mat"]]),(len(c),1))
        colors.extend(np.c_[c,np.ones(len(c))] if c.shape[1]==3 else c)
    center = (verts.min(0)+verts.max(0))*.5
    verts -= center
    key = (verts.round(4).tobytes(), tuple(faces), np.round(colors,4).tobytes())
    if key not in library:
        name = "Part%03d" % len(library)
        m = bpy.data.meshes.new(name)
        m.from_pydata([(float(x),float(-z),float(y)) for x,y,z in verts],[],faces)
        m.materials.append(paint)
        a = m.color_attributes.new(name="FarmPaint",type="FLOAT_COLOR",domain="POINT")
        a.data.foreach_set("color",np.array(colors,dtype=np.float32).ravel())
        obj = bpy.data.objects.new(name,m)
        bpy.context.scene.collection.objects.link(obj)
        library[key] = name
    recipe.append(dict(m=library[key],p=center.round(6).tolist(),seats=seats,convex=convex))
    return len(recipe)-1

def wood(name,parts):
    recipe = recipes[name] = []
    rows = {}
    for p in parts:
        if p["size"][1] > 1: continue   # r009 只為填滿灰盒留下的整塊暗芯
        rows.setdefault(round(float(p["center"][1]),2),[]).append(p)
    last = []
    for level in sorted(rows):
        row = rows[level]
        narrow_x = row[0]["size"][0] < row[0]["size"][2]
        current = []
        for p in sorted(row,key=lambda q: tuple(q["center"])):
            seats = []
            if last:
                # 夾棍橫跨數塊板，尚有左右兩半的支承即可。長板需兩端墊木。
                if narrow_x:
                    seats = [[i for i,q in last if q["center"][2]*side >= -.01] for side in [-1,1]]
                else:
                    seats = [[i] for i,q in last]
            current.append((register(recipe,[p],seats),p))
        last = current

style = "levels/farm_style_buildings/farm_parts.glb"
for name in ("YardStack","TeamStock","ApproachStock","NorthStock"):
    wood(name,read_parts(project,style,name))
parts = read_parts(project,style,"StoredFeed")
cores = [p for p in parts if p["size"][0]>.5]
ties = [p for p in parts if p["size"][0]<.1]
recipe = recipes["StoredFeed"] = []
for x in (-2.5,-1.5,-.5,.5,1.5,2.5):
    for z in (-1,0,1):
        last = None
        for layer in range(4):
            center = np.array([x,.3+.6*layer,z])
            p = min(cores,key=lambda a: np.linalg.norm(a["center"]-center))
            # 舊殼未做的中間捆用同尺寸相鄰原捆補實，外捆移走才會露出。
            strap = [s for s in ties if np.linalg.norm(s["center"]-p["center"])<.31]
            assert len(strap)==2
            items = [dict(i,vertices=i["vertices"]+center-p["center"]) for i in [p,*strap]]
            last = register(recipe,items,[] if last is None else [[last]])

parts = read_parts(project,style,"FarmCrates")
cores = [p for p in parts if .85<p["size"][0]<.95 and .85<p["size"][2]<.95]
assert len(cores)==62
buckets = [[] for _ in cores]
for p in parts:
    ix = min(range(len(cores)),key=lambda j:np.linalg.norm(cores[j]["center"]-p["center"]))
    buckets[ix].append(p)
assert all(len(items)==13 for items in buckets)
recipe = recipes["FarmCrates"] = []
for x in (-1.5,-.5,.5,1.5):
    for z in (-2,-1,0,1,2):
        last = None
        for tier in range(4):
            at = np.array([x,(tier+.5)*2.3/4,z])
            ix = min(range(len(cores)),key=lambda j:np.linalg.norm(cores[j]["center"]-at))
            pieces = [dict(p,vertices=p["vertices"]+at-cores[ix]["center"]) for p in buckets[ix]]
            last = register(recipe,pieces,[] if last is None else [[last]])

parts = read_parts(project,"models/clutters.glb","LogPile")
logs = sorted([p for p in parts if p["size"][2]>1],key=lambda p:(round(p["center"][1],1),p["center"][0]))
recipe = recipes["LogPile"] = []
for i,p in enumerate(logs):
    caps = [q for q in parts if q["mat"]=="c_log_end" and np.linalg.norm((q["center"]-p["center"])[:2])<.06]
    assert len(caps)==2
    seats = {3:[[0],[1]],4:[[1],[2]],5:[[3],[4]]}.get(i,[])
    register(recipe,[p,*caps],seats,True)
stump = [p for p in parts if p["center"][0]>1 and p["mat"] not in ("h_post","h_iron")]
register(recipe,stump,convex=True)
register(recipe,[p for p in parts if p["mat"] in ("h_post","h_iron")],[[6]],True)

rackfile = "models/farm_canal_works/UnloadingRack.glb"
parts = read_parts(project,rackfile,"Trestles-col")
recipe = recipes["RailRack"] = []
frames=[]
for z in (-2.82,-1.10,.62,2.12):
    items = [p for p in parts if abs(p["center"][2]-z)<.01]
    assert len(items)==4
    frames.append(register(recipe,items))
    # 每腳、叉撐與橫頭各有實體，保留腳間可穿視的空隙。
    origin=np.array(recipe[-1]["p"])
    recipe[-1]["hulls"]=[np.unique(np.round(p["vertices"]-origin,5),axis=0).tolist() for p in items]
for p in parts:
    if p["size"][2]>5:
        register(recipe,[p],[[0,1],[2,3]])
for z,i in ((-1.8,1),(1.45,2)):
    register(recipe,[p for p in parts if abs(p["center"][2]-z)<.01],[[i]])
bed=[i for i,q in enumerate(recipe) if 1.30<q['p'][1]<1.37]
assert len(bed)==4
boards = read_parts(project,rackfile,"Stock-col")
for x in [1.39,1.66]:
    last = min(bed,key=lambda i: abs(recipe[i]['p'][0]-x))
    for p in sorted([p for p in boards if abs(p["center"][0]-x)<.02],key=lambda p:p["center"][1]):
        last = register(recipe,[p],[[last]])
# 成脊散草垛。剖面以高度分三層。草梢順坡朝下，立面留叉取後的小缺口。
recipe = recipes["LooseStack"] = []
rng = np.random.default_rng(1926)
rings=[(.009,.461,.459),(.16,.487,.492),(.46,.444,.468),(.74,.317,.434),(.92,.175,.384),(.991,.039,.284)]
def point(t, row):
    h,rx,rz=rings[row]
    u,v=math.cos(t),math.sin(t)
    def rounded(a): return math.copysign(abs(a)**.70,a)
    skirt = .043*math.sin(3*t+.5)+.024*math.cos(5*t-.2)
    return np.array([rounded(u)*rx*(1+.039*math.sin(3*t+row*.24))+.051*h,
                     h + (skirt if 0<row<5 else 0) - .052*h*abs(v)**4,
                     rounded(v)*rz*(1+.026*math.cos(5*t-.5))-.032*h])
for layer,(low,high) in enumerate([(0,2),(2,3),(3,5)]):
    for half in range(1 if layer==2 else 2):
        angles=np.linspace(half*math.pi, (half+1)*math.pi if layer<2 else 2*math.pi,9 if layer<2 else 17)
        vv=[]; ff=[]; cc=[]
        def face(v,col):
            n=len(vv);vv.extend(v);ff.append(tuple(range(n,n+len(v))));cc.extend([linear(col)]*len(v))
        shades=['ac863e','c29b50','ccaa65','bb9651','d2b168']
        for h in range(low,high):
            for a,b in zip(angles,angles[1:]):
                quad=[point(a,h),point(b,h),point(b,h+1),point(a,h+1)]
                face(quad[::-1],shades[int(rng.integers(0,4))])
                for j in range(3):
                    u=(j+.31+rng.uniform(-.10,.18))/3
                    v=.14+rng.uniform(-.10,.19)
                    aa,bb,bc,ac=quad
                    q=(1-v)*((1-u)*aa+u*bb)+v*((1-u)*ac+u*bc)
                    thatch=(ac-aa)*rng.uniform(.42,.78)+(bb-aa)*rng.uniform(-.17,.09)
                    outward=np.array([math.cos((a+b)/2),.12,math.sin((a+b)/2)])*.012
                    width=(bb-aa)*rng.uniform(.11,.20)
                    # 草梢往下垂，由窄尖端伸出坡面；上端仍藏在同一束裡。
                    face([q+outward*1.7,q+thatch+outward,q+thatch+width+outward],shades[int(rng.integers(1,5))])
        if layer<2:
            face([point(angles[0],low),point(angles[-1],low),point(angles[-1],high),point(angles[0],high)],'b08c46')
        face([point(t,high) for t in angles[::-1]],'c6a35e')
        face([point(t,low) for t in angles],'ae8844')
        p=dict(vertices=np.array(vv),faces=ff,colors=np.array(cc),mat="Loose")
        register(recipe,[p], [] if layer==0 else ([[half]] if layer==1 else [[2,3]]),True)
out.joinpath("recipes.json").write_text(json.dumps(recipes,separators=(',',':'))+"\n")
bpy.ops.export_scene.gltf(filepath=str(out/"parts.glb"),export_format="GLB",export_yup=True,
                          export_extras=False,export_animations=False)
print("已封裝", {k:len(v) for k,v in recipes.items()}, "共用網格",len(library))
