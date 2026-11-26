"""Blender 背景重製可動角色。只衍生 GLB 的表面，節點、骨架、逆綁定與動畫沿用來源。"""
import json
import struct
import sys
from collections import defaultdict
from pathlib import Path
from math import cos, sin, tau

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "style_block"))
from actors import PALETTE, _rgb

EXTRA = {"c_metal":"steel", "c_vest":"c_leather", "c_band":"c_scarf", "c_eye":"pupil",
         "steel_dark":"gunmetal", "blued":"gunmetal", "bore":"socket", "wood":"grip",
         "wood_red":"grip", "wood2":"c_hat", "hull":"c_scarf", "hull2":"c_duster",
         "lance_iron":"steel", "lance_iron2":"gunmetal", "lance_cloth":"c_scarf",
         "lance_cloth2":"c_duster"}
TYPES = {5121:"u1", 5123:"<u2", 5125:"<u4", 5126:"<f4"}
WIDTH = {"SCALAR":1, "VEC2":2, "VEC3":3, "VEC4":4, "MAT4":16}
TARGETS = {"ninola_tripo":.24, "cowboy_anim":.24, "cowboy_tripo":.34, "cowboy":.30,
           "revolver_tripo":.29, "shotgun_tripo":.36, "lance_tripo":.42, "rifle":.52}


class Glb:
    def __init__(self, source):
        raw = source.read_bytes()
        end = 20 + struct.unpack_from("<I",raw,12)[0]
        self.doc = json.loads(raw[20:end])
        self.data = bytearray(raw[end+8:])
        self.materials = self.doc["materials"]
        for material in self.materials:
            name = material["name"].split(".")[0]
            self.paint(material, EXTRA.get(name, name) if not name.startswith("tripo_mat") else "steel")

    @staticmethod
    def paint(material, key):
        material["pbrMetallicRoughness"] = {"baseColorFactor":[*_rgb(PALETTE[key]),1.],
                                            "metallicFactor":0., "roughnessFactor":.89}

    def material(self, name):
        for index, material in enumerate(self.materials):
            if material["name"] == name:
                return index
        material = {"name":name}
        self.paint(material,name)
        self.materials.append(material)
        return len(self.materials)-1

    def read(self, index):
        a = self.doc["accessors"][index]
        v = self.doc["bufferViews"][a["bufferView"]]
        dtype = np.dtype(TYPES[a["componentType"]])
        width = WIDTH[a["type"]]
        return np.ndarray((a["count"],width),dtype,self.data,v.get("byteOffset",0)+a.get("byteOffset",0),
                          (v.get("byteStride",width*dtype.itemsize),dtype.itemsize)).copy()

    def append(self, rows, kind, component):
        data = np.asarray(rows,dtype=TYPES[component]).reshape((-1,WIDTH[kind]))
        self.data.extend(bytes(-len(self.data)%4))
        views = self.doc["bufferViews"]
        views.append({"buffer":0,"byteOffset":len(self.data),"byteLength":data.nbytes,"target":34962})
        self.data.extend(data.tobytes())
        a = {"bufferView":len(views)-1, "componentType":component, "type":kind, "count":len(data)}
        if kind == "VEC3":
            a.update(min=data.min(axis=0).tolist(),max=data.max(axis=0).tolist())
        self.doc["accessors"].append(a)
        return len(self.doc["accessors"])-1

    def save(self, dest):
        self.data.extend(bytes(-len(self.data)%4))
        self.doc["buffers"][0]["byteLength"]=len(self.data)
        header=json.dumps(self.doc,separators=(",",":"),ensure_ascii=False).encode()
        header+=b" "*(-len(header)%4)
        dest.write_bytes(struct.pack("<4sIIII",b"glTF",2,28+len(header)+len(self.data),len(header),0x4e4f534a)
                         +header+struct.pack("<II",len(self.data),0x004e4942)+self.data)


