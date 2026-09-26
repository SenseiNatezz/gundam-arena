extends Node
## Run-wide state: waves, XP/levels, player stats and upgrades. Autoloaded as GameState.

signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: int, needed: int, level: int)
signal wave_changed(wave: int, total: int)
signal enemies_changed(remaining: int)
signal boss_changed(hp: float, max_hp: float)
signal level_up_ready
signal stats_changed

const TOTAL_WAVES := 5
## One entry per level. Main reads the waves/arena/boss for GameState.stage.
const STAGES := {
	1: {"sector": "A-1", "title": "HANGAR A-1", "boss": "ARACHNE-CLASS MOBILE ARMOR"},
	2: {"sector": "B-7", "title": "REACTOR DECK B-7", "boss": "LEVIATHAN-CLASS BATTLESHIP"},
	3: {"sector": "VF", "title": "VOLCANIC FORGE", "boss": "MAGMA FORGE MECH"},
	4: {"sector": "CR", "title": "CRYO REACTOR", "boss": "CRYO TITAN"},
}
const FINAL_STAGE := 4
const BASE_STATS := {
	"max_hp": 120.0,
	"move_speed": 380.0,
	"fire_rate": 5.0,
	"damage": 24.0,
	"crit_chance": 0.1,
	"multishot": 1,
	"spread_deg": 9.0,
	"pierce": 0,
	"bullet_speed": 1150.0,
	"dash_cooldown": 1.5,
	"shield": 0,
	"homing": 0,
	"magnet": 130.0,
	"heat_resist": 0.0,
}
const UPGRADE_PATHS := [
	"res://resources/upgrades/triple_shot.tres",
	"res://resources/upgrades/faster_thrusters.tres",
	"res://resources/upgrades/attack_speed.tres",
	"res://resources/upgrades/piercing.tres",
	"res://resources/upgrades/shield.tres",
	"res://resources/upgrades/homing.tres",
	"res://resources/upgrades/power.tres",
	"res://resources/upgrades/armor.tres",
	"res://resources/upgrades/heat_shield.tres",
	"res://resources/upgrades/move_speed.tres",
]

var upgrades: Array[Upgrade] = []
var stats: Dictionary = {}
var stacks: Dictionary = {}
var wave := 0
var enemies_remaining := 0
var level := 1
var xp := 0
var xp_needed := 5
var pending_levels := 0
var kills := 0
var run_time := 0.0
var stage := 1
## Set before reloading Main to keep the current run (next level / retry a later level).
var carry_over := false
var _stage_snapshot: Dictionary = {}

## The Main scene (spawning helpers) and the player; set by those nodes in _ready.
var world: Node
var player: Node2D

## Written by on-screen touch controls, read by the player.
var touch_move := Vector2.ZERO
var dash_requested := false
var special_requested := false
var saber_requested := false

## Command-line debug flags (see Main._parse_debug_args).
var debug := {"god": false, "autopilot": false, "no_input": false}


func _ready() -> void:
	for path in UPGRADE_PATHS:
		upgrades.append(load(path))
	reset()
	load_settings()
	for arg in OS.get_cmdline_user_args():  # preview-only overrides (not saved): --paint=crimson --energy=pink
		if arg.begins_with("--paint=") and PAINTS.has(StringName(arg.get_slice("=", 1))):
			paint = StringName(arg.get_slice("=", 1))
		if arg.begins_with("--energy=") and ENERGIES.has(StringName(arg.get_slice("=", 1))):
			energy = StringName(arg.get_slice("=", 1))


func _process(delta: float) -> void:
	if world and not get_tree().paused:
		run_time += delta


func reset() -> void:
	stats = BASE_STATS.duplicate()
	stacks = {}
	level = 1
	xp = 0
	xp_needed = _xp_for(1)
	kills = 0
	run_time = 0.0
	stage = 1
	begin_stage()


## Per-level state; upgrades, level and XP carry over between levels.
func begin_stage() -> void:
	wave = 0
	enemies_remaining = 0
	pending_levels = 0
	touch_move = Vector2.ZERO
	dash_requested = false
	special_requested = false
	saber_requested = false


func stage_info() -> Dictionary:
	return STAGES[stage]


## Remember the build the player entered this level with (used by Retry).
func snapshot_stage() -> void:
	_stage_snapshot = {
		"stats": stats.duplicate(), "stacks": stacks.duplicate(), "level": level,
		"xp": xp, "xp_needed": xp_needed, "kills": kills, "run_time": run_time,
	}


func restore_stage_snapshot() -> void:
	if _stage_snapshot.is_empty():
		return
	stats = _stage_snapshot.stats.duplicate()
	stacks = _stage_snapshot.stacks.duplicate()
	level = _stage_snapshot.level
	xp = _stage_snapshot.xp
	xp_needed = _stage_snapshot.xp_needed
	kills = _stage_snapshot.kills
	run_time = _stage_snapshot.run_time


func _xp_for(lv: int) -> int:
	return 4 + (lv - 1) * 3


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = _xp_for(level)
		pending_levels += 1
	xp_changed.emit(xp, xp_needed, level)
	if pending_levels > 0:
		level_up_ready.emit()


