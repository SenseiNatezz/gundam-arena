# Builds simple enemy models procedurally and renders them as top-down sprite strips.
# Usage: blender -b --factory-startup --python tools/render_enemies.py
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


# ---------- scout drone (front = -Y, faces down the screen) ----------
clear()
add("cylinder", "chassis", (0, 0, 0.03), (0.15, 0.17, 0.05), material=GUN, bevel=0.02, vertices=8)
add("uv_sphere", "shell", (0, 0.03, 0.07), (0.13, 0.13, 0.07), material=RED, radius=1, segments=24, ring_count=12)
add("cube", "vent", (0, 0.1, 0.12), (0.05, 0.025, 0.02), material=DARK, bevel=0.008)
add("cube", "visor", (0, -0.13, 0.07), (0.07, 0.035, 0.03), material=DARK, bevel=0.01)
add("uv_sphere", "eye", (0, -0.16, 0.08), (0.035, 0.02, 0.02), material=GLOW_R, radius=1)
for sx in (-1, 1):
    add("cylinder", f"gun{sx}", (sx * 0.07, -0.21, 0.03), (0.016, 0.016, 0.06), rot=(math.pi / 2, 0, 0), material=STEEL, vertices=10)
rotors = []
for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
    x, y = sx * 0.21, sy * 0.19
    add("cube", f"arm{i}", (x * 0.6, y * 0.6, 0.04), (0.06, 0.022, 0.018), rot=(0, 0, math.atan2(y, x)), material=RED, bevel=0.006)
    add("torus", f"guard{i}", (x, y, 0.05), (1, 1, 1), material=GUN, major_radius=0.085, minor_radius=0.011)
    add("cylinder", f"hub{i}", (x, y, 0.07), (0.02, 0.02, 0.02), material=STEEL, vertices=12)
    hub = empty(f"rotor{i}", (x, y, 0.06))
    for b in range(2):
        add("cube", f"blade{i}{b}", (0, 0, 0), (0.075, 0.01, 0.003), rot=(0, 0, b * math.pi / 2), material=STEEL, parent=hub)
    rotors.append((hub, 1 if i in (0, 3) else -1))


def drone_frame(i):
    for hub, d in rotors:
        hub.rotation_euler.z = d * i * math.radians(22.5)


render_strip("drone", 4, 192, 0.72, drone_frame)

# ---------- gunship ----------
clear()
add("uv_sphere", "hull", (0, 0.02, 0.06), (0.15, 0.42, 0.08), material=GUN, radius=1, segments=32, ring_count=16)
add("uv_sphere", "armor", (0, 0.1, 0.1), (0.1, 0.26, 0.05), material=RED, radius=1, segments=32, ring_count=16)
add("cube", "armor_slit", (0, 0.12, 0.15), (0.015, 0.16, 0.006), material=DARK)
add("uv_sphere", "canopy", (0, -0.24, 0.1), (0.06, 0.1, 0.04), material=DARK, radius=1)
add("uv_sphere", "sensor", (0, -0.3, 0.12), (0.03, 0.04, 0.02), material=GLOW_R, radius=1)
for sx in (-1, 1):
    add("cube", f"wing{sx}", (sx * 0.28, 0.12, 0.05), (0.18, 0.11, 0.02), rot=(0, 0, sx * 0.22), material=RED, bevel=0.03)
    add("cube", f"wing_panel{sx}", (sx * 0.28, 0.14, 0.072), (0.12, 0.06, 0.006), rot=(0, 0, sx * 0.22), material=GUN, bevel=0.01)
    add("cube", f"stripe{sx}", (sx * 0.29, 0.03, 0.072), (0.13, 0.01, 0.004), rot=(0, 0, sx * 0.22), material=HAZ)
    add("cylinder", f"pod{sx}", (sx * 0.46, 0.14, 0.07), (0.07, 0.07, 0.2), rot=(math.pi / 2, 0, 0), material=STEEL, bevel=0.02, vertices=24)
    add("cylinder", f"pod_band{sx}", (sx * 0.46, 0.05, 0.07), (0.075, 0.075, 0.03), rot=(math.pi / 2, 0, 0), material=DARK, vertices=24)
    add("cylinder", f"exhaust{sx}", (sx * 0.46, 0.35, 0.07), (0.05, 0.05, 0.012), rot=(math.pi / 2, 0, 0), material=GLOW_O, vertices=24)
    add("cylinder", f"cannon{sx}", (sx * 0.1, -0.52, 0.05), (0.02, 0.02, 0.18), rot=(math.pi / 2, 0, 0), material=DARK, vertices=12)
    add("cylinder", f"muzzle{sx}", (sx * 0.1, -0.7, 0.05), (0.028, 0.028, 0.025), rot=(math.pi / 2, 0, 0), material=STEEL, vertices=12)