def fittings(name, tree, skin, glb):
    """依原皮面放置有厚度的木銷與眼珠，把整枚木銷綁到同一組權重。"""
    triangles = []
    def peg(center, axis, radius, depth, color, anchor):
        axis = axis.normalized()
        a = axis.orthogonal().normalized()
        b = axis.cross(a)
        rings = [[center+axis*h+(a*cos(i*tau/12)+b*sin(i*tau/12))*r for i in range(12)]
                 for h,r in ((-depth*.5,radius),(.25*depth,radius),(.5*depth,radius*.85))]
        def face(vs):
            for i in range(1,len(vs)-1):
                triangles.append((glb.material(color),[vs[0],vs[i],vs[i+1]],anchor))
        for l,u in zip(rings,rings[1:]):
            for i in range(12):
                j=(i+1)%12
                face([l[i],l[j],u[j],u[i]])
        face(rings[-1])
    if name=="ninola_tripo":
        for side in (-1,1):
            axis=Vector((side,0,0))
            for height,forward,radius,eye in ((3.08,2.63,.104,True),(1.56,-.04,.155,False),
                                               (.94,.30,.09,False),(2.,1.77,.08,False),(2.81,2.2,.088,False)):
                hit,normal,_,_=tree.ray_cast((side*4,height,-forward),-axis,8)
                if hit is None:
                    continue
                if eye:
                    if normal.dot(axis)<0:
                        normal=-normal
                    for offset,r,depth,key in ((0,radius,.045,"socket"),(.029,.072,.022,"iris"),(.047,.035,.020,"pupil")):
                        peg(hit+normal*offset,normal,r,depth,key,hit)
                else:
                    peg(hit,axis,radius,.06,"peg_ring",hit)
                    peg(hit+axis*.038,axis,radius*.72,.05,"peg",hit)
            for i,forward in enumerate((3.16,3.27,3.39,3.50,3.60,3.69)):
                hit,_,_,_=tree.ray_cast((side*4,2.77,-forward),-axis,8)
                if hit is None:
                    continue
                base=[hit+Vector((dx*.023,.0,dz*.044)) for dx,dz in ((-1,-1),(1,-1),(1,1),(-1,1))]
                tip=hit+Vector((-side*.018,-(.10 if i%2 else .13),.019))
                for j in range(4):
                    triangles.append((glb.material("tooth"),[base[j],base[(j+1)%4],tip],hit))
    if name=="cowboy_anim":
        inv=glb.read(skin["inverseBindMatrices"])
        for i,node_index in enumerate(skin["joints"]):
            if not glb.doc["nodes"][node_index]["name"].endswith("ForeArm"):
                continue
            joint=np.linalg.inv(inv[i].reshape(4,4).T)[:3,3]
            side=1 if joint[0]>0 else -1
            axis=Vector((side,0,0))
            hit,_,_,_=tree.ray_cast(Vector(joint)+axis*.07,-axis,.15)
            if hit is not None:
                peg(hit,axis,.034,.023,"peg",hit)
    return triangles


def body_faces(mesh, name, glb):
    if name != "ninola_tripo":
        return [(p.material_index,[mesh.vertices[i].co.copy() for i in p.vertices],None) for p in mesh.polygons]
    triangles=[]
    planes=[1.35,2.55,3.85]
    for lower,upper in zip([None]+planes,planes+[None]):
        part=bmesh.new()
        part.from_mesh(mesh)
        for cut,keep_above in ((lower,True),(upper,False)):
            if cut is None:
                continue
            result=bmesh.ops.bisect_plane(part,geom=part.verts[:]+part.edges[:]+part.faces[:],
                plane_co=(0,0,cut+(.013 if keep_above else -.013)),plane_no=(0,0,1),
                clear_inner=keep_above,clear_outer=not keep_above,dist=1e-6)
            edges=[e for e in result["geom_cut"] if isinstance(e,bmesh.types.BMEdge) and e.is_valid and e.is_boundary]
            if edges:
                for face in bmesh.ops.holes_fill(part,edges=edges)["faces"]:
                    face.material_index=glb.material("peg")
        bmesh.ops.triangulate(part,faces=part.faces[:])
        triangles.extend((f.material_index,[v.co.copy() for v in f.verts],None) for f in part.faces)
        part.free()
    return triangles


