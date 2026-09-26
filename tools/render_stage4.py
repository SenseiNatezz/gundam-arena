# Level 4 ("Cryo Reactor") enemies: frost drone, snow walker and the Cryo Titan boss.
# Usage: blender -b --factory-startup --python tools/render_stage4.py
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemy_kit import *  # noqa: F401,F403 - scene, materials, add/empty/clear/render_strip

SNOW = mat("snow_armor", (0.86, 0.9, 0.95), 0.25, 0.45)
FROST = mat("frost_metal", (0.45, 0.55, 0.66), 0.8, 0.3)
NAVY = mat("navy_panel", (0.1, 0.18, 0.3), 0.6, 0.35)
ICE = mat("ice_crystal", (0.55, 0.85, 1.0), 0.1, 0.08)
GLACIER = mat("glacier_stone", (0.16, 0.22, 0.3), 0.3, 0.6)
CYAN = mat("cryo_glow", (0.4, 0.95, 1.0), 0, 0.3, (0.25, 0.85, 1.0), 3.2)


# ---------- frost drone (front = -Y) ----------
clear()
add("uv_sphere", "body", (0, 0.02, 0.07), (0.16, 0.18, 0.09), material=SNOW, radius=1, segments=24, ring_count=12)
add("cube", "spine", (0, 0.06, 0.15), (0.04, 0.1, 0.02), material=NAVY, bevel=0.01)
add("cube", "visor", (0, -0.14, 0.1), (0.08, 0.03, 0.025), material=CYAN, bevel=0.01)
for sx in (-1, 1):
    add("cube", f"panel{sx}", (sx * 0.1, 0.02, 0.13), (0.04, 0.09, 0.012), material=ICE, bevel=0.008)
    add("cylinder", f"cannon{sx}", (sx * 0.08, -0.2, 0.05), (0.022, 0.022, 0.07), rot=(math.pi / 2, 0, 0), material=FROST, vertices=12)
    add("cylinder", f"muzzle{sx}", (sx * 0.08, -0.27, 0.05), (0.018, 0.018, 0.01), rot=(math.pi / 2, 0, 0), material=CYAN, vertices=12)
rotors = []
for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
    x, y = sx * 0.21, sy * 0.19
    add("cube", f"arm{i}", (x * 0.6, y * 0.6, 0.05), (0.06, 0.02, 0.016), rot=(0, 0, math.atan2(y, x)), material=FROST)
    add("torus", f"guard{i}", (x, y, 0.06), (1, 1, 1), material=SNOW, major_radius=0.085, minor_radius=0.012)
    hub = empty(f"rotor{i}", (x, y, 0.07))
    for b in range(2):
        add("cube", f"blade{i}{b}", (0, 0, 0), (0.075, 0.01, 0.003), rot=(0, 0, b * math.pi / 2), material=NAVY, parent=hub)
    rotors.append((hub, 1 if i in (0, 3) else -1))


def drone_frame(i):
    for hub, d in rotors:
        hub.rotation_euler.z = d * i * math.radians(22.5)


render_strip("frost_drone", 4, 192, 0.72, drone_frame)


# ---------- snow walker (front = -Y): four legs, snowball launcher on the back ----------
clear()
add("cube", "hull", (0, 0.02, 0.2), (0.22, 0.26, 0.09), material=SNOW, bevel=0.04)
add("cube", "stripe", (0, -0.05, 0.3), (0.2, 0.02, 0.006), material=NAVY)
add("cube", "cockpit", (0, -0.24, 0.22), (0.1, 0.06, 0.05), material=NAVY, bevel=0.02)
add("cube", "cockpit_glass", (0, -0.29, 0.25), (0.07, 0.015, 0.025), material=CYAN)
add("cylinder", "launcher", (0, 0.1, 0.34), (0.1, 0.1, 0.05), material=FROST, bevel=0.01, vertices=24)
add("cylinder", "launcher_mouth", (0, 0.1, 0.4), (0.07, 0.07, 0.01), material=NAVY, vertices=24)
add("uv_sphere", "snowball", (0, 0.1, 0.42), (0.055, 0.055, 0.04), material=SNOW, radius=1)
legs = []
for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
    hip = empty(f"hip{i}", (sx * 0.2, sy * 0.18, 0.18))
    hip.rotation_euler.z = math.atan2(sy, sx)
    add("cube", "thigh", (0.12, 0, 0.0), (0.12, 0.04, 0.04), material=FROST, bevel=0.01, parent=hip)
    add("uv_sphere", "knee", (0.24, 0, 0.0), (0.05, 0.05, 0.05), material=NAVY, radius=1, parent=hip)
    add("cube", "shin", (0.3, 0, -0.08), (0.08, 0.035, 0.035), rot=(0, 0.8, 0), material=SNOW, bevel=0.01, parent=hip)
    add("cylinder", "foot", (0.36, 0, -0.16), (0.05, 0.05, 0.015), material=FROST, vertices=12, parent=hip)
    legs.append((hip, math.atan2(sy, sx), i % 2))


