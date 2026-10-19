"""Kikki collectible model. Run in Blender's Python editor or through Blender MCP."""
import bpy, math, os
from mathutils import Vector
OUT = '/Users/givemethatsewon/git/kikki-desktop-pet/outputs/kikki-3d'
os.makedirs(OUT, exist_ok=True)
scene = bpy.data.scenes.new('Kikki • soft little companion')
bpy.context.window.scene = scene

def mat(name, color, rough=.55):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough
    return m
fur=mat('Toffee • warm clay',(.46,.265,.125)); cream=mat('Vanilla • face and tummy',(.95,.75,.47))
pink=mat('Peach • inner ears',(.86,.40,.29)); dark=mat('Cocoa • expression',(.045,.018,.009),.32)
blush=mat('Soft rose cheeks',(.78,.31,.22)); white=mat('Eye glints',(1,.94,.8),.2)
base=mat('Mint porcelain',(.29,.52,.44)); floor=mat('Warm ivory studio',(.72,.68,.58))
root=bpy.data.objects.new('KIKKI • character',None); scene.collection.objects.link(root)

def uv(name,loc,scale,material,parent=root):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,location=loc)
    o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(material); o.parent=parent
    for p in o.data.polygons:p.use_smooth=True
    return o

def line(name,points,r,material,parent=root):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.bevel_depth=r; c.bevel_resolution=5
    s=c.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for p,co in zip(s.bezier_points,points):
        p.co=co; p.handle_left_type='AUTO'; p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c); scene.collection.objects.link(o); o.data.materials.append(material); o.parent=parent
    return o
uv('Pear-shaped body',(0,0,.94),(.70,.51,.79),fur)
uv('Big round head',(0,-.015,2.18),(1.0,.67,.91),fur)
for side in (-1,1):
    uv(('Left' if side<0 else 'Right')+' round ear',(side*1.0,0,2.19),(.46,.25,.51),fur)
    uv('Peach inner ear',(side*1.055,-.218,2.2),(.285,.065,.34),pink)
uv('Cream tummy',(0,-.466,.91),(.47,.10,.51),cream)
# Single continuous heart-shaped face patch, projected onto the round head.
outline=[(0,2.65),(.28,2.86),(.56,2.82),(.76,2.61),(.80,2.32),(.70,2.02),(.47,1.83),(0,1.79),(-.47,1.83),(-.70,2.02),(-.80,2.32),(-.76,2.61),(-.56,2.82),(-.28,2.86)]
# Catmull-Rom outline sampling.
pts=[]
for i in range(len(outline)):
    a=Vector(outline[(i-1)%len(outline)]); b=Vector(outline[i]); c=Vector(outline[(i+1)%len(outline)]); d=Vector(outline[(i+2)%len(outline)])
    for j in range(8):
        t=j/8; q=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t); pts.append(q)
n=len(pts); verts=[(0,-.736,2.3)]; faces=[]
for ring in range(1,13):
    t=ring/12
    for pt in pts:
        x=pt.x*t; z=2.3+(pt.y-2.3)*t
        y=-.015-.67*math.sqrt(max(.05,1-x*x-((z-2.18)/.91)**2))-.035-.022*(1-t*t)
        verts.append((x,y,z))
for i in range(n):faces.append((0,1+i,1+(i+1)%n))
for r in range(11):
    a=1+r*n; b=a+n
    for i in range(n): j=(i+1)%n; faces.append((a+i,b+i,b+j,a+j))
