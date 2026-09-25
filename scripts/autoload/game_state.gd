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
	wave = 0
	enemies_remaining = 0
	level = 1
	xp = 0
	xp_needed = _xp_for(1)
	pending_levels = 0
	kills = 0
	run_time = 0.0
	touch_move = Vector2.ZERO
	dash_requested = false
	special_requested = false


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
		if stacks.get(u.id, 0) >= u.max_stacks or level < u.min_level:
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
