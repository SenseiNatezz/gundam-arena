# Level 2 ("Sector B-7") enemies: wasp interceptor, mortar crawler, seeker mine, Leviathan boss + turret.
# Usage: blender -b --factory-startup --python tools/render_stage2.py
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemy_kit import *  # noqa: F401,F403 - scene, materials, add/empty/clear/render_strip

YEL = mat("wasp_yellow", (0.9, 0.66, 0.05), 0.35, 0.3)
BLACK = mat("wasp_black", (0.03, 0.03, 0.035), 0.5, 0.35)
OLIVE = mat("olive_armor", (0.26, 0.32, 0.14), 0.4, 0.4)
TEAL = mat("teal_armor", (0.05, 0.3, 0.34), 0.55, 0.3)
TEAL_DARK = mat("teal_dark", (0.03, 0.12, 0.15), 0.6, 0.35)
GLOW_G = mat("glow_green", (0.4, 1, 0.3), 0, 0.3, (0.3, 1, 0.2), 4)
GLOW_P = mat("glow_purple", (0.8, 0.2, 1), 0, 0.3, (0.75, 0.15, 1), 5)
GLOW_C = mat("glow_cyan", (0.3, 0.9, 1), 0, 0.3, (0.2, 0.85, 1), 4)


# ---------- wasp interceptor (front = -Y) ----------
clear()
add("cone", "fuselage", (0, -0.02, 0.06), (0.07, 0.07, 0.3), rot=(math.pi / 2, 0, 0), material=YEL, vertices=16)
add("cube", "spine", (0, 0.08, 0.1), (0.035, 0.16, 0.02), material=BLACK, bevel=0.01)
add("uv_sphere", "canopy", (0, -0.1, 0.1), (0.035, 0.07, 0.03), material=GLOW_C, radius=1)
for sx in (-1, 1):
    add("cube", f"wing{sx}", (sx * 0.17, 0.1, 0.05), (0.15, 0.07, 0.012), rot=(0, 0, sx * 0.55), material=YEL, bevel=0.01)
    add("cube", f"wing_stripe{sx}", (sx * 0.2, 0.13, 0.063), (0.09, 0.018, 0.004), rot=(0, 0, sx * 0.55), material=BLACK)
    add("cube", f"fin{sx}", (sx * 0.07, 0.26, 0.08), (0.02, 0.07, 0.04), rot=(0, 0, sx * 0.3), material=BLACK, bevel=0.005)
    add("cylinder", f"engine{sx}", (sx * 0.06, 0.28, 0.05), (0.035, 0.035, 0.05), rot=(math.pi / 2, 0, 0), material=BLACK, vertices=12)
    add("cylinder", f"exhaust{sx}", (sx * 0.06, 0.33, 0.05), (0.028, 0.028, 0.01), rot=(math.pi / 2, 0, 0), material=GLOW_G, vertices=12)
    add("cylinder", f"gun{sx}", (sx * 0.2, -0.05, 0.05), (0.012, 0.012, 0.08), rot=(math.pi / 2, 0, 0), material=STEEL, vertices=8)
render_strip("wasp", 1, 192, 0.85, lambda i: None)


# ---------- mortar crawler (front = -Y) ----------
clear()
add("cube", "hull", (0, 0, 0.08), (0.2, 0.26, 0.07), material=OLIVE, bevel=0.03)
add("cube", "deck", (0, 0.06, 0.16), (0.14, 0.15, 0.02), material=GUN, bevel=0.01)
add("cube", "hazard_front", (0, -0.25, 0.1), (0.16, 0.015, 0.03), material=HAZ)
links = []
for sx in (-1, 1):
    add("cube", f"tread{sx}", (sx * 0.27, 0, 0.06), (0.07, 0.3, 0.06), material=DARK, bevel=0.02)
    for k in range(9):
        link = add("cube", f"link{sx}{k}", (sx * 0.27, -0.28 + k * 0.07, 0.125), (0.075, 0.012, 0.008), material=STEEL)
        links.append((link, -0.28 + k * 0.07))
add("cylinder", "turret", (0, 0.03, 0.2), (0.12, 0.12, 0.05), material=OLIVE, bevel=0.015, vertices=20)
add("cylinder", "turret_ring", (0, 0.03, 0.26), (0.08, 0.08, 0.012), material=GUN, vertices=20)
add("cylinder", "mortar", (0, -0.1, 0.24), (0.055, 0.055, 0.1), rot=(math.pi / 2 - 0.4, 0, 0), material=GUN, bevel=0.01, vertices=16)
add("cylinder", "mortar_bore", (0, -0.19, 0.28), (0.035, 0.035, 0.01), rot=(math.pi / 2 - 0.4, 0, 0), material=GLOW_O, vertices=16)
add("uv_sphere", "sensor", (0.07, 0.12, 0.25), (0.025, 0.025, 0.02), material=GLOW_G, radius=1)


def crawler_frame(i):
    for link, y in links:
        link.location.y = -0.28 + ((y + 0.28 + i * 0.035) % 0.63)


render_strip("crawler", 2, 224, 1.05, crawler_frame)


