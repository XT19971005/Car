"""Original stylized circuit kit. Run with Blender 4.5 --background --python this_file.
Metres, Z up; GLB exports Y up. One joined mesh per asset for Godot MultiMesh.
The .blend retains named collections. No downloaded geometry or textures.
"""
import bpy, math, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/source_blender'
EXPORT = ROOT / 'godot/assets/environment/circuit_kit'
PREVIEW = ROOT / 'art/previews'
for folder in (SOURCE, EXPORT, PREVIEW):
    folder.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
random.seed(1922)

def mat(name, color, roughness=.85, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metal
    return m

bark = mat('Bark_warm_umber', (.20,.13,.08))
leaves = [mat('Foliage_%02d'%i, c) for i,c in enumerate([
    (.16,.27,.07), (.24,.36,.10), (.32,.43,.12), (.39,.49,.16), (.28,.39,.09)])]
stone = mat('Limestone', (.46,.46,.36))
cream = mat('Concrete_warm', (.68,.65,.52))
ivory = mat('Paint_ivory', (.83,.82,.70))
steel = mat('Steel_blue_grey', (.21,.28,.29),.55,.30)
zinc = mat('Guardrail_zinc', (.55,.61,.59),.52,.45)
glass = mat('Glazing_teal', (.08,.19,.22),.27,.3)
red = mat('Monza_red', (.61,.09,.055))
seat = mat('Seat_muted_terracotta', (.63,.23,.12))
green = mat('Italian_green', (.08,.34,.19))
black = mat('Rubber', (.035,.045,.043))
assets = []
parts = []

def finish_part(obj, material):
    obj.data.materials.append(material)
    parts.append(obj)
    return obj

def box(name, loc, size, material, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Soft_edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish_part(o, material)

def branch(a,b,r1,r2, material=bark):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r1, radius2=r2, depth=(b-a).length, location=(a+b)/2)
    o=bpy.context.object
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish_part(o,material)

def lump(loc, scale, material, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    o=bpy.context.object
    for v in o.data.vertices:
        v.co *= random.uniform(.86,1.13)
    o.scale=scale
    o.rotation_euler.z=random.random()*math.tau
    return finish_part(o,material)

def export_asset(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    o=bpy.context.object
    o.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    collection=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    for col in list(o.users_collection):
        col.objects.unlink(o)
    collection.objects.link(o)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
    assets.append(o)
    parts.clear()

for variant in range(3):
    h=10+variant*1.7
    branch((0,0,0),(.25,.15,h*.7),.46,.14)
    for i in range(7):
        a=i*2.399+variant
        x,y=math.cos(a)*2.2,math.sin(a)*2.2
        branch((.1,0,h*.36),(x,y,h*.70),.18,.055)
        lump((x,y,h*.75+random.uniform(-1,1)),(2.4,2.2,2.4),leaves[(i+variant)%5],2)
    for i in range(6):
        a=i*2.399
        lump((math.cos(a)*1.5,math.sin(a)*1.5,h+random.uniform(-.9,.5)),(2.0,2.1,2.0),leaves[(i+2)%5],1)
    export_asset('ENV_Monza_Oak_%02d'%(variant+1))

branch((0,0,0),(0,0,15),.36,.07)
for i in range(10):
    a=i*2.4
    z=5+i*.95
    w=1.6 if i<6 else 1.6-(i-6)*.25
    lump((math.cos(a)*.6,math.sin(a)*.6,z),(w,w,2.6),leaves[i%5],2)
export_asset('ENV_Monza_Poplar_01')

for i in range(6):
    a=i*2.4
    lump((math.cos(a)*1.1,math.sin(a)*.9,.65+random.random()*.4),(1.15,1.05,.9),leaves[i%5],1)
export_asset('ENV_Monza_Shrub_01')
for i in range(3):
    lump((i*.55,0,.32),(.8,.65,.6),stone,1)
export_asset('ENV_Monza_StoneCluster_01')

# Modular pit building: long axis Y, garage doors face -X (toward circuit).
box('Pit_base',(0,0,2.0),(12,24,4),cream,.12)
box('Upper_storey',(0,0,5.1),(11.8,24,2.2),ivory,.08)
box('Roof',(0,0,6.45),(13.2,25,.35),steel,.08)
box('Balcony',(-6.7,0,4.15),(2,24,.3),ivory,.04)
for y in range(-10,11,4):
    box('Garage_door',(-6.04,y,1.6),(.08,3.55,2.85),steel,.025)
    for z in [.5,1.0,1.5,2,2.5]:
        box('Door_slat',(-6.10,y,z),(.025,3.5,.025),zinc)
    box('Red_header',(-6.12,y,3.3),(.10,3.6,.26),red)
    box('Glazing',(-5.96,y,5.15),(.06,3.65,1.5),glass)
    box('Balcony_post',(-7.6,y,4.8),(.08,.08,1.15),zinc)
box('Balcony_rail',(-7.6,0,5.35),(.075,24,.075),zinc)
for y in [-11,11]:
    box('AC_roof',(1,y,6.85),(2.4,1.4,.6),ivory,.1)
export_asset('ENV_Monza_PitModule_24m')

# Covered grandstand. Front +X, seats ascend toward -X; long axis Y.
for row in range(9):
    x=4.8-row*1.15
    z=.4+row*.53
    box('Concrete_tier',(x,0,z/2),(1.2,30,z),cream)
    for col in range(27):
        y=-14+col*1.06
        if abs(y)<1.2: continue
        box('Seat',(x,y,z+.22),(.55,.70,.18),seat,.065)
        box('Backrest',(x-.26,y,z+.51),(.12,.7,.48),seat,.045)
for y in [-14,-7,0,7,14]:
    branch((-6,y,0),(-6,y,8.3),.12,.12,steel)
    branch((-6,y,7.8),(5.7,y,7.8),.12,.12,steel)
    branch((-6,y,6),(-1,y,7.8),.07,.07,steel)
box('Roof',(-.4,0,8.15),(14,32,.3),ivory,.05)
box('Fascia',(6.65,0,7.9),(.18,32,.7),red)
export_asset('ENV_Monza_Grandstand_30m')

for y in [-4,0,4]:
    box('Post',(0,y,.6),(.16,.16,1.2),zinc)
for z in [.35,.65,.95]:
    box('Rail',(0,0,z),(.14,8.15,.18),zinc,.04)
export_asset('ENV_Circuit_Guardrail_8m')

for y in [-4,4]:
    branch((0,y,0),(0,y,3.5),.045,.045,steel)
    branch((0,y,3.5),(-.55,y,4.15),.045,.045,steel)
for z in [.55,1.1,1.65,2.2,2.75,3.3]:
    box('Fence_wire',(0,0,z),(.018,8,.018),steel)
for y in [i*.5-4 for i in range(17)]:
    box('Fence_wire',(0,y,1.95),(.018,.018,2.9),steel)
export_asset('ENV_Circuit_SafetyFence_8m')

# Ardennes evergreens: layered irregular boughs, rather than a single cone.
branch((0,0,0),(0,0,16),.32,.04)
for level in range(7):
    height=4.0+level*1.65
    radius=3.2-level*.37
    for i in range(5):
        angle=i*math.tau/5+level*.7
        lump((math.cos(angle)*radius*.45,math.sin(angle)*radius*.45,height),(radius*.68,radius*.68,1.65),leaves[(i+level)%3],1)
export_asset('ENV_Spa_Conifer_01')

box('Pit_base',(0,0,3),(16,30,6),cream,.1)
box('Glass_band',(-8.02,0,4.6),(.1,29,2),glass,.02)
box('Terrace',(-9,0,6.1),(3,30,.25),ivory,.05)
box('Upper_glazing',(1,0,7.6),(12,29,2.6),glass,.05)
box('Flat_roof',(0,0,9.15),(18,31,.35),ivory,.04)
for y in range(-12,13,4):
    box('Garage',(-8.07,y,1.7),(.10,3.5,3.2),steel,.025)
    box('Bay_number_strip',(-8.15,y,3.45),(.08,3.5,.25),red)
    box('Roof_pillar',(-5,y,7.7),(.16,.16,3),ivory)
export_asset('ENV_Spa_PitModule_30m')

box('Wing_base',(0,0,4.8),(22,30,9.6),cream,.07)
box('Wing_glass_front',(-11.04,0,7.3),(.06,30,3.5),glass)
for y in range(-13,14,4):
    box('Garage',(-11.08,y,2),(.08,3.5,3.6),steel,.02)
    box('Facade_mullion',(-11.1,y,7.2),(.16,.13,3.9),ivory)
# Folding roof creates the recognizable wing-like angular profile.
vertices=[(-13,-16,10),(12,-16,12),(-13,0,14),(12,0,11),(-13,16,10),(12,16,12)]
roof_mesh=bpy.data.meshes.new('Wing_folded_roof');roof_mesh.from_pydata(vertices,[],[(0,1,3,2),(2,3,5,4)]);roof_mesh.update()
roof_object=bpy.data.objects.new('Wing_roof',roof_mesh);bpy.context.collection.objects.link(roof_object)
finish_part(roof_object,ivory)
mod=roof_object.modifiers.new('Roof_thickness','SOLIDIFY');mod.thickness=.2
bpy.context.view_layer.objects.active=roof_object;bpy.ops.object.modifier_apply(modifier=mod.name)
export_asset('ENV_Silverstone_WingModule_30m')

box('Marshal_cabin',(0,0,1.4),(3.2,3.2,2.8),ivory,.08)
box('Window',(0,-1.61,1.9),(2.8,.04,1.1),glass)
box('Roof',(0,0,2.94),(3.7,3.7,.25),red,.07)
branch((2,0,0),(2,0,6),.04,.04,zinc)
box('Flag',(2.5,0,5.5),(1,.025,.65),green)
export_asset('ENV_Circuit_MarshalPost_01')

for x in [-2,2]:
    for y in [-2,2]:branch((x,y,0),(x,y,2.6),.055,.055,ivory)
bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=3.3,radius2=0,depth=1.25,location=(0,0,3.05),rotation=(0,0,math.pi/4))
finish_part(bpy.context.object,ivory)
export_asset('ENV_Circuit_PaddockTent_01')

branch((0,0,0),(0,0,10),.075,.05,zinc)
branch((0,0,9.8),(1.5,0,9.8),.05,.05,zinc)
box('Lamp',(1.4,0,9.75),(.9,.45,.18),ivory,.04)
export_asset('ENV_Circuit_LightPole_01')

for y in range(4):
    for z in range(3):
        bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=6,major_radius=.28,minor_radius=.13,location=(0,y*.75,z*.27+.18))
        finish_part(bpy.context.object,black)
export_asset('ENV_Circuit_TyreBarrier_3m')

box('Concrete_barrier',(0,0,.5),(.55,4,1),ivory,.10)
for y,m in [(-1.5,red),(-.5,ivory),(.5,red),(1.5,ivory)]:box('Barrier_paint',(-.281,y,.55),(.018,.98,.75),m,.015)
export_asset('ENV_Circuit_PitWall_4m')

# Assemble a clean library display, without altering exported origins.
positions=[(-16,0),(-5,0),(7,0),(18,0),(-17,-10),(-10,-10),(0,30),(23,30),(-4,-11),(9,-11)]
positions += [(36,0),(-32,35),(-62,35),(35,-10),(43,-10),(53,-10),(38,-20),(45,-20)]
for o,(x,y) in zip(assets,positions): o.location=(x,y,0)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'ENV_Circuit_Stylized_Library.blend'))

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.world.color=(.35,.4,.5)
bpy.ops.mesh.primitive_plane_add(size=200)
floor=bpy.context.object
floor.data.materials.append(mat('Preview_background',(.48,.53,.39)))
bpy.ops.object.light_add(type='AREA',location=(-30,-25,60))
light=bpy.context.object
light.data.energy=50000
light.data.shape='DISK'
light.data.size=28
bpy.ops.object.camera_add(location=(100,-130,105))
camera=bpy.context.object
camera.rotation_euler=(Vector((-5,10,3))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=165
scene.camera=camera
scene.render.resolution_x=1500
scene.render.resolution_y=1050
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(PREVIEW/'ENV_Circuit_AssetLibrary.png')
bpy.ops.render.render(write_still=True)
print('ASSET BUILD COMPLETE:',len(assets),'assets')