func roll_upgrades(count := 3) -> Array[Upgrade]:
	var pool: Array[Upgrade] = []
	var featured: Array[Upgrade] = []
	for u in upgrades:
		if stacks.get(u.id, 0) >= u.max_stacks or level < u.min_level or stage < u.min_stage:
			continue
		# Featured unlocks (e.g. the Hyper Mega Cannon) are guaranteed a slot until first taken.
		if u.featured and not stacks.has(u.id):
			featured.append(u)
		else:
			pool.append(u)
	pool.shuffle()
	return (featured + pool).slice(0, count)


func apply_upgrade(u: Upgrade) -> void:
	stacks[u.id] = stacks.get(u.id, 0) + 1
	for key in u.add_stats:
		stats[key] += u.add_stats[key]
	for key in u.mul_stats:
		stats[key] *= u.mul_stats[key]
	stats_changed.emit()


func consume_dash_request() -> bool:
	var requested := dash_requested
	dash_requested = false
	return requested


func consume_special_request() -> bool:
	var requested := special_requested
	special_requested = false
	return requested


func consume_saber_request() -> bool:
	var requested := saber_requested
	saber_requested = false
	return requested



# --- save / continue ---------------------------------------------------------------------------
# Progress is saved at the start of every level (the build the pilot entered it with), so
# CONTINUE on the title screen drops you back into the last level you reached.

## A var (not const) so the smoke test can use its own file and never touch the real save.
var save_path := "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_progress() -> void:
	var data := _stage_snapshot.duplicate()
	data["stage"] = stage
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


## Loads the save and arms carry_over so the next Main scene resumes that level.
func load_progress() -> bool:
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary or not data.has("stage"):
		return false
	reset()
	stats = BASE_STATS.duplicate()
	for key in data.get("stats", {}):
		stats[key] = data.stats[key]
	stacks = {}
	for key in data.get("stacks", {}):
		stacks[StringName(key)] = int(data.stacks[key])
	stage = clampi(int(data.stage), 1, FINAL_STAGE)
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	xp_needed = int(data.get("xp_needed", _xp_for(level)))
	kills = int(data.get("kills", 0))
	run_time = float(data.get("run_time", 0.0))
	carry_over = true
	return true


# --- customization -----------------------------------------------------------------------------
# Armor paint recolors the mech's blue armor panels (hit_flash.gdshader "recolor" uniforms);
# energy color tints thrusters, rifle bolts and the muzzle flash.

const SETTINGS_PATH := "user://settings.cfg"
const PAINTS := {
	&"classic": {"name": "CLASSIC BLUE", "swatch": Color(0.18, 0.4, 0.95)},
	&"crimson": {"name": "CRIMSON", "swatch": Color(0.85, 0.12, 0.12), "hue": 0.99, "sat": 1.05, "val": 1.0},
	&"forest": {"name": "FOREST GREEN", "swatch": Color(0.15, 0.6, 0.25), "hue": 0.36, "sat": 0.95, "val": 0.9},
	&"stealth": {"name": "STEALTH BLACK", "swatch": Color(0.14, 0.15, 0.18), "hue": 0.62, "sat": 0.15, "val": 0.42},
	&"gold": {"name": "ROYAL GOLD", "swatch": Color(0.95, 0.7, 0.15), "hue": 0.12, "sat": 1.0, "val": 1.15},
}
const ENERGIES := {
	&"cyan": {"name": "CYAN", "core": Color(0.85, 0.95, 1.0), "mid": Color(0.25, 0.55, 1.0), "glow": Color(0.25, 0.6, 1.0)},
	&"pink": {"name": "PINK", "core": Color(1.0, 0.85, 0.95), "mid": Color(1.0, 0.3, 0.75), "glow": Color(1.0, 0.3, 0.7)},
	&"orange": {"name": "ORANGE", "core": Color(1.0, 0.95, 0.75), "mid": Color(1.0, 0.5, 0.1), "glow": Color(1.0, 0.5, 0.15)},
	&"green": {"name": "GREEN", "core": Color(0.9, 1.0, 0.85), "mid": Color(0.3, 1.0, 0.35), "glow": Color(0.3, 1.0, 0.4)},
}

var paint := &"classic"
var energy := &"cyan"
var volume := 1.0
var screen_shake := true


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var p := StringName(cfg.get_value("custom", "paint", "classic"))
		var e := StringName(cfg.get_value("custom", "energy", "cyan"))
		paint = p if PAINTS.has(p) else &"classic"
		energy = e if ENERGIES.has(e) else &"cyan"
		volume = clampf(float(cfg.get_value("settings", "volume", 1.0)), 0.0, 1.0)
		screen_shake = bool(cfg.get_value("settings", "screen_shake", true))
	apply_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("custom", "paint", String(paint))
	cfg.set_value("custom", "energy", String(energy))
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.save(SETTINGS_PATH)


## Applies the chosen armor paint to a hit_flash ShaderMaterial.
func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))


func apply_paint(mat: ShaderMaterial) -> void:
	var p: Dictionary = PAINTS[paint]
	mat.set_shader_parameter("recolor", p.has("hue"))
	if p.has("hue"):
		mat.set_shader_parameter("target_hue", p.hue)
		mat.set_shader_parameter("sat_mult", p.sat)
		mat.set_shader_parameter("val_mult", p.val)


func energy_colors() -> Dictionary:
	return ENERGIES[energy]
