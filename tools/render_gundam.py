# Renders the Gundam from Gundam_2D_Sprites.blend as top-down sprites and packs them into a sheet.
# Usage (never saves the .blend):
#   blender -b "path/to/Gundam_2D_Sprites.blend" --python tools/render_gundam.py
import bpy, math, os, json, sys
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(PROJECT, "assets", "raw", "gundam")
SHEET = os.path.join(PROJECT, "assets", "sprites", "gundam_sheet.png")
FRAMES_TRES = os.path.join(PROJECT, "assets", "sprites", "gundam_frames.tres")
META = os.path.join(PROJECT, "assets", "sprites", "gundam_meta.json")
os.makedirs(RAW, exist_ok=True)

CELL = 256
ORTHO = 1.25
# name: (action, frame count, loop, fps)
ANIMS = [
    ("idle", "Hover_Idle", 8, True, 8),
    ("boost", "Boost_Loop", 6, True, 12),
    ("bank_left", "Bank_Left", 6, True, 10),
    ("bank_right", "Bank_Right", 6, True, 10),
    ("dash", "Dash_Forward", 6, False, 18),
    ("fire", "Rifle_Fire", 4, True, 16),
    ("aim", "Aim_Rifle", 6, False, 14),
]
# Frames already in assets/raw/gundam are reused (delete them or pass --force to re-render).
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
center = root.matrix_world.translation.copy()
cam.data.type = "ORTHO"
cam.data.ortho_scale = ORTHO
cam.location = center + Vector((0, 0, 6))
cam.rotation_euler = (0, 0, math.pi)  # straight down, mech's front (-Y) points up the image
s.camera = cam


def project_px(world_co):
    v = world_to_camera_view(s, cam, world_co)
    return [v.x * CELL, (1 - v.y) * CELL]  # Godot-style: origin top-left


def eval_verts(name):
    dg = bpy.context.evaluated_depsgraph_get()
    ob = bpy.data.objects[name].evaluated_get(dg)
    me = ob.to_mesh()
    co = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    ob.to_mesh_clear()
    co = co.reshape(-1, 3)
    m = np.array(ob.matrix_world)
    return co @ m[:3, :3].T + m[:3, 3]


rendered = {}
meta = {"cell": CELL, "anims": {}}
for name, action, count, loop, fps in ANIMS:
    act = bpy.data.actions[action]
    rig.animation_data.action = act
    start, end = act.frame_range
    span = (end - start) if loop else (end - start)
    files = []
    for i in range(count):
        f = start + (span * i / count if loop else span * i / max(count - 1, 1))
        s.frame_set(int(round(f)))
        path = os.path.join(RAW, f"{name}_{i}.png")
        if FORCE or not os.path.exists(path):
            s.render.filepath = path
            bpy.ops.render.render(write_still=True)
            print("RENDERED", name, i, "frame", int(round(f)))
        files.append(path)
        if name == "aim" and i == count - 1:
            rifle = eval_verts("Rifle")
            meta["aim_muzzle_px"] = project_px(Vector(rifle[np.argmin(rifle[:, 1])]))
        if name == "idle" and i == 0:
            rifle = eval_verts("Rifle")
            muzzle = rifle[np.argmin(rifle[:, 1])]  # furthest forward (-Y) point of the rifle
            pack = eval_verts("Armor_Backpack")
            back_y = np.percentile(pack[:, 1], 90)
            rear = pack[pack[:, 1] >= back_y]
            meta["muzzle_px"] = project_px(Vector(muzzle))
            meta["thruster_left_px"] = project_px(Vector(rear[np.argmin(rear[:, 0])]))
            meta["thruster_right_px"] = project_px(Vector(rear[np.argmax(rear[:, 0])]))
            meta["center_px"] = project_px(center)
    rendered[name] = files
    meta["anims"][name] = {"count": count, "loop": loop, "fps": fps}

# Pack into a sheet: one row per animation.
cols = max(c for _, _, c, _, _ in ANIMS)
rows = len(ANIMS)
sheet = np.zeros((rows * CELL, cols * CELL, 4), dtype=np.float32)
for r, (name, *_rest) in enumerate(ANIMS):
    for c, path in enumerate(rendered[name]):
        img = bpy.data.images.load(path)
        px = np.empty(CELL * CELL * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(CELL, CELL, 4)[::-1]  # Blender rows are bottom-up
        sheet[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = px
        bpy.data.images.remove(img)
out = bpy.data.images.new("gundam_sheet", cols * CELL, rows * CELL, alpha=True)
out.alpha_mode = "STRAIGHT"
out.pixels.foreach_set(sheet[::-1].ravel())
out.filepath_raw = SHEET
out.file_format = "PNG"
out.save()
print("SHEET", SHEET, cols * CELL, rows * CELL)

# SpriteFrames resource referencing regions of the sheet.
subs, anims = [], []
for r, (name, _a, count, loop, fps) in enumerate(ANIMS):
    frames = []
    for c in range(count):
        sid = f"{name}_{c}"
        subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                    f'region = Rect2({c * CELL}, {r * CELL}, {CELL}, {CELL})\n')
        frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
    anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                 % (", ".join(frames), "true" if loop else "false", name, fps))
with open(FRAMES_TRES, "w", encoding="utf-8") as fh:
    fh.write('[gd_resource type="SpriteFrames" format=3]\n\n')
    fh.write('[ext_resource type="Texture2D" path="res://assets/sprites/gundam_sheet.png" id="1"]\n\n')
    fh.write("\n".join(subs))
    fh.write("\n[resource]\nanimations = [%s]\n" % ", ".join(anims))

with open(META, "w", encoding="utf-8") as fh:
    json.dump(meta, fh, indent=2)
print("META", json.dumps(meta))
