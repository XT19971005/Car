"""Original fictional GT coupe: Blender source + wheel-separated GLB + preview."""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/cars'
OUT.mkdir(parents=True,exist_ok=True)
variant = next((a.split('=')[1] for a in sys.argv if a.startswith('--variant=')), 'v8')
spec = {'v8': {'asset':'VEH_V8_Muscle_GT','length':4.746,'width':2.049,'height':1.238,'wheelbase':2.630,'color':(.035,.20,.16)},
        'r6': {'asset':'VEH_Rally_Hatch','length':4.10,'width':1.86,'height':1.48,'wheelbase':2.55,'color':(.68,.54,.27)},
        'v6': {'asset':'VEH_Apex_Prototype','length':4.85,'width':2.04,'height':1.08,'wheelbase':2.85,'color':(.55,.045,.04)}}[variant]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name,c,rough=.5,metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*c,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    return m
paint=mat('Racing_bodywork',spec['color'],.30,.38)
lightpaint=mat('Ivory_livery',(.86,.83,.65),.42,.12)
dark=mat('Carbon',(.025,.034,.039),.72)
glass=mat('Smoked_blue_glass',(.055,.13,.17),.18,.4)
glass.use_backface_culling=True
rubber=mat('Tyre',(.025,.025,.028),.92)
alloy=mat('Wheel_champagne',(.64,.51,.29),.3,.7)
red=mat('Tail_lenses',(.8,.025,.018),.24)
lamp=mat('Headlight_lenses',(.85,.96,1),.2)
caliper=mat('Brake_calipers',(.85,.22,.055),.45,.25)

def box(name,loc,size,m,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Chamfer','BEVEL'); mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted_corner_normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(m)
    return o

def mesh(name,verts,faces,m):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);data.materials.append(m)
    return o

# Front is -Y in Blender, +Z in Godot. Body rings form a low GT silhouette.
rings=[(-2.3,.83,.43,.72),(-1.95,1.0,.38,.87),(-1.25,1.02,.38,.92),
       (-.7,.95,.39,.83),(.65,.99,.4,.89),(1.35,1.04,.41,1.0),(2.15,.96,.45,.96),(2.3,.89,.5,.86)]
if variant == 'r6':
    rings=[(-2.3,.82,.30,.88),(-1.85,.99,.30,1.01),(-1.1,1.04,.31,1.05),(-.65,.97,.31,1.02),(.75,1.0,.31,1.08),(1.45,1.05,.33,1.13),(2.15,.99,.34,1.09),(2.30,.96,.38,1.02)]
elif variant == 'v6':
    rings=[(-2.3,.67,.26,.40),(-1.95,.99,.27,.57),(-1.35,1.04,.28,.87),(-.65,.99,.28,.76),(.5,.99,.28,.80),(1.40,1.04,.28,.85),(2.15,1.02,.30,.73),(2.3,.93,.34,.60)]
verts=[]
for y,w,bottom,top in rings:
    verts += [(-w*.88,y,bottom),(-w,y,bottom+.14),(-w,y,top-.1),(-w*.98,y,top),
              (w*.98,y,top),(w,y,top-.1),(w,y,bottom+.14),(w*.88,y,bottom)]
faces=[]
for j in range(len(rings)-1):
    for i in range(8): faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
faces += [tuple(range(7,-1,-1)),tuple(range((len(rings)-1)*8,len(rings)*8))]
mesh('GT_sculpted_body',verts,faces,paint)
# Glasshouse: long sloping windscreen, compact roof, fastback rear.
v=[(-.79,-.85,.9),(.79,-.85,.9),(-.65,-.22,1.43),(.65,-.22,1.43),
   (-.65,.65,1.43),(.65,.65,1.43),(-.83,1.4,.98),(.83,1.4,.98)]
if variant == 'r6':
    v=[(-.81,-.86,1.04),(.81,-.86,1.04),(-.70,-.42,1.71),(.70,-.42,1.71),(-.70,1.32,1.71),(.70,1.32,1.71),(-.83,1.88,1.12),(.83,1.88,1.12)]
elif variant == 'v6':
    v=[(-.62,-1.12,.77),(.62,-1.12,.77),(-.49,-.32,1.28),(.49,-.32,1.28),(-.49,.35,1.28),(.49,.35,1.28),(-.65,1.23,.84),(.65,1.23,.84)]
mesh('Glasshouse',v,[(0,1,3,2),(2,3,5,4),(4,5,7,6),(0,2,4,6),(1,7,5,3)],glass)
box('Roof',(0,(v[2][1]+v[4][1])/2,v[2][2]+.02),(abs(v[2][0])*2+.06,v[4][1]-v[2][1]+.06,.06),paint,.045)
def rod(name,a,b,width,m):
    a,b=Vector(a),Vector(b)
    o=box(name,(a+b)/2,(width,width,(b-a).length),m,.01)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o
