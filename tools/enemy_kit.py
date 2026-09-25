# Shared Blender setup + helpers for the procedural enemy renders (render_enemies.py, render_stage2.py).
# Importing this resets the current scene to an empty, lit, top-down orthographic setup.
import bpy, math, os
import numpy as np

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(PROJECT, "assets", "raw", "enemies")
SPRITES = os.path.join(PROJECT, "assets", "sprites")
os.makedirs(RAW, exist_ok=True)

# ---------- scene ----------
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
s = bpy.context.scene
s.render.engine = "BLENDER_EEVEE"
s.render.film_transparent = True
s.render.image_settings.file_format = "PNG"
s.render.image_settings.color_mode = "RGBA"
s.view_settings.view_transform = "Standard"
s.view_settings.look = "None"
s.world = s.world or bpy.data.worlds.new("World")
s.world.use_nodes = True
s.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1)
s.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6

sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(50), math.radians(-30), math.radians(-30))
s.collection.objects.link(sun)
fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
fill.data.energy = 0.8
fill.data.color = (0.6, 0.75, 1.0)
fill.rotation_euler = (math.radians(-40), math.radians(30), 0)
s.collection.objects.link(fill)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.location = (0, 0, 10)
s.collection.objects.link(cam)
s.camera = cam


def mat(name, color, metallic=0.6, rough=0.35, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    else:
        # subtle grime so large flat panels are not a single flat colour
        nt = m.node_tree
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 18
        noise.inputs["Detail"].default_value = 6
        ramp = nt.nodes.new("ShaderNodeMix")
        ramp.data_type = "RGBA"
        ramp.inputs["A"].default_value = (*[c * 0.55 for c in color], 1)
        ramp.inputs["B"].default_value = (*[min(1, c * 1.25) for c in color], 1)
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Factor"])
        nt.links.new(ramp.outputs["Result"], b.inputs["Base Color"])
    return m


GUN = mat("gunmetal", (0.16, 0.17, 0.2), 0.85, 0.3)
STEEL = mat("steel", (0.5, 0.52, 0.56), 0.85, 0.28)
RED = mat("red_armor", (0.6, 0.05, 0.04), 0.45, 0.28)
DARK = mat("dark", (0.04, 0.04, 0.05), 0.6, 0.45)
HAZ = mat("hazard", (0.85, 0.58, 0.06), 0.2, 0.45)
GLOW_R = mat("glow_red", (1, 0.1, 0.05), 0, 0.3, (1, 0.06, 0.02), 4)
GLOW_O = mat("glow_orange", (1, 0.5, 0.1), 0, 0.3, (1, 0.42, 0.05), 4)


def add(kind, name, loc, scale=(1, 1, 1), rot=(0, 0, 0), material=GUN, bevel=0.0, parent=None, **kw):
    getattr(bpy.ops.mesh, f"primitive_{kind}_add")(location=loc, rotation=rot, **kw)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(material)
    if bevel:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
    if parent:
        ob.parent = parent
    return ob


def empty(name, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    s.collection.objects.link(e)
    return e


def clear():
    for ob in list(bpy.data.objects):
        if ob.type in ("MESH", "EMPTY"):
            bpy.data.objects.remove(ob, do_unlink=True)


def render_strip(name, frames, cell, ortho, setup_frame):
    s.render.resolution_x = s.render.resolution_y = cell
    cam.data.ortho_scale = ortho
    paths = []
    for i in range(frames):
        setup_frame(i)
        p = os.path.join(RAW, f"{name}_{i}.png")
        s.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    strip = np.zeros((cell, cell * frames, 4), dtype=np.float32)
    for i, p in enumerate(paths):
        img = bpy.data.images.load(p)
        px = np.empty(cell * cell * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        strip[:, i * cell:(i + 1) * cell] = px.reshape(cell, cell, 4)
        bpy.data.images.remove(img)
    out = bpy.data.images.new(name, cell * frames, cell, alpha=True)
    out.pixels.foreach_set(strip.ravel())
    out.filepath_raw = os.path.join(SPRITES, f"{name}.png")
    out.file_format = "PNG"
    out.save()
    print("STRIP", name, frames, cell)
