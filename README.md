# Gundam Arena

Top-down mobile-style mech shooter made in Godot 4.7. Pilot a Gundam through four levels of 5 waves
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
- **Level 4 – Cryo Reactor:** a frozen facility with falling snow and breakable ice blocks. Frost drones
  fire snowball spreads and snow walkers lob snowballs; snow hits **chill** you (slow). The **Cryo Titan**
  fires ice-shard fans, erupts rows of ice spikes that **freeze** you (dash to break free) and calls
  down a hailstorm of icicles.

**Cover:** crates, red barrels, reactor pylons, forge rocks and ice blocks block enemy fire (your own shots fly over
them) but break after a few hits. Red barrels explode when destroyed, damaging nearby enemies.

## Main menu

The game opens on an animated main menu video (`assets/title/menu_video.ogv`) with tappable buttons:

- **New Game** – pick a difficulty, then start from Level 1.
- **Continue** – the game saves at the start of every level; Continue resumes the last level you reached
  with your upgrades, pilot level and difficulty.
- **Level Select** – jump into any of the four levels on any difficulty, starting with the pilot level
  and upgrades you'd normally have by then.
- **Gundam Customization** – armor paint (Classic Blue, Crimson, Forest Green, Stealth Black, Royal Gold)
  and energy color (thrusters, rifle bolts, muzzle flash), with a live animated preview. Saved.
- **Settings** – sound volume and screen shake. Saved.
- **Exit** – quits the Windows version.

The pause menu's **MAIN MENU** button returns here at any time.

**Difficulty** scales how many enemies each wave sends, their health (bosses included) and the damage
they deal to you:

| | Enemies per wave | Enemy health | Damage to you |
| --- | --- | --- | --- |
| Easy | 60% | 60% | 50% |
| Normal | 100% | 100% | 100% |
| Hard | 130% | 130% | 130% |
| Extreme | 160% | 170% | 160% |

On top of that, enemies get tougher every level (×1.35 health in Level 2, ×1.7 in Level 3, ×2 in
Level 4), and leveling up slows down after pilot LV 4.

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
| `scenes/title/` | Main menu: menu video, button hotspots, customization and settings panels |
| `scenes/main.gd` | Per-level waves (`STAGE_WAVES`), pools, spawn helpers, eruptions, level-up / pause / end flow, debug flags |
| `scenes/player.gd` | Movement, dash, auto-aim, missiles, shield, damage |
| `scenes/enemies/` | `enemy.gd` base class, all enemy types and the three bosses (+ their telegraph drawing) |
| `scenes/abilities/` | Beam Rifle and Beam Saber effects (hit logic + drawing) |
| `scenes/cover.gd` | Destructible cover (crates, barrels, pylons, rocks) |
| `scenes/ice_shell.gd` | Ice block drawn around the mech while frozen |
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
per-level enemy health in `Main.STAGE_ENEMY_HP`; difficulty modes in `GameState.DIFFICULTIES`; XP curve in `GameState._xp_for`;
player stats in `GameState.BASE_STATS`; cover hit counts in `Arena._spawn_cover()`.

### Re-rendering sprites

```
blender -b "path/to/Gundam_2D_Sprites.blend" --python tools/render_gundam.py
blender -b --factory-startup --python tools/render_enemies.py
blender -b --factory-startup --python tools/render_stage2.py
blender -b --factory-startup --python tools/render_stage3.py
blender -b --factory-startup --python tools/render_stage4.py
blender -b "path/to/Gundam_Sword_2D_Sprites.blend" --python tools/render_gundam_sword.py
blender -b "path/to/Gundam_2D_Sprites.blend" --python tools/render_title_gundam.py
blender -b --factory-startup --python tools/convert_menu_video.py -- "path/to/IdleMenu_Animation_FullFrame.mp4"
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
`--upgrades=homing,homing`, `--preview-zoom=1.6`, `--freeze-at=S`,
`--upgrade-menu`, `--pause-menu`, `--shot=path.png --shot-time=S` (screenshot then quit).

The main menu is skipped when debug flags are given; add `--title` to see it (plus `--title-customize`,
`--title-settings`, `--title-levels`, `--title-difficulty`, `--title-pick=N`, `--difficulty=hard`, `--title-hover=settings`, `--title-start`). `--paint=crimson --energy=pink` preview a
look without saving it.

Input smoke test: `Godot..._console.exe --headless --path . -- --smoke-test --god`