def carve(glb, index, name):
    mesh=glb.doc["meshes"][index]
    node=next(n for n in glb.doc["nodes"] if n.get("mesh")==index)
    pos,faces,labels=[],[],[]
    weights=defaultdict(list)
    for prim in mesh["primitives"]:
        attrs=prim["attributes"]
        p=glb.read(attrs["POSITION"])
        ids=glb.read(prim["indices"]).reshape(-1,3)
        faces.extend((ids+len(pos)).tolist())
        pos.extend(p.tolist())
        original=prim["material"]
        label=np.full(len(ids),original)
        if name=="revolver_tripo" and glb.materials[original]["name"]=="steel":
            if node["name"]=="Revolver":
                label[p[ids,1].mean(axis=1)<-.012]=glb.material("grip")
            elif node["name"] in ("RevolverCylinder","RevolverHammer"):
                label[:]=glb.material("gunmetal")
        if name=="shotgun_tripo" and glb.materials[original]["name"].startswith("tripo_mat"):
            if node["name"]=="Shotgun":
                label[p[ids,2].mean(axis=1)>np.percentile(p[:,2],45)]=glb.material("grip")
            else:
                label[:]=glb.material("gunmetal")
        labels.extend(label.tolist())
        for k in attrs:
            if k.startswith(("WEIGHTS_","JOINTS_")):
                weights[k].extend(glb.read(attrs[k]).tolist())
    kd=KDTree(len(pos))
    for i,p in enumerate(pos):
        kd.insert(p,i)
    kd.balance()
    original_tree=BVHTree.FromPolygons(pos,faces,all_triangles=True)
    temp=bpy.data.meshes.new("表面")
    temp.from_pydata(pos,[],faces)
    for i in range(len(glb.materials)):
        temp.materials.append(bpy.data.materials.new(str(i)))
    temp.polygons.foreach_set("material_index",labels)
    bm=bmesh.new()
    bm.from_mesh(temp)
    bmesh.ops.remove_doubles(bm,verts=bm.verts[:],dist=0.000001)
    bm.to_mesh(temp)
    bm.free()
    obj=bpy.data.objects.new("削面",temp)
    bpy.context.scene.collection.objects.link(obj)
    mod=obj.modifiers.new("保留小零件","DECIMATE")
    mod.ratio=max(min(1.,64/len(faces)),TARGETS[name])
    out=obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    tris=body_faces(out,name,glb)
    skin=glb.doc["skins"][node["skin"]] if "skin" in node else None
    tris+=fittings(name,original_tree,skin,glb)
    groups=defaultdict(lambda:defaultdict(list))
    for mat,vs,anchor in tris:
        normal=(vs[1]-vs[0]).cross(vs[2]-vs[0])
        if normal.length_squared < 1e-18:
            continue
        group=groups[mat]
        group["POSITION"].extend(vs)
        group["NORMAL"].extend([normal.normalized()]*3)
        if weights:
            source=[kd.find(anchor)[1]]*3 if anchor is not None else [kd.find(v)[1] for v in vs]
            for k,rows in weights.items():
                group[k].extend(rows[i] for i in source)
    mesh["primitives"]=[]
    for mat,group in sorted(groups.items()):
        attrs={k:glb.append(rows,"VEC3" if k in ("POSITION","NORMAL") else "VEC4",
                            5121 if k.startswith("JOINTS") else 5126) for k,rows in group.items()}
        mesh["primitives"].append({"attributes":attrs,"material":mat,"mode":4})
    bpy.data.objects.remove(obj,do_unlink=True)
    return len(faces),sum(len(g["POSITION"])//3 for g in groups.values())


if __name__=="__main__":
    source,dest=map(Path,sys.argv[sys.argv.index("--")+1:])
    assert source.resolve()!=dest.resolve()
    for name in TARGETS:
        glb=Glb(source/(name+".glb"))
        counts=[carve(glb,i,name) for i in range(len(glb.doc["meshes"]))]
        glb.save(dest/(name+".glb"))
        print("CAST",name,np.sum(counts,axis=0).tolist(),flush=True)
