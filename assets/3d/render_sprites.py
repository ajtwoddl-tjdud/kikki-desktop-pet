"""Re-render the checked-in animation with Blender (foreground or --background).
blender assets/3d/kikki-animation.blend --background --python assets/3d/render_sprites.py
Then run package_sprites.py using Pillow. Existing raw PNGs are overwritten.
"""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
plan=json.loads((ROOT/'assets/3d/pose-catalog.json').read_text())
scene=next(s for s in bpy.data.scenes if s.name.startswith('Kikki • complete sprite animation'))
bpy.context.window.scene=scene
output=ROOT/'outputs/kikki-3d/frames';output.mkdir(parents=True,exist_ok=True)
for item in plan:
    scene.frame_set(item['frame']);scene.render.filepath=str(output/item['file'])
    bpy.ops.render.render(write_still=True)
print(f'Rendered {len(plan)} frames to {output}')