for side in [-1,1]:
    rod('A_pillar',(side*abs(v[0][0]),v[0][1],v[0][2]),(side*abs(v[2][0]),v[2][1],v[2][2]),.065,paint)
    rod('C_pillar',(side*abs(v[4][0]),v[4][1],v[4][2]),(side*abs(v[6][0]),v[6][1],v[6][2]),.10,paint)
    rod('B_pillar',(side*.75,.40,.94),(side*abs(v[2][0]),.40,v[2][2]),.055,dark)
    box('Side_skirt',(side*1.015,0,.37),(.12,1.80,.14),dark)
    box('Door_number_panel',(side*.996,.05,.69),(.023,.66,.36),lightpaint,.015)
    box('Mirror_arm',(side*.9,-.59,1.09),(.30,.065,.07),dark,.02)
    box('Mirror',(side*1.09,-.59,1.12),(.22,.30,.13),paint,.05)
    box('Headlight',(side*.61,-2.23,.7),(.45,.1,.13),lamp,.035)
    box('Tail_light',(side*.57,2.255,.80),(.62,.08,.10),red,.022)
    for y in [-1.27,1.34]:
        # Dark wheel-well rings cover the body and create an arch outline.
        bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,location=(side*1.00,y,.43),major_radius=.35,minor_radius=.045,rotation=(0,math.pi/2,0))
        bpy.context.object.name='Wheelarch';bpy.context.object.data.materials.append(dark)
box('Front_splitter',(0,-2.16,.36),(2.10,.54,.10),dark,.035)
box('Front_intake',(0,-2.292,.53),(1.14,.035,.22),dark,.015)
for x in [-.38,0,.38]: box('Intake_vertical',(x,-2.325,.53),(.025,.035,.19),paint,.008)
box('Rear_diffuser',(0,2.20,.43),(1.65,.3,.22),dark,.025)
for x in [-.64,-.32,0,.32,.64]: box('Diffuser_fin',(x,2.27,.37),(.035,.36,.22),dark,.008)
for x in [-.62,.62]:box('Wing_mount',(x,1.87,1.10),(.07,.18,.35),dark,.015)
box('Rear_wing',(0,1.94,1.32),(2.00,.40,.065),dark,.025)
for x in [-.98,.98]:box('Wing_endplate',(x,1.94,1.35),(.05,.49,.20),paint,.02)
# Dual hood stripes and roof stripe. Slightly lifted geometry avoids z-fighting.
for x in [-.19,.19]:
    for j in range(3):
        ya,_,_,za=rings[j];yb,_,_,zb=rings[j+1]
        mesh('Hood_stripe',[(x-.09,ya,za+.007),(x+.09,ya,za+.007),(x+.09,yb,zb+.007),(x-.09,yb,zb+.007)],[(0,1,2,3)],lightpaint)
    box('Roof_stripe',(x,(v[2][1]+v[4][1])/2,v[2][2]+.054),(.18,v[4][1]-v[2][1],.005),lightpaint,0)
for x in [-.55,.55]:
    for y in [-1.6,-1.45,-1.30]:box('Hood_vent',(x,y,.938),(.27,.055,.015),dark,.01)

# Four separate wheel parents: local X axle, steering around Godot Y.
for side in [-1,1]:
    for front,y in [(True,-1.27),(False,1.34)]:
        bpy.ops.object.empty_add(location=(side*.88,y,.365))
        pivot=bpy.context.object;pivot.name='wheel_'+('front' if front else 'rear')+('_left' if side<0 else '_right')
        wheel_parts=[]
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.34,depth=.30,location=(side*.88,y,.365),rotation=(0,math.pi/2,0))
        o=bpy.context.object;o.name='Tyre';o.data.materials.append(rubber);wheel_parts.append(o)
        for poly in o.data.polygons:poly.use_smooth=len(poly.vertices)==4
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.25,depth=.025,location=(side*1.032,y,.365),rotation=(0,math.pi/2,0))
        o=bpy.context.object;o.name='Rim_dark_inset';o.data.materials.append(dark);wheel_parts.append(o)
        for i in range(8):
            a=i*math.tau/8
            spoke=box('Spoke',(side*1.04,y+math.sin(a)*.13,.365+math.cos(a)*.13),(.027,.043,.25),alloy,.01)
            spoke.rotation_euler.x=-a;wheel_parts.append(spoke)
        bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,major_radius=.25,minor_radius=.018,location=(side*1.04,y,.365),rotation=(0,math.pi/2,0))
        o=bpy.context.object;o.data.materials.append(alloy);wheel_parts.append(o)
        for o in wheel_parts:
            matrix=o.matrix_world.copy();o.parent=pivot;o.matrix_world=matrix