mesh=bpy.data.meshes.new('Continuous heart face surface'); mesh.from_pydata(verts,[],faces); mesh.update()
o=bpy.data.objects.new('Heart-shaped vanilla face',mesh); scene.collection.objects.link(o); o.parent=root; o.data.materials.append(cream)
for p in mesh.polygons:p.use_smooth=True
for side in (-1,1):
    uv('Glossy cocoa eye',(side*.325,-.697,2.32),(.10,.054,.115),dark)
    uv('Tiny eye sparkle',(side*.325-.026,-.745,2.356),(.022,.013,.025),white)
    uv('Rosy cheek',(side*.53,-.599,2.15),(.115,.016,.052),blush)
    uv('Nostril',(side*.047,-.737,2.19),(.018,.012,.019),dark)
    arm=uv('Chubby arm',(side*.57,-.28,1.03),(.21,.23,.46),fur); arm.rotation_euler[1]=side*.32
    uv('Little cream hand',(side*.49,-.49,.74),(.205,.15,.19),cream)
    foot=uv('Sitting foot',(side*.54,-.34,.30),(.30,.38,.25),fur); foot.rotation_euler[2]=side*.22
    uv('Cream sole',(side*.56,-.68,.32),(.22,.075,.185),cream)
    for k in (-1,0,1):uv('Round toe',(side*.56+k*.105,-.64,.435),(.064,.07,.068),cream)
line('Tiny signature pout',[(-.10,-.722,2.06),(0,-.745,2.105),(.10,-.722,2.06)],.023,dark)
line('Belly stitch A',[(-.047,-.571,.80),(.047,-.571,.70)],.016,dark)
line('Belly stitch B',[(-.047,-.571,.70),(.047,-.571,.80)],.016,dark)
line('Curling monkey tail',[(.48,.27,.52),(.98,.29,.42),(1.42,.25,.62),(1.58,.20,.95),(1.44,.15,1.18),(1.19,.12,1.13),(1.15,.10,.94)],.115,fur)
uv('Tail rounded tip',(1.15,.1,.94),(.115,.115,.115),fur)
for i,pts2 in enumerate([
 [(-.10,-.05,2.99),(-.20,-.06,3.23),(-.36,-.05,3.35)],
 [(0,-.02,3.02),(-.01,-.01,3.32),(-.09,0,3.48)],
 [(.09,0,3.01),(.19,.01,3.26),(.32,.03,3.36)]]):
    line('Crown hair '+str(i+1),pts2,.035,dark); uv('Soft hair tip '+str(i+1),pts2[-1],(.035,.035,.035),dark)
# Rounded collectible plinth.
bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=1.94,depth=.16,location=(.12,0,-.045))
o=bpy.context.object; o.name='Mint display plinth'; o.data.materials.append(base)
mod=o.modifiers.new('Soft ceramic edges','BEVEL'); mod.width=.09; mod.segments=4
for p in o.data.polygons:p.use_smooth=True
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.13)); bpy.context.object.name='Studio floor'; bpy.context.object.data.materials.append(floor)
world=bpy.data.worlds.new('Cream studio world'); world.use_nodes=True; scene.world=world
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND'); bg.inputs[0].default_value=(.72,.78,.86,1); bg.inputs[1].default_value=.35

def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
for name,loc,power,size,color in [('Large warm softbox',(-3,-4,6),500,4,(1,.84,.68)),('Gentle fill',(4,-2,4),300,3,(.78,.86,1)),('Rim glow',(1,3,5),600,3,(1,.87,.70))]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    o=bpy.data.objects.new(name,data); scene.collection.objects.link(o); o.location=loc; aim(o,(0,0,1.6))
data=bpy.data.cameras.new('Portrait camera'); cam=bpy.data.objects.new('Portrait camera',data); scene.collection.objects.link(cam)
cam.location=(3,-9,4.2); aim(cam,(.08,0,1.65)); data.type='ORTHO'; data.ortho_scale=4.8; scene.camera=cam
scene.render.resolution_x=1100; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=OUT+'/kikki-3d.png'
scene.render.film_transparent=False
for area in bpy.context.screen.areas:
    if area.type=='CONSOLE':area.type='VIEW_3D'
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.shading.color_type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=OUT+'/kikki-3d.blend')
print('Created Kikki:',len(scene.objects),'objects. Saved',OUT+'/kikki-3d.blend')
