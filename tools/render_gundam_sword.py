# Renders the Gundam's Sword_Slash animation (energy sword in the left hand) as top-down sprites.
# Usage (never saves the .blend):
#   blender -b "path/to/Gundam_Sword_2D_Sprites.blend" --python tools/render_gundam_sword.py
# Output: assets/sprites/gundam_sword_sheet.png + gundam_sword_frames.tres (animation "slash").
# The Player merges the "slash" animation into its main SpriteFrames at runtime.
import bpy, math, os, sys
import numpy as np
from mathutils import Vector

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(PROJECT, "assets", "raw", "gundam_sword")
SHEET = os.path.join(PROJECT, "assets", "sprites", "gundam_sword_sheet.png")
FRAMES_TRES = os.path.join(PROJECT, "assets", "sprites", "gundam_sword_frames.tres")
os.makedirs(RAW, exist_ok=True)

# Same pixels-per-unit as the 256px / 1.25 ortho main sheet, on a bigger canvas so the blade fits.
CELL = 384
ORTHO = 1.25 * CELL / 256
ACTION = "Sword_Slash"
COUNT = 12
FPS = 24  # 12 frames over the 0.5s slash
FORCE = "--force" in sys.argv

s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = CELL
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
cam = bpy.data.objects["SpriteCamera"]
root = bpy.data.objects["SpriteRoot"]
rig = bpy.data.objects["Gundam_Rig"]
cam.data.type = "ORTHO"
cam.data.ortho_scale = ORTHO
cam.location = root.matrix_world.translation + Vector((0, 0, 6))
cam.rotation_euler = (0, 0, math.pi)  # straight down, front of the mech points up the image
s.camera = cam

act = bpy.data.actions[ACTION]
rig.animation_data.action = act
start, end = act.frame_range
paths = []
for i in range(COUNT):
    f = int(round(start + (end - start) * i / (COUNT - 1)))
    path = os.path.join(RAW, f"slash_{i}.png")
    if FORCE or not os.path.exists(path):
        s.frame_set(f)
        s.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("RENDERED slash", i, "frame", f)
    paths.append(path)

sheet = np.zeros((CELL, COUNT * CELL, 4), dtype=np.float32)
for i, path in enumerate(paths):
    img = bpy.data.images.load(path)
    px = np.empty(CELL * CELL * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    sheet[:, i * CELL:(i + 1) * CELL] = px.reshape(CELL, CELL, 4)  # both bottom-up: no flip needed
    bpy.data.images.remove(img)
out = bpy.data.images.new("gundam_sword_sheet", COUNT * CELL, CELL, alpha=True)
out.alpha_mode = "STRAIGHT"
out.pixels.foreach_set(sheet.ravel())
out.filepath_raw = SHEET
out.file_format = "PNG"
out.save()
print("SHEET", SHEET)

subs, frames = [], []
for i in range(COUNT):
    sid = f"slash_{i}"
    subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                f'region = Rect2({i * CELL}, 0, {CELL}, {CELL})\n')
    frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
with open(FRAMES_TRES, "w", encoding="utf-8") as fh:
    fh.write('[gd_resource type="SpriteFrames" format=3]\n\n')
    fh.write('[ext_resource type="Texture2D" path="res://assets/sprites/gundam_sword_sheet.png" id="1"]\n\n')
    fh.write("\n".join(subs))
    fh.write('\n[resource]\nanimations = [{\n"frames": [%s],\n"loop": false,\n"name": &"slash",\n"speed": %.1f\n}]\n'
             % (", ".join(frames), FPS))
print("FRAMES", FRAMES_TRES)
