"""Apply softer, connected seated limbs to the original Kikki Blender scene."""
import bpy, math
from mathutils import Vector
scene=bpy.context.scene
root=scene.objects['KIKKI • character']
fur=scene.objects['Pear-shaped body'].data.materials[0]
cream=scene.objects['Cream tummy'].data.materials[0]
for o in list(scene.objects):
    if o.name.startswith(('Chubby arm','Little cream hand','Sitting foot','Cream sole','Round toe')):
        bpy.data.objects.remove(o,do_unlink=True)

def oval(name,loc,scale,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=28,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(material)
    for p in o.data.polygons:p.use_smooth=True
    return o

def fuse(parts,name,voxel=.022):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.convert(target='MESH'); bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    m=o.modifiers.new('Continuous sculpted surface','REMESH'); m.mode='VOXEL'; m.voxel_size=voxel
    bpy.ops.object.modifier_apply(modifier=m.name)
    m=o.modifiers.new('Relax joins','SMOOTH'); m.factor=.75; m.iterations=12
    bpy.ops.object.modifier_apply(modifier=m.name)
    m=o.modifiers.new('Silky surface','SUBSURF'); m.levels=1; m.render_levels=1
    for p in o.data.polygons:p.use_smooth=True
    o.parent=root
    return o

parts=[scene.objects['Pear-shaped body']]
for side in (-1,1):
    # Soft shoulder, relaxed elbow and tapered wrist follow a gentle inward arc.
    control=[(side*.46,-.07,1.36,.23),(side*.60,-.20,1.17,.205),(side*.64,-.34,.97,.18),(side*.59,-.48,.81,.155),(side*.49,-.60,.69,.125)]
    for i in range(len(control)-1):
        a=control[i]; b=control[i+1]
        for j in range(8):
            t=j/8
            x,y,z,r=[a[k]*(1-t)+b[k]*t for k in range(4)]
            parts.append(oval('Arm sculpt',(x,y,z),(r,r,r),fur))
    # Thighs connect the hips to feet projecting forward on the ground.
    parts.append(oval('Bent haunch',(side*.55,.015,.48),(.35,.40,.38),fur))
    parts.append(oval('Bent shin',(side*.66,-.20,.29),(.26,.35,.23),fur))
    foot=oval('Long relaxed foot',(side*.67,-.48,.22),(.245,.43,.185),fur)
    foot.rotation_euler[2]=side*.17; parts.append(foot)
    handparts=[]
    palm=oval('Resting palm',(side*.445,-.675,.605),(.15,.12,.205),cream)
    palm.rotation_euler[1]=-side*.32; handparts.append(palm)
    handparts.append(oval('Small inward thumb',(side*.325,-.694,.64),(.080,.092,.109),cream))
    # Fingers form one mitten-like hand rather than separate beads.
    for k in range(3):
        handparts.append(oval('Soft fingertip',(side*(.365+k*.062),-.692,.455+abs(k-1)*.018),(.050,.087,.073),cream))
    fuse(handparts,('Left' if side<0 else 'Right')+' relaxed mitten',.013)
    patch=oval('Cream foot upper',(side*.67,-.58,.375),(.175,.25,.065),cream)
    patch.rotation_euler[0]=math.radians(12); patch.rotation_euler[2]=side*.17; patch.parent=root
fuse(parts,'Pear-shaped body')
scene.render.filepath='/Users/givemethatsewon/git/kikki-desktop-pet/outputs/kikki-3d/kikki-3d-refined.png'
bpy.ops.wm.save_as_mainfile(filepath='/Users/givemethatsewon/git/kikki-desktop-pet/outputs/kikki-3d/kikki-3d-refined.blend')
bpy.ops.render.render(write_still=True)
print('Refined arms, mitten hands, bent legs and grounded feet; saved and rendered.')
