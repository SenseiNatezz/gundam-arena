extends Enemy
## Leviathan-class battleship (Level 2 boss).
##   Phase 1: two wing turrets (separate targets) fire bursts while the hull cruises across the top,
##            fires broadside volleys and drops seeker mines.
##   Phase 2 (HP <= 50% or both turrets destroyed): "REACTOR OVERLOAD" - rotating spoke lasers from
##            the reactor, homing missile swarms and a telegraphed ramming charge down the arena.

const TURRET := preload("res://scenes/enemies/leviathan_turret.tscn")
const TURRET_MOUNTS := [Vector2(-123, -11), Vector2(123, -11)]
const CORE := Vector2(0, 16)
const SIDE_GUNS := [Vector2(-45, 80), Vector2(45, 80)]
const PHASE1_CYCLE := [&"broadside", &"mines", &"broadside", &"mines"]
const PHASE2_CYCLE := [&"spokes", &"missiles", &"ram", &"mines", &"spokes", &"ram", &"missiles"]
const SPOKE_WARN := 1.0
const SPOKE_ACTIVE := 2.8
const SPOKE_LENGTH := 1000.0
const RAM_WARN := 1.1
const RAM_SPEED := 1150.0
const LANE_WIDTH := 190.0

var phase := 1
var _state := &"cruise"
var _state_time := 2.5
var _cycle := 0
var _home_y := 345.0
var _turrets: Array[Enemy] = []
var _volleys_left := 0
var _volley_timer := 0.0
var _spoke_angle := 0.0
var _spoke_count := 3
var _base_contact := 25.0

@onready var telegraph: Node2D = $Telegraph


func _ready() -> void:
	super()
	_base_contact = contact_damage
	GameState.boss_changed.emit(hp, max_hp)
	for mount in TURRET_MOUNTS:
		var turret: Enemy = TURRET.instantiate()
		turret.position = mount
		turret.entering = false
		add_child(turret)
		turret.died.connect(GameState.world._on_enemy_died)
		turret.died.connect(_on_turret_died)
		_turrets.append(turret)
	GameState.enemies_remaining += _turrets.size()
	GameState.enemies_changed.emit(GameState.enemies_remaining)


func take_damage(amount: float, crit: bool, hit_dir: Vector2, knock := 170.0) -> void:
	super(amount, crit, hit_dir, knock)
	GameState.boss_changed.emit(maxf(hp, 0.0), max_hp)


func _behave(delta: float) -> void:
	var p := _player()
	_state_time -= delta
	if phase == 1 and (hp <= max_hp * 0.5 or _turrets.is_empty()):
		_enter_phase_two()
	match _state:
		&"cruise":
			_cruise(delta)
			if _state_time <= 0.0:
				var cycle: Array = PHASE1_CYCLE if phase == 1 else PHASE2_CYCLE
				_start_attack(cycle[_cycle % cycle.size()])
				_cycle += 1
		&"broadside":
			_cruise(delta)
			_volley_timer -= delta
			if _volleys_left > 0 and _volley_timer <= 0.0:
				_volley_timer = 0.3
				_volleys_left -= 1
				for gun in SIDE_GUNS:
					_fire_at(gun, 330.0, 10.0, 3, 16.0)
			if _volleys_left <= 0 and _volley_timer <= 0.0:
				_end_attack(2.2 if phase == 1 else 1.4)
		&"spokes":
			var elapsed := SPOKE_WARN + SPOKE_ACTIVE - _state_time
			if elapsed >= SPOKE_WARN:
				telegraph.spoke_mode = 2
				_spoke_angle += delta * 0.65
				GameState.world.shake(0.12)
				if p and _spoke_hits(p.global_position):
					p.take_damage(20.0, to_global(CORE))
			telegraph.spoke_angle = _spoke_angle
			telegraph.spoke_origin = to_global(CORE)
			if _state_time <= 0.0:
				_end_attack(1.4)
		&"missiles":
			_cruise(delta)
			_volley_timer -= delta
			if _volleys_left > 0 and _volley_timer <= 0.0:
				_volley_timer = 0.12
				_volleys_left -= 1
				var side := -1.0 if _volleys_left % 2 == 0 else 1.0
				var dir := Vector2(side, 0.35).normalized()
				GameState.world.fire_enemy_missile(to_global(Vector2(side * 70, 20)), dir * 260.0, 12.0)
				Sfx.play(&"missile", -10.0)
			if _volleys_left <= 0 and _volley_timer <= 0.0:
				_end_attack(1.6)
		&"ram_warn":
			telegraph.lane_x = global_position.x
			if _state_time <= 0.0:
				_state = &"ram"
				contact_damage = 34.0
				Sfx.play(&"dash", 0.0, 0.0)
				GameState.world.shake(0.5)
		&"ram":
			global_position.y += RAM_SPEED * delta
			GameState.world.shake(0.15)
			if global_position.y >= 1080.0:
				_state = &"ram_return"
				telegraph.lane_mode = 0
				contact_damage = _base_contact
				GameState.world.spawn_explosion(global_position + Vector2(0, 150), 1.6)
				GameState.world.shake(0.8)
				Sfx.play(&"slam", 0.0)
		&"ram_return":
			global_position.y = move_toward(global_position.y, _home_y, 300.0 * delta)
			if absf(global_position.y - _home_y) < 2.0:
				_end_attack(1.2)
		&"mines":
			_cruise(delta)
			if _state_time <= 0.0:
				_end_attack(2.0 if phase == 1 else 1.4)


