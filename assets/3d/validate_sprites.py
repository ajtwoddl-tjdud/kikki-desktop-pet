"""Validate full source coverage, file integrity, alpha margins and runtime bindings."""
from pathlib import Path
import json
from PIL import Image
from catalog import SHEETS,cells
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/rendered-3d'
m=json.loads((OUT/'manifest.json').read_text())
assert m['version']==1 and m['frameCount']==257
assert {s[1]+'.png' for s in SHEETS}=={p.name for p in (ROOT/'assets').glob('*.png')}, 'Unconverted source atlas'
checks=0
for key,source,count,cols,rows in SHEETS:
    paths=m['sheets'][key];assert len(paths)==count
    for path in paths:
        with Image.open(OUT/path) as im:
            assert im.mode=='RGBA' and im.size==(627,627),path
            b=im.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
            assert b and b[0]>0 and b[1]>0 and b[2]<627 and b[3]<627,(path,b)
            checks+=1
    with Image.open(OUT/'atlases'/f'{source}.png') as im, Image.open(ROOT/'assets'/f'{source}.png') as original:
        assert im.size==original.size
        for rect in cells(key,*im.size,cols,rows):
            cell=im.crop(rect);b=cell.getchannel('A').getbbox()
            assert b and b[0]>0 and b[1]>0 and b[2]<cell.width and b[3]<cell.height,(source,rect,b)
            checks+=1
for path in [p for k in ('transitionMid','walkSmooth','glanceSmooth','phoneSmooth','heartSmooth','pickupSmooth') for p in m['sheets'][k]]:
    with Image.open(OUT/path) as im:
        b=im.getchannel('A').getbbox()
        assert im.size==(627,627) and b and b[0]>0 and b[1]>0 and b[2]<627 and b[3]<627,path
        checks+=1
assert len(m['sheets']['transitionMid'])==13
assert m['sheets']['landed']==[m['sheets']['liftPose'][3]]
assert len(list((OUT/'frames').glob('*.png')))==257
print(f'PASS: {checks} frame/cell checks; all 20 source atlases covered; 257 RGBA frames including 13 geometric midpoints.')
