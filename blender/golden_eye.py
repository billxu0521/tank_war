"""Build a faceted golden eye. Run in Blender Python; +Z up, front is -Y.
Diameter: 2 Blender units. No external textures required.
"""
import bpy, math, random
from datetime import datetime
from zoneinfo import ZoneInfo
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'models'
RECORD_ROOT = ROOT / 'docs/image/modeling-tests/golden-eye'
DATE = datetime.now(ZoneInfo('Asia/Taipei')).strftime('%Y-%m-%d')
VERSION = 1
while (RECORD_ROOT / f'{DATE}-v{VERSION:03d}').exists():
    VERSION += 1
RECORD = RECORD_ROOT / f'{DATE}-v{VERSION:03d}'
RECORD.mkdir(parents=True)
rng = random.Random(52)
scene = bpy.data.scenes.new('Golden Eye Studio')
bpy.context.window.scene = scene

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .87
    bs.inputs['Specular IOR Level'].default_value = .12
    return m

palette = []
for label, rgb in [('Sclera',(.49,.455,.29)),('Iris Rim',(.23,.082,.018)),('Amber',(.52,.185,.019)),('Gold',(.91,.45,.035)),('Pupil',(.012,.015,.014))]:
    for k in range(6):
        factor = .84 + k*.055
        palette.append(material(f'{label} {k+1}',tuple(min(1,c*factor) for c in rgb)))
N=32
angles=[.13,.30,.40,.58,.76,.92,1.12,1.36,1.60,1.86,2.12,2.39,2.66,2.90]
verts=[(0,-1.025,0)]
for row,theta in enumerate(angles):
    for j in range(N):
        # Offset shell rows to create large irregular triangular facets.
        phase = (0 if row<6 else (.42 if row%2 else 0)) * 2*math.pi/N
        phi=2*math.pi*j/N+phase
        t=theta+(rng.uniform(-.035,.035) if row>=6 else 0)
        rr=1.012 if row<2 else 1
        verts.append((rr*math.sin(t)*math.cos(phi),-rr*math.cos(t),rr*math.sin(t)*math.sin(phi)))
verts.append((0,1,0))
faces=[]; zones=[]
for j in range(N):
    faces.append((0,1+j,1+(j+1)%N)); zones.append(('pupil',j,0))
for row in range(len(angles)-1):
    for j in range(N):
        a=1+row*N+j; b=1+row*N+(j+1)%N
        c=1+(row+1)*N+j; d=1+(row+1)*N+(j+1)%N
        pair=[(a,c,b),(b,c,d)] if row%2 else [(a,c,d),(a,d,b)]
        for part,face in enumerate(pair):
            faces.append(face); zones.append(('band',j,(row,part)))
last=len(verts)-1
for j in range(N):
    faces.append((1+(len(angles)-1)*N+j,last,1+(len(angles)-1)*N+(j+1)%N)); zones.append(('shell',j,0))
mesh=bpy.data.meshes.new('GoldenEye_Triangulated')
mesh.from_pydata(verts,[],faces); mesh.update()
eye=bpy.data.objects.new('GoldenEye',mesh); scene.collection.objects.link(eye)
for mat in palette: mesh.materials.append(mat)
for poly,(kind,j,data) in zip(mesh.polygons,zones):
    if kind=='pupil': zone=4
    elif kind=='shell': zone=0
    else:
        row,part=data
        if row==0: zone=4
        elif row==1: zone=3
        elif row==2: zone=3
        elif row==3: zone=3 if j%2==0 and part==0 else 2
        elif row==4: zone=1
        elif row==5: zone=0
        else: zone=0
    poly.material_index=zone*6+rng.randrange(6)
    poly.use_smooth=False
# Ensure outward normals on the closed manifold.
import bmesh
bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(mesh); bm.free()
eye['description']='Faceted cream eyeball with radial amber/gold iris and black pupil'
eye['front_axis']='-Y (Blender); +Z up'
eye['diameter']=2.0
# Select only the delivered object for the glTF export.
for ob in bpy.context.selected_objects: ob.select_set(False)
eye.select_set(True); bpy.context.view_layer.objects.active=eye
bpy.ops.export_scene.gltf(filepath=str(OUT/'golden_eye.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True)
# Studio lights and orthographic camera are in the editable .blend, not in GLB.
world=bpy.data.worlds.new('Eye Studio World'); world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
bg.inputs['Color'].default_value=(.68,.68,.68,1); bg.inputs['Strength'].default_value=.8
scene.world=world
for name,pos,power,size in [('Key',(-3,-4,5),450,5),('Fill',(4,-1,2),120,4)]:
    light=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA')); scene.collection.objects.link(light)
    light.location=pos; light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler(); light.data.energy=power; light.data.shape='DISK'; light.data.size=size
cam=bpy.data.objects.new('Preview Camera',bpy.data.cameras.new('Preview Camera')); scene.collection.objects.link(cam)
cam.data.type='ORTHO'; cam.data.ortho_scale=2.55; scene.camera=cam
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=24
scene.render.resolution_x=600; scene.render.resolution_y=600; scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.view_settings.view_transform='Standard'
for name,pos in [('front',(0,-5,0)),('side',(5,0,0)),('back',(0,5,0)),('three_quarter',(3.6,-4.4,1.2))]:
    cam.location=pos; cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(RECORD/(name+'.png')); bpy.ops.render.render(write_still=True)
cam.location=(3.6,-4.4,1.2); cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
# Show the model in the viewport.
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            area.spaces.active.region_3d.view_distance=4.5
            area.spaces.active.region_3d.view_location=(0,0,0)
            area.spaces.active.shading.color_type='MATERIAL'
bpy.data.libraries.write(str(ROOT/'blender/golden_eye.blend'),{scene},fake_user=True,compress=True)
print('EYE_BUILT',len(mesh.vertices),'vertices',len(mesh.polygons),'triangles')

(RECORD/'README.md').write_text(f'# Golden Eye {DATE} v{VERSION:03d}\n\n450 頂點／896 三角面；Cycles CPU 24 samples；四視圖 600×600。\n本輪產生於 build_eye.py，尚待查看圖片、製作對比與驗證模型。\n', encoding='utf-8')
print('IMAGE_RECORD', str(RECORD))