func _cruise(delta: float) -> void:
	var target_x := 360.0 + sin(t * 0.45) * 160.0
	global_position.x = move_toward(global_position.x, target_x, move_speed * delta)
	global_position.y = lerpf(global_position.y, _home_y + sin(t * 0.8) * 18.0, 1.0 - exp(-2.0 * delta))


func _start_attack(kind: StringName) -> void:
	_state = kind
	match kind:
		&"broadside":
			_volleys_left = 4
			_volley_timer = 0.2
		&"mines":
			_state_time = 0.8
			for side in [-1.0, 1.0]:
				var from := to_global(Vector2(side * 60.0, 60.0))
				GameState.world.spawn_enemy(&"mine", from, from + Vector2(side * 90.0, 140.0), true)
			Sfx.play(&"select", -8.0, 0.0)
		&"spokes":
			_state_time = SPOKE_WARN + SPOKE_ACTIVE
			_spoke_angle = randf() * TAU
			telegraph.spoke_mode = 1
			telegraph.spoke_count = _spoke_count
			Sfx.play(&"charge", -6.0, 0.0)
		&"missiles":
			_volleys_left = 6
			_volley_timer = 0.3
		&"ram":
			_state = &"ram_warn"
			_state_time = RAM_WARN
			telegraph.lane_mode = 1
			telegraph.lane_x = global_position.x
			telegraph.lane_width = LANE_WIDTH
			Sfx.play(&"alarm", -12.0, 0.0)


func _end_attack(cruise_time: float) -> void:
	_state = &"cruise"
	_state_time = cruise_time
	telegraph.spoke_mode = 0
	telegraph.lane_mode = 0


func _enter_phase_two() -> void:
	phase = 2
	_cycle = 0
	_spoke_count = 4
	move_speed *= 1.3
	GameState.world.hud.show_banner("REACTOR OVERLOAD", "The Leviathan is enraged", Color(1.0, 0.55, 0.15), 1.0)
	GameState.world.shake(0.6)
	Sfx.play(&"alarm", -4.0, 0.0)
	$Core.modulate = Color(1, 0.3, 0.1, 1)


func _spoke_hits(point: Vector2) -> bool:
	var origin := to_global(CORE)
	for i in _spoke_count:
		var dir := Vector2.from_angle(_spoke_angle + i * TAU / _spoke_count)
		var along := (point - origin).dot(dir)
		if along > 0.0 and along < SPOKE_LENGTH and point.distance_to(origin + dir * along) < 34.0:
			return true
	return false


func _on_turret_died(turret: Enemy) -> void:
	_turrets.erase(turret)
	# Losing a turret rocks the ship and costs it a chunk of hull.
	hp -= max_hp * 0.06
	_flash = 1.0
	GameState.boss_changed.emit(maxf(hp, 0.0), max_hp)
	GameState.world.shake(0.5)


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_end_attack(0.0)
	for turret in _turrets.duplicate():
		turret.kill()
	GameState.boss_changed.emit(0.0, max_hp)
	for i in 12:
		get_tree().create_timer(i * 0.11, false).timeout.connect(func() -> void:
			GameState.world.spawn_explosion(global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150)), randf_range(0.9, 1.6))
			GameState.world.shake(0.4)
			Sfx.play(&"explode", -4.0, 0.2))
	await get_tree().create_timer(1.4, false).timeout
	GameState.world.spawn_explosion(global_position, 3.6)
	GameState.world.shake(1.0)
	Sfx.play(&"big_explode", 2.0)
	for i in xp_orbs:
		GameState.world.spawn_xp(global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60)), xp_value)
	died.emit(self)
	queue_free()