# Distinct silhouettes and functional visual details, not just paint changes.
if variant == 'r6':
    for side in [-1,1]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(side*.68,-1.97,.88))
        o=bpy.context.object;o.name='Round_endurance_headlight';o.scale=(.20,.17,.10);o.data.materials.append(lamp)
    for x in [-.54,-.18,.18,.54]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.14,depth=.12,location=(x,-2.38,.78),rotation=(math.pi/2,0,0))
        bpy.context.object.name='Rally_spotlight';bpy.context.object.data.materials.append(lamp)
    box('Hatch_roof_spoiler',(0,1.58,1.71),(1.67,.40,.075),paint,.035)
    box('Roof_air_vent',(0,.15,1.81),(.50,.48,.11),dark,.025)
    for side in [-1,1]:
        box('Rally_mudflap',(side*.94,1.77,.28),(.28,.045,.40),dark,.005)
        box('Vertical_tail_lamp',(side*.81,2.32,.88),(.14,.045,.35),red,.015)
elif variant == 'v6':
    for side in [-1,1]:
        mesh('Side_air_scoop',[(side*.98,.35,.85),(side*1.07,1.15,.95),(side*1.07,1.2,.50),(side*.98,.48,.50)],[(0,1,2,3)],dark)
        box('Rear_buttress',(side*.56,1.16,1.11),(.17,.85,.15),paint,.06)
    box('Rear_light_bar',(0,2.30,.68),(1.6,.025,.045),red,.01)
    mesh('Prototype_dorsal_fin',[(0,.43,1.26),(0,2.03,1.14),(0,2.10,.78),(0,.6,.84)],[(0,1,2,3)],paint)
    for side in [-1,1]:
        box('Front_fender_aero',(side*.91,-1.34,.77),(.31,1.0,.12),paint,.06)
        box('Prototype_LED_blade',(side*.86,-1.85,.65),(.08,.42,.025),lamp,.009)
else:
    for x in [i*.09-.63 for i in range(15)]:box('V8_vertical_grille',(x,-2.327,.59),(.021,.025,.22),alloy,.003)
    for side in [-1,1]:
        for y in [-.8,-.63,-.46]:box('Fender_gill',(side*1.00,y,.78),(.028,.085,.13),dark,.01)

# Cockpit geometry and named anchors survive GLB export.
box('Cockpit_floor',(0,.2,.28),(1.6,1.9,.09),dark)
box('Dashboard',(0,-.67,.91),(1.5,.40,.20),dark,.075)
box('Centre_console',(-.17,.05,.63),(.28,.95,.18),dark,.04)
for side in [-1,1]:
    box('Door_liner',(side*.8,.25,.7),(.065,1.35,.40),dark,.03)
    rod('Rollcage_A',(side*.70,-.7,.37),(side*.61,-.12,1.38),.05,alloy)
    rod('Rollcage_roof',(side*.61,-.12,1.38),(side*.61,.71,1.38),.05,alloy)
    rod('Rollcage_B',(side*.61,.71,1.38),(side*.73,1.0,.3),.05,alloy)
rod('Rollcage_crossbar',(-.61,.71,1.38),(.61,.71,1.38),.05,alloy)
box('Bucket_seat',(.36,.51,.53),(.48,.65,.28),dark,.08)
box('Seat_back',(.36,.88,.92),(.48,.13,.80),dark,.08)
for x in [.24,.47]:box('Harness',(x,.785,.98),(.07,.022,.53),red,.01)
for y in [-.3,-.05,.2]:
    for x in [-.27,-.12]:box('Console_button',(x,y,.738),(.052,.052,.025),red if y==.2 else alloy,.01)
bpy.ops.object.empty_add(location=(.36,-.33,1.02))
steering=bpy.context.object;steering.name='steering_wheel'
bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,major_radius=.145,minor_radius=.021,location=(.36,-.33,1.02),rotation=(math.pi/2,0,0))
rim=bpy.context.object;rim.data.materials.append(dark)
hub=box('Wheel_hub',(.36,-.33,1.02),(.22,.05,.09),dark,.02)
for o in [rim,hub]:
    matrix=o.matrix_world.copy();o.parent=steering;o.matrix_world=matrix
for x in [.26,.46]:
    o=box('Wheel_button',(x,-.297,1.04),(.033,.015,.034),red if x<.3 else alloy,.008)
    matrix=o.matrix_world.copy();o.parent=steering;o.matrix_world=matrix
steering.location.z -= .12
box('Dash_screen',(.36,-.545,1.075),(.37,.035,.16),dark,.016)
for name,pos in [('cockpit_camera',(.36,.10,1.225)),('dash_display',(.36,-.518,1.075)),('mirror_display',(0,-.65,1.30))]:
    bpy.ops.object.empty_add(location=pos);bpy.context.object.name=name