def walker_frame(i):
    for hip, base, group in legs:
        hip.rotation_euler.z = base + math.radians(10) * (1 if (group + i) % 2 else -1)


render_strip("snow_walker", 2, 256, 1.2, walker_frame)


# ---------- Cryo Titan boss (front = -Y): crystalline golem ----------
clear()
add("uv_sphere", "torso", (0, 0.05, 0.35), (0.5, 0.42, 0.26), material=GLACIER, radius=1, segments=32, ring_count=16)
add("uv_sphere", "chest_plate", (0, -0.12, 0.5), (0.3, 0.22, 0.1), material=FROST, radius=1)
add("uv_sphere", "core", (0, -0.12, 0.6), (0.12, 0.12, 0.06), material=CYAN, radius=1)
add("torus", "core_ring", (0, -0.12, 0.58), (1, 1, 1), material=ICE, major_radius=0.16, minor_radius=0.03)
add("uv_sphere", "head", (0, -0.36, 0.56), (0.15, 0.13, 0.1), material=GLACIER, radius=1)
add("cube", "eyes", (0, -0.47, 0.6), (0.1, 0.012, 0.02), material=CYAN)
for k in range(-1, 2):
    add("cone", f"crown{k}", (k * 0.07, -0.33, 0.66), (0.035, 0.035, 0.12), rot=(-0.3, k * 0.35, 0), material=ICE, vertices=6)
for sx in (-1, 1):
    add("uv_sphere", f"shoulder{sx}", (sx * 0.55, 0.0, 0.5), (0.22, 0.24, 0.16), material=GLACIER, radius=1)
    # Jagged ice crystals erupting from the shoulders and back.
    for k, (dx, dy, h, tilt) in enumerate([(0.0, 0.05, 0.32, 0.3), (0.12, -0.08, 0.24, 0.5), (-0.1, 0.14, 0.22, -0.2)]):
        add("cone", f"crystal{sx}{k}", (sx * (0.55 + dx), dy, 0.62), (0.11, 0.11, h * 1.4), rot=(tilt, sx * 0.4, 0),
            material=ICE, vertices=6)
    add("uv_sphere", f"arm{sx}", (sx * 0.64, -0.36, 0.38), (0.11, 0.26, 0.11), rot=(0, 0, sx * 0.35), material=FROST, radius=1)
    add("uv_sphere", f"fist{sx}", (sx * 0.7, -0.7, 0.36), (0.16, 0.16, 0.13), material=GLACIER, radius=1)
    for k in range(3):
        add("cone", f"knuckle{sx}{k}", (sx * 0.7 + (k - 1) * 0.08, -0.84, 0.4), (0.04, 0.04, 0.12),
            rot=(math.pi / 2 + 0.3, 0, 0), material=ICE, vertices=6)
for k, (x, y, h) in enumerate([(0, 0.35, 0.4), (-0.18, 0.3, 0.3), (0.18, 0.3, 0.3), (0, 0.18, 0.28)]):
    add("cone", f"back_crystal{k}", (x, y, 0.58), (0.12, 0.12, h * 1.3), rot=(-0.4, 0, 0), material=ICE, vertices=6)
render_strip("cryo_titan", 1, 576, 2.6, lambda i: None)
print("STAGE4 DONE")
