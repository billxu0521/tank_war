"""讀取 r009 的靜態 glTF 三角面，按共位置的頂點找回合批前的零件。"""
import json
import struct
from pathlib import Path

import numpy as np


def read_parts(project, relpath, label):
    raw = (Path(project) / relpath).read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    buf = raw[28 + length:]
    def accessor(idx):
        acc = doc["accessors"][idx]
        view = doc["bufferViews"][acc["bufferView"]]
        dt = np.dtype({5126:"<f4",5125:"<u4",5123:"<u2",5121:"u1"}[acc["componentType"]])
        width = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[acc["type"]]
        arr = np.ndarray((acc["count"],width),dtype=dt,buffer=buf,
                         offset=view.get("byteOffset",0)+acc.get("byteOffset",0),
                         strides=(view.get("byteStride",dt.itemsize*width),dt.itemsize))
        return arr.astype(float) / np.iinfo(dt).max if acc.get("normalized") else arr
    node = next(n for n in doc["nodes"] if n["name"]==label)
    parts = []
    for prim in doc["meshes"][node["mesh"]]["primitives"]:
        attr = prim["attributes"]
        pos = accessor(attr["POSITION"])
        faces = accessor(prim["indices"]).reshape((-1,3))
        material = doc["materials"][prim["material"]]
        base = material.get("pbrMetallicRoughness",{}).get("baseColorFactor",[1,1,1,1])
        colors = accessor(attr["COLOR_0"]) if "COLOR_0" in attr else np.broadcast_to(base,(len(pos),4))
        owners = {}
        parents = list(range(len(faces)))
        def root(index):
            while parents[index]!=index:
                index, parents[index] = parents[index], parents[parents[index]]
            return index
        for i,face in enumerate(faces):
            for vi in face:
                point = tuple(np.round(pos[vi],5))
                if point in owners:
                    parents[root(i)] = root(owners[point])
                else:
                    owners[point] = i
        sets = {}
        for i in range(len(faces)):
            sets.setdefault(root(i),[]).append(i)
        for ids in sets.values():
            used, compact = np.unique(faces[ids],return_inverse=True)
            points = pos[used]
            parts.append(dict(vertices=points,faces=compact.reshape(-1,3),colors=colors[used],
                              mat=material["name"],center=(points.max(0)+points.min(0))/2,
                              size=np.ptp(points,axis=0)))
    return parts
