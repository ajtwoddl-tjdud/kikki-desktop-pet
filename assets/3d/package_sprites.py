"""Assemble Blender renders into runtime frames and compatible atlas copies.
Run: uv run --with pillow python assets/3d/package_sprites.py
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from catalog import SHEETS, cells
ROOT=Path(__file__).resolve().parents[2]
RAW=ROOT/'outputs/kikki-3d/frames'; OUT=ROOT/'assets/rendered-3d'
OUT.mkdir(exist_ok=True);(OUT/'frames').mkdir(exist_ok=True);(OUT/'atlases').mkdir(exist_ok=True)
images={}; boxes={}
FRAME_SHEETS=SHEETS+[("transitionMid",None,13,0,0)]+[("walkSmooth",None,32,0,0),("glanceSmooth",None,32,0,0),("phoneSmooth",None,24,0,0),("heartSmooth",None,21,0,0),("pickupSmooth",None,13,0,0)]
for key,source,count,cols,rows in FRAME_SHEETS:
    for i in range(count):
        name=f'{key}-{i:02}.png'; im=Image.open(RAW/name).convert('RGBA')
        box=im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
        if not box or min(box[:2])<=0 or box[2]>=im.width or box[3]>=im.height:raise ValueError(f'Empty/clipped render: {name} {box}')
        images[name]=im;boxes[name]=box
# Use a fixed scale per animation family, never auto-size each animation frame.
families={k:('locomotion' if k in ('walk','glance','walkPose','walkSmooth','glanceSmooth') else 'lift' if k in ('lift','liftPose') else 'standard') for k,*_ in FRAME_SHEETS}
scales={}
for family in set(families.values()):
    selected=[box for n,box in boxes.items() if families[n.rsplit('-',1)[0]]==family and n!='drop-01.png']
    scales[family]=min(1.14,540/max(b[2]-b[0] for b in selected),(500 if family=='locomotion' else 520)/max(b[3]-b[1] for b in selected))
# Gait frames share one crop/origin, so silhouette changes cannot slide the body.
gait_keys={'walk','glance','walkSmooth','glanceSmooth'}
gait_boxes=[b for n,b in boxes.items() if n.rsplit('-',1)[0] in gait_keys]
gait_box=(min(b[0] for b in gait_boxes),min(b[1] for b in gait_boxes),max(b[2] for b in gait_boxes),max(b[3] for b in gait_boxes))
manifest={'version':1,'renderer':'Blender EEVEE','frameSize':627,'sheets':{},'atlases':[]}
for key,source,count,cols,rows in FRAME_SHEETS:
    paths=[]
    for i in range(count):
        name=f'{key}-{i:02}.png';im=images[name];b=boxes[name];scale=scales[families[key]]
        if key in gait_keys:b=gait_box
        cropped=im.crop(b);size=(max(1,round(cropped.width*scale)),max(1,round(cropped.height*scale)))
        thumb=cropped.resize(size,Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(627,627))
        x=(627-thumb.width)//2;y=590-thumb.height
        if key in ('lift','liftPose') and not (key=='liftPose' and i==3):y=62
        if key=='drop' and i==1:
            # A small separate phone overlay; keep it above the reclined monkey's face.
            x=285;y=185
        canvas.alpha_composite(thumb,(x,y));canvas.save(OUT/'frames'/name)
        paths.append('frames/'+name)
    manifest['sheets'][key]=paths
    if source is None:continue
    original=Image.open(ROOT/'assets'/f'{source}.png')
    rects=cells(key,*original.size,cols,rows);atlas=Image.new('RGBA',original.size)
    # Match the original atlas's irregular gutters; keep a shared scale in each atlas.
    factor=min(min((r[2]-r[0])*.84/(boxes[f'{key}-{i:02}.png'][2]-boxes[f'{key}-{i:02}.png'][0]),(r[3]-r[1])*.84/(boxes[f'{key}-{i:02}.png'][3]-boxes[f'{key}-{i:02}.png'][1])) for i,r in enumerate(rects) if not(key=='drop' and i==1))
    for i,r in enumerate(rects):
        n=f'{key}-{i:02}.png';im=images[n].crop(boxes[n]);im=im.resize((max(1,round(im.width*factor)),max(1,round(im.height*factor))),Image.Resampling.LANCZOS)
        atlas.alpha_composite(im,(r[0]+(r[2]-r[0]-im.width)//2,r[3]-max(15,round((r[3]-r[1])*.07))-im.height))
    atlas.save(OUT/'atlases'/f'{source}.png')
    manifest['atlases'].append({'source':source+'.png','key':key,'count':count,'size':list(original.size),'cells':rects})
manifest['sheets']['landed']=[manifest['sheets']['liftPose'][3]]
manifest['frameCount']=sum(s[2] for s in FRAME_SHEETS)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
# Labeled contact sheet for all frames, deliberately outside the shipped bundle.
contact=Image.new('RGB',(8*180,((len(images)+7)//8)*196),(239,233,218));draw=ImageDraw.Draw(contact)
for idx,(name,im) in enumerate(images.items()):
    thumb=Image.open(OUT/'frames'/name);thumb.thumbnail((176,176),Image.Resampling.LANCZOS)
    x=(idx%8)*180;y=(idx//8)*196;contact.paste(thumb,(x,y),thumb);draw.text((x+5,y+176),name[:-4],fill=(57,39,27))
contact.save(ROOT/'outputs/kikki-3d/all-poses.jpg')
print(f'Packaged {manifest["frameCount"]} frames and {len(SHEETS)} atlases; scales={scales}')
