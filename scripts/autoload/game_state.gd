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
}
const FINAL_STAGE := 3
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
	"cannon": 0,
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
	"res://resources/upgrades/mega_cannon.tres",
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

## Command-line debug flags (see Main._parse_debug_args).
var debug := {"god": false, "autopilot": false, "no_input": false}


func _ready() -> void:
	for path in UPGRADE_PATHS:
		upgrades.append(load(path))
	reset()


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
