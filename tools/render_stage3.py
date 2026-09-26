# Level 3 ("Volcanic Forge") enemies: heat drone and the Magma Forge Mech mini-boss.
# Usage: blender -b --factory-startup --python tools/render_stage3.py
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemy_kit import *  # noqa: F401,F403 - scene, materials, add/empty/clear/render_strip

BASALT = mat("basalt", (0.075, 0.068, 0.066), 0.2, 0.8)
IRON = mat("forge_iron", (0.26, 0.23, 0.21), 0.8, 0.35)
SOOT = mat("soot", (0.03, 0.028, 0.027), 0.4, 0.6)
LAVA = mat("lava", (1, 0.3, 0.03), 0, 0.3, (1, 0.22, 0.01), 2.2)
EMBER = mat("ember", (1, 0.5, 0.08), 0, 0.3, (1, 0.42, 0.04), 2.8)


# ---------- heat drone (front = -Y): charcoal body, two orange eyes, heat fins ----------
clear()
add("uv_sphere", "body", (0, 0.02, 0.08), (0.16, 0.18, 0.1), material=BASALT, radius=1, segments=24, ring_count=12)
add("cube", "brow", (0, -0.1, 0.13), (0.1, 0.035, 0.03), material=IRON, bevel=0.01)
for sx in (-1, 1):
    add("uv_sphere", f"eye{sx}", (sx * 0.055, -0.15, 0.1), (0.03, 0.025, 0.022), material=EMBER, radius=1)
    add("cube", f"fin{sx}", (sx * 0.2, 0.04, 0.07), (0.07, 0.11, 0.015), rot=(0, sx * 0.25, sx * 0.2), material=IRON, bevel=0.01)
    for k in range(3):
        add("cube", f"vent{sx}{k}", (sx * 0.2, -0.02 + k * 0.05, 0.088), (0.05, 0.008, 0.004), rot=(0, sx * 0.25, sx * 0.2), material=LAVA)
    add("cylinder", f"nozzle{sx}", (sx * 0.06, -0.19, 0.06), (0.022, 0.022, 0.04), rot=(math.pi / 2, 0, 0), material=SOOT, vertices=10)
add("torus", "exhaust_ring", (0, 0.17, 0.08), (1, 1, 1), material=LAVA, major_radius=0.05, minor_radius=0.012)
add("cube", "crack1", (0.05, 0.06, 0.17), (0.05, 0.006, 0.004), rot=(0, 0, 0.6), material=LAVA)
add("cube", "crack2", (-0.04, 0.09, 0.17), (0.04, 0.006, 0.004), rot=(0, 0, -0.4), material=LAVA)
render_strip("heat_drone", 1, 192, 0.66, lambda i: None)


# ---------- Magma Forge Mech (front = -Y) ----------
clear()
add("cube", "torso", (0, 0.05, 0.3), (0.42, 0.32, 0.22), material=BASALT, bevel=0.06)
add("cylinder", "furnace_rim", (0, -0.08, 0.53), (0.19, 0.19, 0.03), material=IRON, vertices=32)
add("cylinder", "furnace", (0, -0.08, 0.55), (0.15, 0.15, 0.02), material=LAVA, vertices=32)
for k in range(-2, 3):
    add("cube", f"grille{k}", (k * 0.055, -0.08, 0.575), (0.012, 0.15, 0.01), material=SOOT)
add("cube", "head", (0, -0.3, 0.46), (0.12, 0.09, 0.08), material=IRON, bevel=0.03)
add("cube", "visor", (0, -0.39, 0.48), (0.09, 0.012, 0.025), material=EMBER)
for sx in (-1, 1):
    add("uv_sphere", f"shoulder{sx}", (sx * 0.55, 0.02, 0.42), (0.22, 0.24, 0.16), material=IRON, radius=1, segments=24, ring_count=12)
    for k in range(3):
        add("cube", f"sh_vent{sx}{k}", (sx * 0.55, -0.06 + k * 0.08, 0.58), (0.13, 0.012, 0.006), material=LAVA)
    add("cube", f"forearm{sx}", (sx * 0.58, -0.38, 0.28), (0.1, 0.24, 0.1), material=BASALT, bevel=0.03)
    add("cube", f"fist{sx}", (sx * 0.6, -0.72, 0.3), (0.19, 0.16, 0.15), material=IRON, bevel=0.04)
    add("cube", f"fist_glow{sx}", (sx * 0.6, -0.86, 0.3), (0.15, 0.02, 0.1), material=LAVA)
    add("cylinder", f"stack{sx}", (sx * 0.22, 0.4, 0.5), (0.08, 0.08, 0.2), material=SOOT, vertices=16)
    add("cylinder", f"stack_fire{sx}", (sx * 0.22, 0.4, 0.71), (0.06, 0.06, 0.01), material=EMBER, vertices=16)
    add("cube", f"foot{sx}", (sx * 0.32, 0.42, 0.06), (0.14, 0.16, 0.06), material=IRON, bevel=0.02)
# Glowing magma cracks across the armour.
for i, (x, y, rz, ln) in enumerate([(0.25, 0.2, 0.5, 0.12), (-0.28, 0.15, -0.7, 0.1), (0.1, 0.28, 0.1, 0.09), (-0.12, -0.25, 0.9, 0.07)]):
    add("cube", f"crack{i}", (x, y, 0.525), (ln, 0.008, 0.004), rot=(0, 0, rz), material=LAVA)
render_strip("forge_mech", 1, 512, 2.4, lambda i: None)
print("STAGE3 DONE")
