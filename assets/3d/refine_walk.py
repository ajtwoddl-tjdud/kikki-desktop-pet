"""Rebake only gait poses with fixed-length limbs and a grounded stance/swing cycle.
Run after add_action_frames.py. Other actions and their keyframes are untouched.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
scene=next(s for s in bpy.data.scenes if s.name.startswith('Kikki • complete sprite animation'))
bpy.context.window.scene=scene
rig=scene.objects['Kikki pose root'];head=scene.objects['Head pivot']
plan=json.loads((ROOT/'assets/3d/pose-catalog.json').read_text())
walk_keys={'walk','glance','walkSmooth','glanceSmooth'}
checks=[]
def key(o,frame):
 for attr in ('location','rotation_euler'):o.keyframe_insert(data_path=attr,frame=frame)
 if o.type=='CURVE':
  for sp in o.data.splines:
   for p in sp.bezier_points:p.keyframe_insert(data_path='co',frame=frame)
def joint(a,b,length):
 delta=b-a;d=delta.length
 assert d<2*length,('unreachable leg',d)
 mid=(a+b)*.5
 forward=Vector((0,-1,0));axis=delta.normalized()
 bend=(forward-axis*forward.dot(axis)).normalized()
 return mid+bend*math.sqrt(length*length-d*d/4)
for item in plan:
 if item['key'] not in walk_keys:continue
 f=item['frame'];scene.frame_set(f)
 count=32 if item['key'].endswith('Smooth') else 8
 phase=item['index']/count;theta=2*math.pi*phase
 bob=.022*(1-math.cos(theta*2))
 rig.location=(0,0,.47+bob);rig.rotation_euler=(0,0,-.85)
 # Small counter-motion, never a tilted pelvis that knocks the planted foot off the floor.
 head.rotation_euler=(.025,0,.85 if item['key'].startswith('glance') else .035*math.sin(theta))
 touched=[rig,head]
 for side in (-1,1):
  q=(phase+(0 if side==-1 else .5))%1
  if q<.62:
   u=q/.62;y=-.26+.52*u;lift=0;pitch=.10*math.sin(math.pi*u)
  else:
   u=(q-.62)/.38;y=.26-.52*(u*u*(3-2*u));lift=.18*math.sin(math.pi*u)**2;pitch=-.24*math.sin(math.pi*u)
  ankle=Vector((side*.36,y,-.20-bob+lift))
  hip=Vector((side*.36,0,.65));knee=joint(hip,ankle,.48)
  leg=scene.objects['Bent leg '+str(side)];foot=scene.objects['Foot '+str(side)]
  for p,co in zip(leg.data.splines[0].bezier_points,[hip,knee,ankle]):p.co=co
  foot.location=ankle;foot.rotation_euler=(pitch,0,side*.035)
  # Shoulder->elbow->wrist follow fixed-length segments; elbow always flexes forward.
  shoulder=Vector((side*.46,0,1.38))
  angle=.30*math.cos(2*math.pi*q)
  elbow=shoulder+Vector((side*.055,.49*math.sin(angle),-.49*math.cos(angle)))
  fore=angle-.24
  wrist=elbow+Vector((side*.025,.39*math.sin(fore),-.39*math.cos(fore)))
  arm=scene.objects['Arm '+str(side)];hand=scene.objects['Hand '+str(side)]
  for p,co in zip(arm.data.splines[0].bezier_points,[shoulder,shoulder.lerp(elbow,.48),elbow,wrist]):p.co=co
  direction=(wrist-elbow).normalized();hand.location=wrist+direction*.045;hand.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
  assert abs((knee-hip).length-.48)<1e-6 and abs((ankle-knee).length-.48)<1e-6
  checks.append({'frame':f,'side':side,'upper':(knee-hip).length,'lower':(ankle-knee).length,'stance':q<.62,'ankle_world_z':rig.location.z+ankle.z})
  touched += [leg,foot,arm,hand]
 for o in touched:key(o,f)
scene.frame_set(next(p['frame'] for p in plan if p['key']=='walkSmooth'))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/3d/kikki-animation.blend'))
(ROOT/'outputs/kikki-3d/walk-joints.json').write_text(json.dumps(checks,indent=2))
assert all(abs(c['ankle_world_z']-.27)<1e-6 for c in checks if c['stance'])
print('Baked 80 gait poses; 160 fixed-length leg and planted-ankle checks passed.')
