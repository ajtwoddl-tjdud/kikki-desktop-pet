"""Bake quaternion/curve in-betweens for walking, phone and hair-heart actions."""
import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
s=bpy.context.scene
plan=json.loads((ROOT/'assets/3d/pose-catalog.json').read_text())
keys={'walkSmooth','glanceSmooth','phoneSmooth','heartSmooth','pickupSmooth'}
plan=[p for p in plan if p['key'] not in keys]
def descendants(o):return [o]+[c for child in o.children for c in descendants(child)]
objects=descendants(s.objects['Kikki pose root'])
lookup={(p['key'],p['index']):p['frame'] for p in plan}
def snapshot(key,i):
 s.frame_set(lookup[key,i])
 return {o.name:(o.location.copy(),o.rotation_euler.to_quaternion(),o.scale.copy(),o.hide_render,[[p.co.copy() for p in sp.bezier_points] for sp in o.data.splines] if o.type=='CURVE' else None) for o in objects}
specs=[('walkSmooth','walk',8,4,True),('glanceSmooth','glance',8,4,True),('heartSmooth','hairHeart',6,4,False),('pickupSmooth','pickup',4,4,False)]
jobs=[]
for out,key,n,steps,loop in specs:
 snapshots=[snapshot(key,i) for i in range(n)]
 for i in range(n if loop else n-1):
  for j in range(steps):jobs.append((out,snapshots[i],snapshots[(i+1)%n],j/steps))
 if not loop:jobs.append((out,snapshots[-1],snapshots[-1],0))
a=snapshot('base',1);b=snapshot('rest',2)
for i in range(24):jobs.append(('phoneSmooth',a,b,(1-math.cos(i*2*math.pi/24))/2))
counts={}
for out,A,B,t in jobs:
 frame=len(plan)+1;s.frame_set(frame)
 # Linear gait phase maintains travel timing. Ease discrete gestures at their endpoints.
 u=t if out in ('walkSmooth','glanceSmooth','phoneSmooth') else t*t*(3-2*t)
 for o in objects:
  x,y=A[o.name],B[o.name]
  o.location=x[0].lerp(y[0],u);o.rotation_euler=x[1].slerp(y[1],u).to_euler();o.scale=x[2].lerp(y[2],u)
  o.hide_render=x[3] and y[3]
  if x[3]!=y[3]:
   # Grow/retract changed props instead of a missing object between key poses.
   o.scale*=max(.001,u if x[3] else 1-u)
   o.hide_render=(t==0 and x[3])
  if o.type=='CURVE':
   for si,sp in enumerate(o.data.splines):
    for pi,p in enumerate(sp.bezier_points):p.co=x[4][si][pi].lerp(y[4][si][pi],u)
  for path in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(data_path=path,frame=frame)
  if o.type=='CURVE':
   for sp in o.data.splines:
    for p in sp.bezier_points:p.keyframe_insert(data_path='co',frame=frame)
 i=counts.get(out,0);counts[out]=i+1
 plan.append(dict(key=out,index=i,frame=frame,source=None,file=f'{out}-{i:02}.png'))
s.frame_end=len(plan);s.frame_set(1)
(ROOT/'assets/3d/pose-catalog.json').write_text(json.dumps(plan,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/3d/kikki-animation.blend'))
print(counts,len(plan))
