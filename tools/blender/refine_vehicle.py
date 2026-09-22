"""Structural refinement before normalization/export, using the builder context."""
import bmesh

def remove_prefixes(prefixes):
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(prefixes):bpy.data.objects.remove(o,do_unlink=True)

def normals(o):
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()

def subtract(body,cutter):
    bpy.context.view_layer.objects.active=body
    mod=body.modifiers.new('Recessed_detail','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)

# Continuous deck and shoulder loft, with connected character lines and material livery.
remove_prefixes(('GT_sculpted_body','Hood_stripe','Prototype_nose_livery','Hood_vent','Roof_stripe','Roof','Glasshouse','A_pillar','B_pillar','C_pillar','Wheelarch','Door_number_panel','Fender_gill','Rear_buttress','Side_air_scoop','Front_fender_aero','Prototype_LED_blade','Prototype_dorsal_fin'))
sections=[]
for j in range(len(rings)-1):
    a=Vector(rings[max(0,j-1)]);b=Vector(rings[j]);c=Vector(rings[j+1]);d=Vector(rings[min(len(rings)-1,j+2)])
    for k in range(5):
        t=k/5
        val=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
        sections.append(tuple(val))
sections.append(rings[-1])
verts=[];faces=[]
for y,w,base,top in sections:
    profile=[(-.86,base),(-.97,base+(top-base)*.12),(-1,base+(top-base)*.30),(-1,base+(top-base)*.70),(-.965,base+(top-base)*.92),(-.86,top+.005),(-.64,top+.014),(-.28,top+.023),(-.10,top+.026),(.10,top+.026),(.28,top+.023),(.64,top+.014),(.86,top+.005),(.965,base+(top-base)*.92),(1,base+(top-base)*.70),(1,base+(top-base)*.30),(.97,base+(top-base)*.12),(.86,base)]
    verts.extend((x*w,y,z) for x,z in profile)
N=len(profile)
for j in range(len(sections)-1):
    for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
faces.extend([tuple(range(N-1,-1,-1)),tuple(range((len(sections)-1)*N,len(sections)*N))])
body=mesh('GT_sculpted_body',verts,faces,paint);body.data.materials.append(lightpaint);normals(body)
for p in body.data.polygons:
    p.use_smooth=True
    center=sum((body.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
    # Paint belongs to the body surface, with no floating stripe geometry.
    if center.y<-.87 and p.index%N in [7,9]:p.material_index=1
# The interior is a real cavity below the glazing, not a solid slab through the cabin.
cabin=box('Cabin_cut_tool',(0,.20,1.08),(1.30 if variant!='v6' else 1.0,1.25,1.10),dark,.08)
subtract(body,cabin)

# Roof and four glazed openings share exact border vertices. Gaskets sit in their apertures.
def bilerp(q,u,t):return Vector(q[0]).lerp(Vector(q[1]),u).lerp(Vector(q[3]).lerp(Vector(q[2]),u),t)
def pane(name,q):
    outer=[Vector(p) for p in q]
    inner=[bilerp(q,.065,.08),bilerp(q,.935,.08),bilerp(q,.935,.92),bilerp(q,.065,.92)]
    n=(outer[1]-outer[0]).cross(outer[2]-outer[0]).normalized()
    frame=mesh('Integrated_'+name+'_surround',outer+inner,[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)],paint)
    gasket=[bilerp(inner,.018,.02),bilerp(inner,.982,.02),bilerp(inner,.982,.98),bilerp(inner,.018,.98)]
    mesh('Gasket_'+name,inner+gasket,[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)],dark)
    mesh('Glass_'+name,[p-n*.003 for p in gasket],[(0,1,2,3)],glass)
pane('windscreen',[v[i] for i in [0,1,3,2]])
pane('rear',[v[i] for i in [4,5,7,6]])
pane('left',[v[i] for i in [0,2,4,6]])
pane('right',[v[i] for i in [1,7,5,3]])
# Continuous sill flanges join window apertures to the shoulder below.
for name,ids in [('left',[0,6]),('right',[7,1]),('front',[1,0]),('rear',[6,7])]:
    a,b=[Vector(v[i]) for i in ids]
    mesh('Cabin_sill_'+name,[a,b,b-Vector((0,0,.14)),a-Vector((0,0,.14))],[(0,1,2,3)],paint)

roofverts=[];roof_faces=[]
xx=[-1,-.94,-.74,-.44,-.28,-.10,.10,.28,.44,.74,.94,1]
for j in range(6):
    t=j/5;y=v[2][1]*(1-t)+v[4][1]*t
    for x in xx:roofverts.append((x*abs(v[2][0]),y,v[2][2]+.034*(1-x*x)*math.sin(math.pi*t)))
for j in range(5):
    for k in range(len(xx)-1):roof_faces.append((j*len(xx)+k,j*len(xx)+k+1,(j+1)*len(xx)+k+1,(j+1)*len(xx)+k))
roof=mesh('Continuous_roof_panel',roofverts,roof_faces,paint);roof.data.materials.append(lightpaint);normals(roof)
for p in roof.data.polygons:
    p.use_smooth=True
    if p.index%(len(xx)-1) in [4,6]:p.material_index=1
solid=roof.modifiers.new('Roof_panel_thickness','SOLIDIFY');solid.thickness=.022
bpy.context.view_layer.objects.active=roof;bpy.ops.object.modifier_apply(modifier=solid.name)
# A narrow flush window divider, not an external rod across the door.
for side in [-1,1]:
    a=Vector(v[0 if side<0 else 1]);b=Vector(v[6 if side<0 else 7]);c=Vector(v[2 if side<0 else 3]);d=Vector(v[4 if side<0 else 5])
    rod('Window_divider',a.lerp(b,.58),c.lerp(d,.58),.035,dark)

# Car-specific, recessed light pockets. Their glass follows the fascia instead of hanging outside.
remove_prefixes(('Headlight','Tail_light','Vertical_tail_lamp','Rear_light_bar','Front_intake','Intake_vertical','V8_vertical_grille'))
for side in [-1,1]:
    z=.66 if variant=='v8' else .82 if variant=='r6' else .43
    x=side*(.60 if variant!='v6' else .53)
    cutter=box('Lamp_socket_tool',(x,-2.26,z),(.48,.22,.145),dark,.04);subtract(body,cutter)
    box('Recessed_headlight_housing',(x,-2.225,z),(.45,.045,.125),dark,.032)
    box('Recessed_LED_lens',(x,-2.251,z+.005),(.37,.018,.042),lamp,.014)
    for n in [-1,1]:box('LED_projector',(x+n*.10,-2.264,z-.015),(.06,.008,.044),lamp,.013)
    rear_z=.71 if variant=='v8' else .88 if variant=='r6' else .66
    cutter=box('Rear_lamp_socket_tool',(side*.60,2.265,rear_z),(.52,.20,.09),dark,.025);subtract(body,cutter)
    box('Inset_tail_housing',(side*.60,2.225,rear_z),(.48,.045,.075),dark,.02)
    box('Inset_tail_LED',(side*.60,2.252,rear_z),(.42,.012,.025),red,.009)
intake_z=.53 if variant!='v6' else .34
cutter=box('Intake_cut_tool',(0,-2.28,intake_z),(.90,.26,.19),dark,.045);subtract(body,cutter)
box('Recessed_radiator',(0,-2.205,intake_z),(.84,.018,.145),dark,.014)
for x in [i*.07-.35 for i in range(11)]:box('Radiator_fins',(x,-2.22,intake_z),(.012,.006,.13),alloy,.002)
# Proper brake discs, central fasteners and a beveled tyre shoulder.
for pivot in [o for o in bpy.data.objects if o.name.startswith('wheel_')]:
    side=-1 if 'left' in pivot.name else 1
    for name,radius,depth,x,m in [('Brake_disc',.205,.022,side*.10,alloy),('Centre_lock',.052,.035,side*.165,alloy)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,rotation=(0,math.pi/2,0))
        o=bpy.context.object;o.name=name;o.data.materials.append(m);o.parent=pivot;o.location=(x,0,0)
    for o in pivot.children:
        if o.name.startswith('Tyre'):
            bpy.context.view_layer.objects.active=o
            mod=o.modifiers.new('Rounded_tyre_shoulder','BEVEL');mod.width=.023;mod.segments=3
            bpy.ops.object.modifier_apply(modifier=mod.name)
# Fit the actual cabin parts beneath the glass planes (including seat and cage corners).
bpy.context.view_layer.update()
for o in list(bpy.data.objects):
    if o.type!='MESH' or not o.name.startswith(('Seat_back','Harness','Rollcage','Dashboard','Dash_screen')):continue
    inv=o.matrix_world.inverted()
    for vertex in o.data.vertices:
        p=o.matrix_world@vertex.co
        if p.y<v[2][1]:
            t=max(0,min(1,(p.y-v[0][1])/(v[2][1]-v[0][1])))
            ceiling=v[0][2]*(1-t)+v[2][2]*t
        elif p.y>v[4][1]:
            t=max(0,min(1,(p.y-v[4][1])/(v[6][1]-v[4][1])))
            ceiling=v[4][2]*(1-t)+v[6][2]*t
        else:ceiling=v[2][2]
        p.z=min(p.z,ceiling-.065)
        if o.name.startswith('Rollcage'):p.x*=.90
        if variant=='v6':p.x=max(-.40,min(.40,p.x))
        vertex.co=inv@p
    normals(o)