# ---------- seeker mine ----------
clear()
add("uv_sphere", "shell", (0, 0, 0.1), (0.14, 0.14, 0.12), material=GUN, radius=1, segments=24, ring_count=12)
add("torus", "core_ring", (0, 0, 0.19), (1, 1, 1), material=GLOW_P, major_radius=0.07, minor_radius=0.018)
add("uv_sphere", "core", (0, 0, 0.2), (0.04, 0.04, 0.03), material=GLOW_P, radius=1)
spikes = empty("spikes", (0, 0, 0.1))
for k in range(8):
    a = k * math.tau / 8
    add("cone", f"spike{k}", (math.cos(a) * 0.17, math.sin(a) * 0.17, 0), (0.03, 0.03, 0.07),
        rot=(0, math.pi / 2, a), material=STEEL, vertices=8, parent=spikes)
render_strip("mine", 3, 160, 0.6, lambda i: setattr(spikes.rotation_euler, "z", i * math.tau / 24))


# ---------- Leviathan battleship (front = -Y) ----------
clear()
add("uv_sphere", "hull", (0, 0, 0.15), (0.55, 1.45, 0.22), material=TEAL, radius=1, segments=40, ring_count=20)
add("cube", "armor_spine", (0, 0.15, 0.36), (0.2, 0.85, 0.05), material=TEAL_DARK, bevel=0.03)
add("cone", "prow", (0, -1.35, 0.14), (0.3, 0.3, 0.45), rot=(math.pi / 2, 0, 0), material=TEAL_DARK, vertices=24)
add("cube", "prow_stripe", (0, -1.05, 0.33), (0.18, 0.02, 0.012), material=HAZ)
for sx in (-1, 1):
    add("cube", f"wing{sx}", (sx * 0.85, 0.12, 0.12), (0.42, 0.3, 0.05), rot=(0, 0, sx * 0.12), material=TEAL, bevel=0.04)
    add("cylinder", f"mount{sx}", (sx * 1.15, 0.1, 0.18), (0.22, 0.22, 0.04), material=TEAL_DARK, bevel=0.01, vertices=28)
    add("cube", f"wing_panel{sx}", (sx * 0.72, 0.3, 0.18), (0.18, 0.1, 0.012), rot=(0, 0, sx * 0.12), material=GUN, bevel=0.01)
    add("cube", f"wing_haz{sx}", (sx * 1.1, 0.42, 0.18), (0.2, 0.02, 0.01), rot=(0, 0, sx * 0.12), material=HAZ)
    for k in range(3):
        add("cylinder", f"engine{sx}{k}", (sx * (0.18 + k * 0.17), 1.3, 0.12), (0.075, 0.075, 0.12),
            rot=(math.pi / 2, 0, 0), material=GUN, vertices=16)
        add("cylinder", f"exhaust{sx}{k}", (sx * (0.18 + k * 0.17), 1.43, 0.12), (0.06, 0.06, 0.01),
            rot=(math.pi / 2, 0, 0), material=GLOW_O, vertices=16)
    add("cube", f"side_gun{sx}", (sx * 0.42, -0.75, 0.2), (0.035, 0.18, 0.035), material=DARK, bevel=0.008)
add("cylinder", "reactor_well", (0, -0.15, 0.36), (0.26, 0.26, 0.03), material=DARK, vertices=32)
add("torus", "reactor_ring", (0, -0.15, 0.4), (1, 1, 1), material=GLOW_O, major_radius=0.2, minor_radius=0.035)
add("uv_sphere", "reactor_core", (0, -0.15, 0.4), (0.13, 0.13, 0.08), material=GLOW_O, radius=1)
add("cube", "bridge", (0, 0.6, 0.45), (0.14, 0.18, 0.08), material=TEAL_DARK, bevel=0.03)
add("cube", "bridge_glass", (0, 0.49, 0.5), (0.1, 0.03, 0.03), material=GLOW_C)
render_strip("leviathan", 1, 640, 3.6, lambda i: None)


# ---------- Leviathan wing turret (rotates in game; barrels point -Y) ----------
clear()
add("cylinder", "base", (0, 0, 0.05), (0.2, 0.2, 0.06), material=TEAL_DARK, bevel=0.02, vertices=24)
add("uv_sphere", "dome", (0, 0.03, 0.1), (0.15, 0.16, 0.08), material=TEAL, radius=1)
add("uv_sphere", "eye", (0, -0.1, 0.14), (0.04, 0.03, 0.02), material=GLOW_C, radius=1)
for sx in (-1, 1):
    add("cylinder", f"barrel{sx}", (sx * 0.06, -0.22, 0.12), (0.025, 0.025, 0.14), rot=(math.pi / 2, 0, 0), material=GUN, vertices=12)
    add("cylinder", f"tip{sx}", (sx * 0.06, -0.36, 0.12), (0.03, 0.03, 0.015), rot=(math.pi / 2, 0, 0), material=STEEL, vertices=12)
render_strip("leviathan_turret", 1, 192, 0.85, lambda i: None)
print("STAGE2 DONE")