if variant == 'r6':
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(('Rear_wing','Wing_mount','Wing_endplate','Round_endurance_headlight','Headlight')):bpy.data.objects.remove(o,do_unlink=True)
if variant == 'v6':
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Rollcage'):bpy.data.objects.remove(o,do_unlink=True)
    for side in [-1,1]:rod('Canopy_support',(side*.48,-.31,1.25),(side*.48,.36,1.25),.04,dark)
if variant == 'v6':
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(('Hood_vent','Hood_stripe','Front_fender_aero','Prototype_LED_blade','B_pillar')):bpy.data.objects.remove(o,do_unlink=True)
        elif o.name.startswith('Headlight'):o.location.z=.49;o.location.y=-2.19
    for x in [-.16,.16]:
        for j in range(3):
            ya,_,_,za=rings[j];yb,_,_,zb=rings[j+1]
            mesh('Prototype_nose_livery',[(x-.065,ya,za+.008),(x+.065,ya,za+.008),(x+.065,yb,zb+.008),(x-.065,yb,zb+.008)],[(0,1,2,3)],lightpaint)
    for o in list(bpy.context.scene.objects):
        if o.parent:continue
        if o.name.startswith(('Dashboard','Dash_screen','dash_display','Centre_console','Door_liner','steering_wheel')):
            o.location.x*=.77;o.scale.x*=.77;o.location.z-=.13
        elif o.name.startswith(('Seat_back','Harness')):
            o.location.y-=.25;o.location.z-=.17;o.scale.z*=.75
        elif o.name.startswith(('Mirror','Mirror_arm')):o.location.z-=.16
        elif o.name.startswith('B_pillar'):o.scale.x*=.8;o.location.x*=.8

# Driver eyes stay below each roof, with clearance across the full camera frustum.
if variant == 'v6':
    bpy.data.objects['cockpit_camera'].location=(.27,-.10,1.075)
elif variant == 'r6':
    bpy.data.objects['cockpit_camera'].location=(.36,.10,1.40)
    bpy.data.objects['steering_wheel'].location.z+=.19
# Normalize each original design to its metre dimensions; preserve axle spacing.
bpy.context.view_layer.update()
verts_world=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
length=max(v.y for v in verts_world)-min(v.y for v in verts_world)
height=max(v.z for v in verts_world)
sx=spec['width']/2.11;sy=spec['length']/length;sz=spec['height']/height
for o in list(bpy.context.scene.objects):
    if o.parent:continue
    o.location.x*=sx;o.location.y*=sy;o.location.z*=sz
    o.scale.x*=sx;o.scale.y*=sy;o.scale.z*=sz
    if o.name.startswith('wheel_'):
        o.location.y=(-1 if 'front' in o.name else 1)*spec['wheelbase']/2
    if o.name.startswith('Wheelarch'):
        o.location.y=(-1 if o.location.y<0 else 1)*spec['wheelbase']/2
# Cut real wheel wells after the wheelbase is finalized; avoid tyres intersecting a solid body.
bpy.context.view_layer.update()
body=bpy.data.objects.get('GT_sculpted_body')
for pivot in [o for o in bpy.context.scene.objects if o.name.startswith('wheel_')]:
    center=pivot.matrix_world.translation.copy()
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.397,depth=.76,location=center,rotation=(0,math.pi/2,0))
    cutter=bpy.context.object;cutter.name='Wheelwell_cut_tool'
    cutter.scale=(sz,sy,sx)
    bpy.context.view_layer.objects.active=cutter
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=body.modifiers.new('Actual_wheel_well','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.context.view_layer.objects.active=body
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
# Pivot positions determine runtime camera and live dashboard placement.
bpy.context.view_layer.update()
metadata={name:list(bpy.data.objects[name].location) for name in ['cockpit_camera','dash_display','mirror_display']}
metadata['dimensions']=spec
(OUT/(spec['asset']+'.json')).write_text(json.dumps(metadata,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/('art/source_blender/'+spec['asset']+'.blend')))
bpy.ops.export_scene.gltf(filepath=str(OUT/(spec['asset']+'.glb')),export_format='GLB',use_selection=True)

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(mat('Preview_floor',(.32,.39,.35),.9))
scene.world.color=(.45,.50,.6)
bpy.ops.object.light_add(type='AREA',location=(-4,-6,9))
bpy.context.object.data.energy=1800;bpy.context.object.data.size=6
bpy.ops.object.light_add(type='AREA',location=(5,3,5))
bpy.context.object.data.energy=1200;bpy.context.object.data.size=4
bpy.ops.object.camera_add(location=(6,-8,4.5))
camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,.7))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=6.8
scene.camera=camera;scene.render.resolution_x=1400;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.filepath=str(ROOT/('art/previews/'+spec['asset']+'.png'))
bpy.ops.render.render(write_still=True)
print('GT BUILD COMPLETE')
