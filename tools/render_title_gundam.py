# Renders the Gundam in a 3/4 hero view flying (Fly_Forward loop) for the title screen.
# Usage (never saves the .blend):
#   blender -b "path/to/Gundam_2D_Sprites.blend" --python tools/render_title_gundam.py
# Output: assets/title/gundam_hero_sheet.png (one row of COUNT frames).
import bpy, os, sys
import numpy as np
from mathutils import Vector

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(PROJECT, "assets", "raw", "title_gundam")
OUT = os.path.join(PROJECT, "assets", "title", "gundam_hero_sheet.png")
os.makedirs(RAW, exist_ok=True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
CELL = 640
COUNT = 12
FORCE = "--force" in sys.argv

s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = CELL
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
s.view_settings.exposure = 0.5
cam = bpy.data.objects["SpriteCamera"]
root = bpy.data.objects["SpriteRoot"]
rig = bpy.data.objects["Gundam_Rig"]
cam.data.type = "PERSP"
cam.data.lens = 50
center = root.matrix_world.translation + Vector((0, 0, 0.45))
cam.location = center + Vector((1.6, -2.6, 0.9)) * 0.72
cam.rotation_euler = (center - cam.location).to_track_quat('-Z', 'Y').to_euler()
s.camera = cam

act = bpy.data.actions["Fly_Forward"]
rig.animation_data.action = act
start, end = act.frame_range
paths = []
for i in range(COUNT):
    f = int(round(start + (end - start) * i / COUNT))  # loop: last frame != first
    path = os.path.join(RAW, f"fly_{i}.png")
    if FORCE or not os.path.exists(path):
        s.frame_set(f)
        s.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("RENDERED fly", i, "frame", f)
    paths.append(path)

sheet = np.zeros((CELL, COUNT * CELL, 4), dtype=np.float32)
for i, path in enumerate(paths):
    img = bpy.data.images.load(path)
    px = np.empty(CELL * CELL * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    sheet[:, i * CELL:(i + 1) * CELL] = px.reshape(CELL, CELL, 4)
    bpy.data.images.remove(img)
out = bpy.data.images.new("gundam_hero_sheet", COUNT * CELL, CELL, alpha=True)
out.alpha_mode = "STRAIGHT"
out.pixels.foreach_set(sheet.ravel())
out.filepath_raw = OUT
out.file_format = "PNG"
out.save()
print("SHEET", OUT)
