# Gundam Arena

Top-down mobile-style mech shooter made in Godot 4.7. Pilot a Gundam through 5 waves of drones and
gunships, pick upgrades as you level up, and take down a spider-mech boss.

## Play

- **In your browser (PC or phone):** https://senseinatezz.github.io/gundam-arena/
- **Windows:** download `GundamArena-windows.zip` from the
  [latest release](https://github.com/SenseiNatezz/gundam-arena/releases/latest), unzip, and run
  `GundamArena.exe`. Windows SmartScreen may warn about an unknown publisher: click
  *More info → Run anyway*.

**Controls:** WASD / arrows or the on-screen stick to move · Space / Shift or the » button to dash ·
Esc / P or the II button to pause · 1 / 2 / 3 to pick an upgrade. The mech auto-fires at the nearest enemy.

## Development

Top-down shooter in Godot 4.7 (GDScript, Compatibility renderer, portrait 720x1280).
The player mech is rendered from a rigged Blender model (`Gundam_2D_Sprites.blend`, not included);
enemies are procedural Blender models.

### Run from source

Open `project.godot` in Godot 4.7+ and press F5, or:

```
Godot_v4.7.2-stable_win64_console.exe --path .
```

Exports: *Project → Export* has **Web** (single-threaded, works on GitHub Pages) and **Windows Desktop**
(single .exe) presets; output goes to `build/`. `node tools/serve_web.js` serves `build/web` locally.

### Layout

| Path | What |
| --- | --- |
| `scenes/main.gd` | Wave script (`WAVES`), pools, spawn helpers, level-up / pause / end flow, debug flags |
| `scenes/player.gd` | Movement, dash, auto-aim, missiles, shield, damage |
| `scenes/enemies/` | `enemy.gd` base class, drone, gunship, spider-mech boss (+ telegraph drawing) |
| `scenes/bullet.gd` | Pooled projectile used by player bolts, missiles and enemy shots |
| `scripts/autoload/game_state.gd` | Base player stats (`BASE_STATS`), XP curve, upgrades |
| `scripts/autoload/sfx.gd` | Synthesized sound effects (no audio files) |
| `resources/upgrades/*.tres` | Upgrade definitions (`Upgrade` resource) |
| `scenes/arena.gd` | Procedurally painted hangar floor, walls and crate colliders |
| `scripts/ui/` | HUD, virtual joystick, dash button, upgrade menu, pause / end overlay |

**Adding an upgrade:** create a `.tres` in `resources/upgrades` (copy an existing one), set `add_stats` /
`mul_stats` using keys from `GameState.BASE_STATS`, and add its path to `GameState.UPGRADE_PATHS`.

**Tuning:** enemy HP/speed/damage are exported on each enemy scene; waves are in `Main.WAVES`;
player stats in `GameState.BASE_STATS`.

### Re-rendering sprites

```
blender -b "path/to/Gundam_2D_Sprites.blend" --python tools/render_gundam.py
blender -b --factory-startup --python tools/render_enemies.py
```

`render_gundam.py` renders each action (Hover_Idle, Boost_Loop, Bank_Left/Right, Dash_Forward, Rifle_Fire)
from straight above, packs `assets/sprites/gundam_sheet.png`, and regenerates `gundam_frames.tres`
plus `gundam_meta.json` (muzzle / thruster pixel positions used in `player.tscn`). It never saves the .blend.

### Debug flags

Pass after `--`: `--god`, `--autopilot` (dodging bot, auto-picks upgrades), `--wave=N`, `--level=N`,
`--hp=N`, `--upgrade-menu`, `--pause-menu`, `--shot=path.png --shot-time=S` (screenshot then quit).

Input smoke test: `Godot..._console.exe --headless --path . -- --smoke-test --god`
