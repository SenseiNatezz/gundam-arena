# Builds simple enemy models procedurally and renders them as top-down sprite strips.
# Usage: blender -b --factory-startup --python tools/render_enemies.py
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemy_kit import *  # noqa: F401,F403 - scene, materials, add/empty/clear/render_strip


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
