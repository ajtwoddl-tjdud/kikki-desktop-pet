"""Add real geometric midpoint poses for all seated/reclined transition edges."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
scene=bpy.context.scene
plan=json.loads((ROOT/'assets/3d/pose-catalog.json').read_text())
plan=[p for p in plan if p['key']!='transitionMid']
original={p['index']:p['frame'] for p in plan if p['key']=='transition'}
rig=scene.objects['Kikki pose root']
def descendants(o):return [o]+[c for child in o.children for c in descendants(child)]
objects=descendants(rig)
def snapshot(frame):
    scene.frame_set(frame)
    return {o.name:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy(),o.hide_render,
                   [[p.co.copy() for p in s.bezier_points] for s in o.data.splines] if o.type=='CURVE' else None) for o in objects}
for marker in list(scene.timeline_markers):
    if marker.name.startswith('transitionMid-'):scene.timeline_markers.remove(marker)
for i,(a,b) in enumerate([(i,i+1) for i in range(11)]+[(4,7),(4,6)]):
    A=snapshot(original[a]);B=snapshot(original[b]);frame=123+i;scene.frame_set(frame)
    for o in objects:
        x,y=A[o.name],B[o.name]
        o.location=x[0].lerp(y[0],.5);o.rotation_euler=tuple((a+b)*.5 for a,b in zip(x[1],y[1]));o.scale=x[2].lerp(y[2],.5)
        o.hide_render=x[3] or y[3]
        if o.type=='CURVE':
            for si,s in enumerate(o.data.splines):
                for pi,p in enumerate(s.bezier_points):p.co=x[4][si][pi].lerp(y[4][si][pi],.5)
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();z=[]
    for o in objects:
        if o.type in ('MESH','CURVE') and not o.hide_render:
            ev=o.evaluated_get(deps);mesh=ev.to_mesh();z.extend((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear()
    rig.location.z+=.06-min(z)
    for o in objects:
        for path in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(data_path=path,frame=frame)
        if o.type=='CURVE':
            for s in o.data.splines:
                for p in s.bezier_points:p.keyframe_insert(data_path='co',frame=frame)
    scene.timeline_markers.new(f'transitionMid-{i:02} ({a}-{b})',frame=frame)
    plan.append({'key':'transitionMid','index':i,'frame':frame,'source':None,'file':f'transitionMid-{i:02}.png','between':[a,b]})
scene.frame_end=135;scene.frame_set(1)
(ROOT/'assets/3d/pose-catalog.json').write_text(json.dumps(plan,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/3d/kikki-animation.blend'))
print('Added 13 geometric transition midpoints; 135 unique frames total.')
