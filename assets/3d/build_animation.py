"""Build a poseable Kikki and key all 122 atlas poses in the connected Blender.
Run after opening kikki-3d-refined.blend. No external generator or API required.
"""
import bpy, math, os, sys, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'assets/3d'))
from catalog import SHEETS
source=next(s for s in bpy.data.scenes if s.name.startswith("Kikki • soft little companion") and "Cream tummy" in s.objects)
scene=bpy.data.scenes.new('Kikki • complete sprite animation'); bpy.context.window.scene=scene

def empty(name,parent=None):
    o=bpy.data.objects.new(name,None); scene.collection.objects.link(o); o.parent=parent; return o
rig=empty('Kikki pose root'); head=empty('Head pivot',rig); head.location.z=2.18
fur=source.objects['Pear-shaped body'].data.materials[0]; cream=source.objects['Cream tummy'].data.materials[0]
dark=source.objects['Tiny signature pout'].data.materials[0]
# Reuse the approved face, ears, crown and tail with their exact materials.
head_names=('Big round head','round ear','Peach inner ear','Heart-shaped','Glossy cocoa eye','Tiny eye sparkle','Rosy cheek','Nostril','Tiny signature pout','Crown hair','Soft hair tip')
for src in source.objects:
    if any(n in src.name for n in head_names):
        o=src.copy(); o.data=src.data.copy(); scene.collection.objects.link(o); o.parent=head; o.location.z-=2.18
    elif src.name.startswith(('Curling monkey tail','Tail rounded tip')):
        o=src.copy(); o.data=src.data.copy(); scene.collection.objects.link(o); o.parent=rig

