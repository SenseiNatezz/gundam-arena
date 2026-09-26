# Gundam Arena

Top-down mobile-style mech shooter made in Godot 4.7. Pilot a Gundam through three levels of 5 waves
each, pick upgrades as you level up (they carry over between levels), and take down the boss at the end
of each level:

- **Level 1 – Hangar A-1:** scout drones and gunships, then the spider-mech **Arachne**.
- **Level 2 – Reactor Deck B-7:** wasp interceptors that dash along warning lanes, mortar crawlers
  whose shells mark their landing zone, and seeker mines (shoot them early for chain reactions), then the
  **Leviathan** battleship: destroy its wing turrets, then survive its reactor overload (rotating spoke
  lasers, homing missiles and a ramming charge).
- **Level 3 – Volcanic Forge:** a basalt floor split by glowing lava cracks, where random floor tiles
  glow and then erupt. Heat drones lob slow fireballs, and the **Magma Forge Mech** rises from the lava
  to leap onto you with a flame slam inside a red warning circle.

**Cover:** crates, red barrels, reactor pylons and forge rocks block enemy fire (your own shots fly over
them) but break after a few hits. Red barrels explode when destroyed, damaging nearby enemies.

## Play

- **In your browser (PC or phone):** https://senseinatezz.github.io/gundam-arena/
- **Windows:** download `GundamArena-windows.zip` from the
  [latest release](https://github.com/SenseiNatezz/gundam-arena/releases/latest), unzip, and run
  `GundamArena.exe`. Windows SmartScreen may warn about an unknown publisher: click
  *More info → Run anyway*.

**Controls:** WASD / arrows or the on-screen stick to move · Space / Shift or the » button to dash ·
E / Q or the BEAM RIFLE button to fire the Beam Rifle · F / R or the BEAM SABER button for a spin slash ·
Esc / P or the II button to pause · 1 / 2 / 3 to pick an upgrade. The mech auto-fires at the nearest enemy.

**Specials** (available from the start, each with a cooldown shown under its button):

- **Beam Rifle** (12s): a piercing beam wrapped in crackling lightning that hits every enemy in a line.
- **Beam Saber** (6s): the Gundam draws its energy sword and spins, sweeping a crescent of energy around
  itself that hits every nearby enemy, knocks them back and slices enemy shots out of the air.

**Upgrades** include Triple Shot, Faster Thrusters, +25% Attack Speed, Piercing Shot, I-Field Shield,
Homing Missiles, Beam Overcharge, Reinforced Armor, +20% Move Speed and (in the Volcanic Forge) Heat Shield.

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
| `scenes/main.gd` | Per-level waves (`STAGE_WAVES`), pools, spawn helpers, eruptions, level-up / pause / end flow, debug flags |
| `scenes/player.gd` | Movement, dash, auto-aim, missiles, shield, damage |
| `scenes/enemies/` | `enemy.gd` base class, all enemy types and the three bosses (+ their telegraph drawing) |
| `scenes/abilities/` | Beam Rifle and Beam Saber effects (hit logic + drawing) |
| `scenes/cover.gd` | Destructible cover (crates, barrels, pylons, rocks) |
| `scenes/hazards/` | Volcanic Forge eruption tiles |
| `scenes/bullet.gd` | Pooled projectile used by player bolts, missiles and enemy shots / fireballs |
| `scenes/arena.gd` | Procedurally painted floors for all three levels, walls and cover placement |
| `scripts/autoload/game_state.gd` | Levels (`STAGES`), base player stats (`BASE_STATS`), XP curve, upgrades |
| `scripts/autoload/sfx.gd` | Synthesized sound effects (no audio files) |
| `resources/upgrades/*.tres` | Upgrade definitions (`Upgrade` resource) |
| `scripts/ui/` | HUD, virtual joystick, dash + ability buttons, upgrade menu, pause / end overlay |

**Adding an upgrade:** create a `.tres` in `resources/upgrades` (copy an existing one), set `add_stats` /
`mul_stats` using keys from `GameState.BASE_STATS`, and add its path to `GameState.UPGRADE_PATHS`.
`min_level` / `min_stage` limit when it's offered; `featured` guarantees it a slot.

**Tuning:** enemy HP/speed/damage are exported on each enemy scene; waves are in `Main.STAGE_WAVES`;
player stats in `GameState.BASE_STATS`; cover hit counts in `Arena._spawn_cover()`.

### Re-rendering sprites

```
blender -b "path/to/Gundam_2D_Sprites.blend" --python tools/render_gundam.py
blender -b --factory-startup --python tools/render_enemies.py
blender -b --factory-startup --python tools/render_stage2.py
blender -b --factory-startup --python tools/render_stage3.py
blender -b "path/to/Gundam_Sword_2D_Sprites.blend" --python tools/render_gundam_sword.py
```

`render_gundam.py` renders each action (Hover_Idle, Boost_Loop, Bank_Left/Right, Dash_Forward, Rifle_Fire,
Aim_Rifle) from straight above, packs `assets/sprites/gundam_sheet.png`, and regenerates `gundam_frames.tres`
plus `gundam_meta.json` (muzzle / thruster pixel positions used in `player.tscn`). It reuses frames already
in `assets/raw/gundam` (pass `--force` to re-render) and never saves the .blend. `render_gundam_sword.py` renders
the Sword_Slash animation (energy sword model) into `gundam_sword_sheet.png`; the player merges it in as `slash`. The enemy scripts share
their scene setup and helpers through `tools/enemy_kit.py`.

### Debug flags

Pass after `--`: `--god`, `--autopilot` (dodging bot, auto-picks upgrades and advances levels),
`--stage=N`, `--wave=N`, `--level=N`, `--hp=N`, `--boss-hp=0.5`, `--damage-cover`, `--beam-at=S`, `--saber-at=S`, `--demo-ring`,
`--upgrade-menu`, `--pause-menu`, `--shot=path.png --shot-time=S` (screenshot then quit).

Input smoke test: `Godot..._console.exe --headless --path . -- --smoke-test --god`