add("cylinder", "rear_exhaust", (0, 0.44, 0.06), (0.06, 0.06, 0.012), rot=(math.pi / 2, 0, 0), material=GLOW_O, vertices=24)
render_strip("gunship", 1, 256, 1.6, lambda i: None)

# ---------- spider-mech boss ----------
clear()
add("cylinder", "body", (0, 0.05, 0.25), (0.46, 0.5, 0.14), material=GUN, bevel=0.04, vertices=8)
add("uv_sphere", "dome", (0, 0.1, 0.36), (0.33, 0.36, 0.14), material=RED, radius=1, segments=32, ring_count=16)
add("torus", "core_ring", (0, 0.1, 0.49), (1, 1, 1), material=GLOW_R, major_radius=0.12, minor_radius=0.025)
add("uv_sphere", "core", (0, 0.1, 0.49), (0.07, 0.07, 0.04), material=GLOW_R, radius=1)
for sx in (-1, 1):
    add("cube", f"plate{sx}", (sx * 0.3, 0.2, 0.4), (0.09, 0.2, 0.03), rot=(0, sx * 0.4, 0), material=STEEL, bevel=0.01)
    add("cube", f"haz{sx}", (sx * 0.2, 0.47, 0.33), (0.08, 0.03, 0.02), material=HAZ)
add("cube", "head", (0, -0.42, 0.3), (0.2, 0.16, 0.1), material=GUN, bevel=0.03)
add("cube", "brow", (0, -0.5, 0.39), (0.17, 0.06, 0.02), material=RED, bevel=0.01)
for ex, ey, r in ((-0.09, -0.57, 0.035), (0.09, -0.57, 0.035), (-0.04, -0.55, 0.025), (0.04, -0.55, 0.025)):
    add("uv_sphere", "eye", (ex, ey, 0.33), (r, r, r), material=GLOW_R, radius=1)
add("cylinder", "laser", (0, -0.75, 0.28), (0.07, 0.07, 0.22), rot=(math.pi / 2, 0, 0), material=STEEL, bevel=0.01, vertices=16)
add("cylinder", "laser_tip", (0, -0.98, 0.28), (0.055, 0.055, 0.02), rot=(math.pi / 2, 0, 0), material=GLOW_R, vertices=16)
for sx in (-1, 1):
    add("cylinder", f"side_gun{sx}", (sx * 0.34, -0.45, 0.25), (0.035, 0.035, 0.16), rot=(math.pi / 2, 0, 0), material=DARK, vertices=10)

legs = []
for side in (-1, 1):
    for k, ang in enumerate((-50, 0, 50)):
        hip = empty(f"hip{side}{k}", (side * 0.42, 0.05, 0.22))
        base = math.radians(ang) * side + (0 if side > 0 else math.pi)
        hip.rotation_euler.z = base
        upper = add("cube", "upper", (0.3, 0, 0.12), (0.3, 0.05, 0.045), rot=(0, -0.4, 0), material=RED, bevel=0.015, parent=hip)
        add("uv_sphere", "knee", (0.58, 0, 0.24), (0.07, 0.07, 0.07), material=STEEL, radius=1, parent=hip)
        add("cube", "lower", (0.8, 0, 0.05), (0.26, 0.04, 0.035), rot=(0, 0.75, 0), material=GUN, bevel=0.012, parent=hip)
        add("cone", "foot", (1.02, 0, -0.14), (0.05, 0.05, 0.08), rot=(math.pi, 0, 0), material=DARK, parent=hip)
        legs.append((hip, base, (k + (side > 0)) % 2))


def boss_frame(i):
    phase = math.sin(i / 4 * math.tau)
    for hip, base, group in legs:
        hip.rotation_euler.z = base + math.radians(9) * phase * (1 if group else -1)


render_strip("boss", 4, 512, 3.1, boss_frame)
print("ENEMIES DONE")