def material(name,color,rough=.5,metal=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
yellow=material('Banana peel',(1,.61,.07)); banana_white=material('Banana fruit',(1,.89,.52))
phone_mat=material('Phone charcoal',(.045,.055,.07),.28); screen_mat=material('Screen glass',(.15,.32,.43),.2)
gold=material('Brass cymbals',(.72,.42,.08),.26,.72); red=material('Noodle bowl coral',(.62,.09,.055)); noodle_mat=material('Golden noodles',(.95,.65,.19))
white=material('Paper white',(.92,.9,.82)); ember=material('Warm ember',(.8,.12,.025)); smoke_mat=material('Soft smoke',(.7,.76,.77))

def uv(name,loc,scale,mat,parent=rig):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;o.parent=parent;o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def tube(name,pts,r,mat,parent=rig):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=16;c.bevel_depth=r;c.bevel_resolution=4
    s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
    for p,co in zip(s.bezier_points,pts):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    c.use_fill_caps=True
    o=bpy.data.objects.new(name,c);scene.collection.objects.link(o);o.parent=parent;o.data.materials.append(mat);return o

def box(name,loc,scale,mat,parent):
    bpy.ops.mesh.primitive_cube_add(size=2,location=loc);o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.parent=parent;o.data.materials.append(mat);m=o.modifiers.new('Rounded edges','BEVEL');m.width=.045;m.segments=4
    return o
body=uv('Soft torso',(0,0,.96),(.67,.49,.76),fur)
tummy=uv('Cream belly',(0,-.465,.94),(.44,.08,.47),cream)
for pts in [[(-.045,-.55,.80),(.045,-.55,.70)],[(-.045,-.55,.70),(.045,-.55,.80)]]:tube('Belly stitch',pts,.014,dark)
limbs={}
for side in (-1,1):
    arm=tube('Arm '+str(side),[(side*.38,-.04,1.36),(side*.56,-.16,1.22),(side*.69,-.32,.98),(side*.43,-.65,.74)],.165,fur)
    for p,r in zip(arm.data.splines[0].bezier_points,[1.18,1.08,.94,.68]):p.radius=r
    hand=empty('Hand '+str(side),rig)
    uv('Mitten palm',(0,0,0),(.14,.115,.17),cream,hand)
    uv('Mitten thumb',(-side*.12,-.015,.035),(.07,.08,.095),cream,hand)
    leg=tube('Bent leg '+str(side),[(side*.40,.02,.65),(side*.65,-.10,.43),(side*.65,-.48,.22)],.23,fur)
    foot=empty('Foot '+str(side),rig)
    uv('Foot body',(0,0,0),(.24,.36,.185),fur,foot)
    uv('Foot cream',(0,-.13,.145),(.17,.21,.055),cream,foot)
    limbs[side]=(arm,hand,leg,foot)
# Expressions use curves on the face, not a stretched image.
closed=[]
for side in (-1,1):closed.append(tube('Closed eyelid',[(side*.325-.10,-.698,.14),(side*.325,-.715,.11),(side*.325+.10,-.698,.14)],.022,dark,head))
tongue=uv('Tiny tongue',(0,-.755,-.17),(.06,.018,.08),material('Tongue pink',(.9,.3,.31)),head)
props={}
def prop(name):
    p=empty(name,rig);props[name]=p;return p
p=prop('banana');tube('Banana fruit',[(0,0,0),(.09,0,.25),(.02,0,.48)],.085,banana_white,p)
for s in (-1,1):tube('Peeled banana',[(0,0,.20),(s*.17,-.02,.12),(s*.22,0,-.08)],.055,yellow,p)
tube('Banana stem',[(0,0,0),(0,0,-.14)],.06,yellow,p)
p=prop('phone');box('Phone case',(0,0,0),(.16,.055,.28),phone_mat,p);box('Phone display',(0,-.058,0),(.135,.01,.235),screen_mat,p)
uv('Phone camera',(-.09,.06,.19),(.03,.012,.03),dark,p)
p=prop('gamepad');box('Controller center',(0,0,0),(.36,.10,.14),phone_mat,p)
for s in (-1,1):uv('Controller grip',(s*.29,0,-.10),(.14,.12,.20),phone_mat,p)
box('Dpad vertical',(-.18,-.115,.02),(.025,.018,.08),dark,p);box('Dpad horizontal',(-.18,-.115,.02),(.08,.018,.025),dark,p)
for x,z in [(.18,.07),(.25,0),(.11,0),(.18,-.07)]:uv('Gamepad button',(x,-.119,z),(.025,.015,.025),cream,p)
p=prop('tripod');box('Tripod phone',(0,0,1.25),(.15,.06,.25),phone_mat,p);box('Tripod display',(0,-.065,1.25),(.13,.01,.21),screen_mat,p)
tube('Tripod post',[(0,0,.15),(0,0,1.04)],.025,phone_mat,p)
for x,y in [(-.25,-.1),(.25,-.1),(0,.25)]:tube('Tripod leg',[(0,0,.5),(x,y,0)],.022,phone_mat,p)
for s in (-1,1):
    p=prop('cymbal'+str(s));uv('Brass plate',(0,0,0),(.34,.045,.34),gold,p);uv('Cymbal bell',(0,-.04,0),(.09,.065,.09),gold,p)
p=prop('bowl');uv('Noodle bowl',(0,0,0),(.34,.28,.20),red,p)
uv('Noodle surface',(0,-.015,.14),(.29,.24,.05),noodle_mat,p)
for j in range(5):tube('Noodle curl',[(-.20,j*.06-.14,.17),(-.05,j*.06-.12,.19),(.09,j*.06-.16,.17),(.21,j*.06-.13,.18)],.018,banana_white,p)
p=prop('chopsticks')
for x in (-.035,.035):tube('Chopstick',[(x,0,-.18),(x+.04,0,.33)],.013,gold,p)
tube('Lifted noodle',[(0,0,.02),(.05,0,-.16),(.02,0,-.36)],.018,noodle_mat,p)
p=prop('cigarette');tube('Cigarette',[(0,0,0),(.25,0,0)],.026,white,p);uv('Cigarette tip',(.25,0,0),(.027,.027,.027),ember,p)
p=prop('smoke');tube('Smoke curl',[(0,0,0),(.16,0,.16),(.06,.02,.32),(.22,0,.49)],.028,smoke_mat,p)
p=prop('hair');tube('Plucked hair',[(-.25,0,.1),(0,0,-.1),(.25,0,.1)],.022,dark,p)
p=prop('heart');tube('Hair heart',[(0,0,-.20),(-.23,0,.04),(-.16,0,.20),(0,0,.12),(.16,0,.20),(.23,0,.04),(0,0,-.20)],.022,dark,p)
# Copy the studio illumination but render only the character on transparent film.
for src in source.objects:
    if src.type=='LIGHT':o=src.copy();o.data=src.data.copy();scene.collection.objects.link(o)
scene.world=source.world.copy()
camera_data=bpy.data.cameras.new('Sprite orthographic camera');camera=bpy.data.objects.new('Sprite orthographic camera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
camera.location=(.75,-10,4.0);camera.rotation_euler=(Vector((0,0,1.65))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=5.4
scene.render.engine=source.render.engine;scene.render.film_transparent=True
scene.render.resolution_x=627;scene.render.resolution_y=627;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
# Every property that can change is keyed to make the .blend self-contained.
def descendants(o):
    return [o]+[c for child in o.children for c in descendants(child)]
head_eyes=[o for o in head.children if o.name.startswith(('Glossy cocoa eye','Tiny eye sparkle'))]
def visibility(o,visible):
    for c in descendants(o):c.hide_render=not visible

def set_arm(side,wrist,elbow=None):
    arm,hand,_,_=limbs[side]
    shoulder=Vector((side*.38,-.04,1.36))
    wrist=Vector(wrist)
    if elbow is None:
        elbow=(side*max(.69,abs(wrist.x)*.85),-.30,1.0+max(0,wrist.z-1.55)*.65)
    elbow=Vector(elbow)
    upper=shoulder.lerp(elbow,.45); upper.x+=side*.035
    for p,co in zip(arm.data.splines[0].bezier_points,[shoulder,upper,elbow,wrist]):p.co=co
    direction=(wrist-elbow).normalized()
    hand.location=wrist+direction*.045
    hand.rotation_euler=direction.to_track_quat('Z','Y').to_euler()

def set_leg(side,foot,knee=None):
    _,_,leg,f=limbs[side]
    for p,co in zip(leg.data.splines[0].bezier_points,[(side*.40,0,.65),knee or (side*.65,-.12,.39),foot]):p.co=co
    f.location=foot;f.rotation_euler=(0,0,side*.12)

def show(name,loc,rot=(0,0,0)):
    p=props[name];visibility(p,True);p.location=loc;p.rotation_euler=rot

def pose(key,i):
    rig.location=(0,0,0);rig.rotation_euler=(0,0,0);rig.scale=(1,1,1)
    head.rotation_euler=(0,0,0);head.location=(0,0,2.18)
    for o in descendants(rig):o.hide_render=False
    for p in props.values():visibility(p,False);p.scale=(1,1,1)
    for o in closed+[tongue]:visibility(o,False)
    for side in (-1,1):set_arm(side,(side*.43,-.65,.74));set_leg(side,(side*.65,-.48,.22))
    mode=None;blink=False;wink=False;lying=0;standing=False
    if key in ('base','blink','look','playful'):mode=i;blink=key=='blink';wink=key=='playful'
    if key=='rest':mode=[2,2,1,1,0,0][i]
    if mode==0:
        hand=(.43,-.78,1.34 if key!='rest' or i==5 else 1.82);set_arm(1,hand);show('banana',(.43,-.88,hand[2]+.12))
    if mode==1:
        lying=-65;set_arm(-1,(-.42,-.85,1.9));set_arm(1,(.32,-.85,1.88));show('phone',(-.06,-.99,2.08));set_leg(1,(.60,-.75,.55));set_leg(-1,(-.48,-.65,.58))
    if mode==2:
        lying=-85;blink=True;set_arm(-1,(-.48,-.65,1.72));set_arm(1,(.12,-.70,1.62));set_leg(-1,(-.42,-.50,.45));set_leg(1,(.38,-.50,.48))
    if mode==3:
        set_arm(-1,(-.39,-.81,1.06));set_arm(1,(.39,-.81,1.06));show('gamepad',(0,-.87,1.10))
    if key=='look':head.rotation_euler[2]=-.10;head.rotation_euler[0]=-.07
    if key=='playful':head.rotation_euler[1]=.10;visibility(tongue,i==3)
    if key=='rest':
        head.rotation_euler[1]=.07 if i%2==0 else -.07
        if i==0:set_arm(1,(.1,-.7,2.0))
        if i==3:set_arm(-1,(-.5,-.7,1.5));show('phone',(.15,-.95,1.75))
    if key in ('walk','glance','walkPose'):
        standing=True;phase=2*math.pi*i/8 if key!='walkPose' else [0,1,3,0][i]
        rig.rotation_euler[2]=-.65 if key!='walkPose' else -.2
        for s in (-1,1):
            swing=math.sin(phase)*s
            set_leg(s,(s*.40,-.18+.30*swing,-.32+max(0,swing)*.12),(s*.43,.04,.10))
            set_arm(s,(s*.64,-.25-.25*swing,.80))
        if key=='glance':head.rotation_euler[2]=.65
        if key=='walkPose' and i==0:
            set_arm(-1,(-.9,-.1,2.4));set_arm(1,(.9,-.1,2.4))
        if key=='walkPose' and i==3:standing=False
    if key=='back':rig.rotation_euler[2]=math.pi;head.rotation_euler[2]=[0,-.5,-1.4,-1.4][i];blink=i==3
    if key in ('lift','liftPose'):
        if key=='liftPose' and i==3:
            rig.scale.z=.92;head.rotation_euler[0]=.12
        else:
            phase=i*math.pi/4
            for s in (-1,1):
                set_arm(s,(s*.9,-.12,1.15+.12*math.cos(phase)))
                set_leg(s,(s*(.40+.14*math.sin(phase)),-.16+.2*s*math.sin(phase),-.45+.16*s*math.cos(phase)),(s*.43,0,.12))
            head.rotation_euler[1]=.05*math.sin(phase)
    if key in ('drop','pickup'):
        lying=-65
        set_arm(-1,(-.5,-.7,1.80));set_arm(1,(.42,-.8,1.95));set_leg(1,(.60,-.75,.55));set_leg(-1,(-.48,-.65,.58))
        if key=='drop' and i==1:
            for o in descendants(rig):o.hide_render=True
            show('phone',(-.06,-1,2.15))
        elif key=='drop' and i==2:show('phone',(0,-.85,2.45),(.2,0,.35));blink=True
        elif key=='pickup':
            wrist=[(.4,-.8,.60),(.4,-.8,.90),(.3,-.85,1.4),(.2,-.9,1.9)][i]
            set_arm(1,wrist);show('phone',wrist)
    if key=='transition':
        lying=[0,-15,-30,-48,-62,-65,-65,-72,-78,-82,-85,-85][i]
        if i in (5,6):
            set_arm(1,(.30,-.8,1.85 if i==5 else 1.5));show('phone',(.2,-.96,2 if i==5 else 1.65))
        if i>=8:set_arm(-1,(-.45,-.65,1.72));set_arm(1,(.1,-.7,1.55));blink=i>=9
        set_leg(1,(.60,-.65,.45));set_leg(-1,(-.48,-.65,.45))
    if key=='camera' and i<4:
        wrist=[(.65,-.6,1.65),(1,-.65,2.3),(1,-.65,2.3),(.5,-.8,1.2)][i]
        set_arm(1,wrist);show('phone',(wrist[0],wrist[1]-.05,wrist[2]+.22))
        if i in (1,2):set_arm(-1,(-.65,-.7,2.1));wink=i==2
    if key=='reels' or key=='camera' and i>=4:
        standing=True;show('tripod',(-1.55,.05,-.48))
        j=i%4;style=-1 if key=='camera' else i//4
        for s in (-1,1):set_leg(s,(s*.42,-.18,-.32),(s*.43,.02,.1))
        if style==-1:
            set_arm(-1,(-.8,-.2,2.35 if j==1 else .95));set_arm(1,(.8,-.2,2.35 if j==2 else .95));head.rotation_euler[1]=[0,-.15,.15,0][j]
            if j==3:set_arm(-1,(-.57,-.7,2.03));set_arm(1,(.57,-.7,2.03))
        if style==0:
            set_arm(-1,(-.62,-.65,1.22+(j==1)*.3));set_arm(1,(.62,-.65,1.22+(j==2)*.3));head.rotation_euler[1]=[0,-.12,.12,0][j]
        if style==1:
            for s in (-1,1):set_arm(s,(s*.65,-.36,.9));set_leg(s,(s*.43,-.2-(.25 if j==(1 if s<0 else 2) else 0),-.32),(s*.45,-.1,.1))
            head.rotation_euler[0]=.15 if j==3 else 0
        if style==2:
            for s in (-1,1):set_arm(s,(s*[.3,.55,.35,.2][j],-.75,[1.1,2.1,3.35,1.45][j]),(s*[.6,.8,1.0,.6][j],-.3,[1.1,1.6,2.65,1.2][j]))
            wink=j==3
    if key=='smoke':
        wrist=(.40,-.78,1.95 if i in (1,2) else 1.0);set_arm(1,wrist);show('cigarette',(wrist[0]-.1,wrist[1]-.04,wrist[2]+.1))
        if i==2:show('smoke',(.25,-.83,2.05))
    if key=='hairHeart':
        if i in (0,1,5):set_arm(1,(.15,-.15,3.3),(1,-.15,2.4))
        if i in (1,2,3,4):
            for o in head.children:
                if o.name.startswith(('Crown hair 3','Soft hair tip 3')):visibility(o,False)
        if i==1:show('hair',(.15,-.22,3.5))
        if i in (2,3,4):
            for s in (-1,1):set_arm(s,(s*.26,-.85,1.35 if i<4 else 1.6))
            show('hair' if i==2 else 'heart',(0,-.90,1.40 if i<4 else 1.65))
    if key=='noodles':
        show('bowl',(-.12,-.90,.80));set_arm(-1,(-.40,-.74,.83))
        wrist=(.45,-.8,[1.05,1.55,1.85,1.3,1.1,1.05][i]);set_arm(1,wrist);show('chopsticks',wrist,(0,-.5,0))
        if i>=3:head.rotation_euler[1]=.10*math.sin(i);visibility(tongue,True)
        if i==4:show('smoke',(.3,-.83,2.05))
    if key=='extra':
        if i<4:
            for s in (-1,1):
                wrist=(s*[.92,.48,.18,.98][i],-.80,1.28)
                set_arm(s,wrist);show('cymbal'+str(s),(wrist[0],-.90,1.30),(0,0,s*[.2,.9,1.45,.25][i]))
        else:
            lying=-85;blink=True
            for s in (-1,1):set_arm(s,(s*.35,-.65,2.25 if i in (5,6) else 1.65));set_leg(s,(s*.4,-.42,-.20 if i in (5,6) else .40))
    if blink or mode==2:
        for o in head_eyes:visibility(o,False)
        for o in closed:visibility(o,True)
    elif wink:
        # The left eyelid closes while the other eye stays round.
        for o in head_eyes:
            if o.location.x<0:visibility(o,False)
        visibility(closed[0],True)
    if lying:rig.rotation_euler[1]=math.radians(lying)
    # Ground the entire pose, using evaluated geometry (including curves).
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    visible=[o for o in descendants(rig) if o.type in ('MESH','CURVE') and not o.hide_render]
    coords=[]
    for obj in visible:
        evaluated=obj.evaluated_get(deps); mesh=evaluated.to_mesh()
        coords.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    if coords:
        minx=min(v.x for v in coords);maxx=max(v.x for v in coords);minz=min(v.z for v in coords)
        rig.location.x=-(minx+maxx)*.5;rig.location.z=-minz+.06
    # Phone-only layer uses the exact same layout as the phone-in-hand pose.
    if key=='drop' and i==1:rig.location=(1.0,0,.65)
    bpy.context.view_layer.update()

frames=[];frame=0
for key,source_name,count,cols,rows in SHEETS:
    for i in range(count):
        frame+=1;scene.frame_set(frame);pose(key,i)
        for o in descendants(rig):
            for path in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(data_path=path,frame=frame)
            if o.type=='CURVE':
                for s in o.data.splines:
                    for p in s.bezier_points:p.keyframe_insert(data_path='co',frame=frame)
        scene.timeline_markers.new(f'{key}-{i:02}',frame=frame)
        frames.append({'key':key,'index':i,'frame':frame,'source':source_name+'.png','file':f'{key}-{i:02}.png'})
scene.frame_start=1;scene.frame_end=frame;scene.frame_set(1)
out=ROOT/'outputs/kikki-3d/frames';out.mkdir(parents=True,exist_ok=True)
(ROOT/'assets/3d/pose-catalog.json').write_text(json.dumps(frames,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/3d/kikki-animation.blend'))
print(f'Built {frame} keyed poses for {len(SHEETS)} source atlases.')
