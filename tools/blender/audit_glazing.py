import bpy, json
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
def tree(obj):
 deps=bpy.context.evaluated_depsgraph_get();mesh=obj.evaluated_get(deps).to_mesh();verts=[obj.matrix_world@v.co for v in mesh.vertices];polys=[list(p.vertices) for p in mesh.polygons];out=BVHTree.FromPolygons(verts,polys);obj.evaluated_get(deps).to_mesh_clear();return out
results={}
for stem in ['VEH_V8_Muscle_GT','VEH_Rally_Hatch','VEH_Apex_Prototype']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source_blender'/(stem+'.blend')))
 glazing=[o for o in bpy.data.objects if o.type=='MESH' and ('Glasshouse' in o.name or o.name.startswith('Glass_'))]
 conflicts=[]
 for pane in glazing:
  glass=tree(pane)
  for o in bpy.data.objects:
   if o.type=='MESH' and o.name.startswith(('Seat_back','Harness','Rollcage','Dashboard','Dash_screen')) and glass.overlap(tree(o)):conflicts.append([pane.name,o.name])
 print('GLAZING AUDIT',stem,json.dumps(conflicts))

 results[stem]=conflicts
report=ROOT/'art/build_logs/glazing-audit.json'
report.write_text(json.dumps(results,indent=2),encoding='utf-8')
if any(results.values()):raise RuntimeError('Glazing intersects cabin parts')
print('GLAZING PASS: 3 vehicles, no cabin intersections')
