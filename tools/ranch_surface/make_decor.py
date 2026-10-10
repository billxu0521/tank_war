"""v8 small stylized ground fragments, original geometry, metres, Blender Z up.
No textures, transparency, colliders, downloaded assets or external generation.
Isolated pipeline equivalent: model_iter.sh hardcodes production models/ so not used.
"""
import bpy, bmesh, math, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'blender'))
import pipeline

def make_mesh(name,verts,faces,mat):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(mat)
    return ob

def build():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    mats=[]
    for name,col in [('DryLeaf',(.31,.255,.16,1)),('SmallStone',(.36,.29,.22,1)),('DryWood',(.285,.215,.14,1)),('WoodChip',(.37,.295,.19,1))]:
        m=bpy.data.materials.new(name);m.diffuse_color=col;m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=col;bs.inputs['Roughness'].default_value=.95;mats.append(m)
    obs=[]
    for family in range(4):
        for variant in range(3):
            name=['Leaf','Stone','Twig','Chip'][family]+str(variant)
            if family==0:
                length=[.16,.22,.14][variant];width=[.065,.042,.08][variant]
                ring=[(-length*.52,0,.001),(-length*.18,width*.52,.001),(length*.3,width*.38,.002),(length*.5,0,.001),(length*.12,-width*.47,.002),(-length*.25,-width*.32,.001)]
                verts=ring+[(0,0,.008)];faces=[(i,(i+1)%6,6) for i in range(6)]
                # thin underside, unlike transparent card, no giant star rosette
                verts += [(x,y,0) for x,y,z in ring];faces += [tuple(range(7,13))]+[(i,i+7,(i+1)%6+7,(i+1)%6) for i in range(6)]
            elif family in (1,3):
                length=([.09,.14,.11] if family==1 else [.14,.19,.10])[variant]
                width=([.075,.062,.10] if family==1 else [.035,.03,.05])[variant]
                height=.025 if family==1 else .012
                ring=[(-length*.5,-width*.24,0),(-length*.20,width*.48,0),(length*.35,width*.37,0),(length*.52,-width*.08,0),(length*.11,-width*.47,0)]
                verts=ring+[(x*.8+length*.04,y*.76,height*(.72+(.2 if i%2 else 0))) for i,(x,y,z) in enumerate(ring)]
                faces=[tuple(reversed(range(5))),tuple(range(5,10))]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
            else:
                # Bent irregular short branch; flat five-sided section, no repeated Y-star.
                centers=[(-.17,0,.008),(-.01,.013 if variant!=1 else -.024,.012),(.14,.03 if variant==0 else -.01,.004)]
                verts=[]
                for j,(x,y,z) in enumerate(centers):
                    radius=[.008,.007,.003][j]
                    verts += [(x,y+math.cos(k*math.tau/5)*radius,z+math.sin(k*math.tau/5)*radius) for k in range(5)]
                faces=[tuple(reversed(range(5))),tuple(range(10,15))]+[(j*5+k,j*5+(k+1)%5,(j+1)*5+(k+1)%5,(j+1)*5+k) for j in range(2) for k in range(5)]
                if variant==2:
                    # distinct broken tip silhouette, not another separate object
                    for i in range(10,15):verts[i]=(verts[i][0]*.62,verts[i][1]-.025,verts[i][2])
            obs.append(make_mesh(name,verts,faces,mats[family]))
    return obs

if __name__=='__main__':
    obs=build();probs=pipeline.check(obs,budget=48)
    if probs:raise RuntimeError('CHECK FAIL '+str(probs))
    print('CHECK OK')
    out=Path(__file__).parent
    pipeline.export(obs,str(ROOT/'levels/ranch_surface/ground_fragments.glb'))
    # 可編輯來源即此參數化腳本；不提交大型Blender暫存。
    (out/'decor-budget.json').write_text(json.dumps({o.name:{'triangles':pipeline.tris(o),'height_m':max(v.co.z for v in o.data.vertices),'textures':0} for o in obs},indent=2))
