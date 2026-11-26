"""從 r013 原始 glTF 拆出紅框中的構件。參數為遊戲專案路徑。"""
import json
import struct
import sys
from collections import defaultdict
from pathlib import Path

project = Path(sys.argv[1])
scene = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": []}],
         "nodes": [], "meshes": [], "materials": [], "accessors": [], "bufferViews": []}
data = bytearray()


def source(path):
    raw = (project / path).read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    return json.loads(raw[20:20+length]), raw[28+length:]


def read_accessor(doc, raw, index):
    spec = doc["accessors"][index]
    view = doc["bufferViews"][spec["bufferView"]]
    form = struct.Struct("<" + {"SCALAR": "", "VEC3": "3", "VEC4": "4"}[spec["type"]]
                         + {5121: "B", 5123: "H", 5125: "I", 5126: "f"}[spec["componentType"]])
    start = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
    stride = view.get("byteStride", form.size)
    return [form.unpack_from(raw, start + j*stride) for j in range(spec["count"])], form


def write_accessor(rows, form, spec, bounds=False):
    data.extend(bytes(-len(data) % 4))
    view = len(scene["bufferViews"])
    scene["bufferViews"].append({"buffer": 0, "byteOffset": len(data), "byteLength": len(rows)*form.size})
    data.extend(b"".join(form.pack(*row) for row in rows))
    item = {k: spec[k] for k in ("type", "componentType", "normalized") if k in spec}
    item.update(bufferView=view, count=len(rows))
    if bounds:
        item.update(min=list(map(min, zip(*rows))), max=list(map(max, zip(*rows))))
    scene["accessors"].append(item)
    return len(scene["accessors"]) - 1


def components(positions, indices):
    parents = {}

    def root(point):
        while parents.setdefault(point, point) != point:
            point = parents[point]
        return point

    for i in range(0, len(indices), 3):
        a, b, c = [positions[k] for k in indices[i:i+3]]
        base = root(a)
        parents[root(b)] = parents[root(c)] = base
    groups = defaultdict(list)
    for k in indices:
        groups[root(positions[k])].append(k)
    return list(groups.values())


def extract(path, label):
    doc, raw = source(path)
    node = next(n for n in doc["nodes"] if n.get("name") == label)
    for prim in doc["meshes"][node["mesh"]]["primitives"]:
        mat = doc["materials"][prim["material"]]
        tool = label == "水尺與水車機座工具"
        if tool and mat["name"] not in ("作業物 · rope", "作業物 · cut"):
            continue
        if mat not in scene["materials"]:
            scene["materials"].append(mat)
        attrs = prim["attributes"]
        arrays = {key: read_accessor(doc, raw, attrs[key]) for key in attrs if key in ("POSITION","NORMAL","COLOR_0")}
        positions = arrays["POSITION"][0]
        indices = [r[0] for r in read_accessor(doc, raw, prim["indices"])[0]]
        groups = [indices] if tool and mat["name"].endswith("rope") else components(positions, indices)
        if not tool:
            assert len(groups) == {"StoneHeap": 52, "WheelSeat": 58}[label]
        for i, group in enumerate(groups):
            if label == "StoneHeap" and i == 0:
                continue  # 舊砂漿芯與所有砌石重疊，會填回缺口。
            name = ("Heap" if label == "StoneHeap" else "Seat") + f"{i:02}"
            if tool:
                name = "ToolRope" if mat["name"].endswith("rope") else f"ToolWedge{i}"
            unique = list(dict.fromkeys(group))
            lookup = {k: j for j, k in enumerate(unique)}
            center = [(min(v)+max(v))/2 for v in zip(*(positions[k] for k in unique))]
            part = {"attributes": {}, "material": scene["materials"].index(mat)}
            for key, (values, form) in arrays.items():
                rows = [values[k] for k in unique]
                if key == "POSITION":
                    rows = [tuple(x-y for x,y in zip(row,center)) for row in rows]
                part["attributes"][key] = write_accessor(rows,form,doc["accessors"][attrs[key]],key=="POSITION")
            part["indices"] = write_accessor([(lookup[k],) for k in group],struct.Struct("<H"),{"componentType":5123,"type":"SCALAR"})
            scene["scenes"][0]["nodes"].append(len(scene["nodes"]))
            scene["nodes"].append({"name":name,"translation":center,"mesh":len(scene["meshes"])})
            scene["meshes"].append({"name":name,"primitives":[part]})


for name in ("StoneHeap", "WheelSeat"):
    extract("levels/farm_style_buildings/farm_parts.glb", name)
extract("levels/farm_style/bridge_details.glb", "水尺與水車機座工具")
data.extend(bytes(-len(data) % 4))
scene["buffers"] = [{"byteLength":len(data)}]
header = json.dumps(scene,separators=(",",":")).encode()
header += b" " * (-len(header) % 4)
out = struct.pack("<4sIIII",b"glTF",2,28+len(header)+len(data),len(header),0x4e4f534a) + header
(project/"levels/farm_masonry/parts.glb").write_bytes(out + struct.pack("<II",len(data),0x004e4942) + data)
print(len(scene["nodes"]), "件")
