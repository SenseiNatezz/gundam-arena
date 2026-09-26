extends Enemy
## Magma Forge Mech (Volcanic Forge mini-boss).
##   Rises out of a lava pool at the top of the arena (invulnerable while rising).
##   FLAME SLAM: a red warning circle locks onto the player's spot and fills up; the mech leaps onto
##               it and slams down in a ring of fire (heat damage inside the circle).
##   Also fires fireball fans from its furnace and calls in heat drones.

const HOME := Vector2(360, 300)
const RISE_TIME := 1.8
const SLAM_WARN := 1.3
const SLAM_LEAP := 0.3
const SLAM_RADIUS := 115.0
const SLAM_DAMAGE := 26.0
const FURNACE := Vector2(0, 10)
const CYCLE := [&"slam", &"fireballs", &"slam", &"summon", &"slam", &"fireballs"]

var _state := &"rise"
var _state_time := RISE_TIME
var _cycle := 0
var _slam_target := Vector2.ZERO
var _leap_from := Vector2.ZERO
var _volleys_left := 0
var _volley_timer := 0.0
var _slam_radius := SLAM_RADIUS

@onready var telegraph: Node2D = $Telegraph
@onready var furnace_glow: Sprite2D = $Furnace


func _ready() -> void:
	super()
	entering = false
	global_position = HOME
	sprite.scale = Vector2.ONE * 0.2
	sprite.modulate = Color(0.1, 0.05, 0.03)
	telegraph.rise_pos = HOME
	GameState.boss_changed.emit(hp, max_hp)
	Sfx.play(&"slam", 0.0, 0.0)
	Sfx.play(&"charge", -6.0, 0.0)


func is_targetable() -> bool:
	return super() and _state != &"rise"


func take_damage(amount: float, crit: bool, hit_dir: Vector2, knock := 170.0) -> void:
	if _state == &"rise":
		return
	super(amount, crit, hit_dir, knock)
	GameState.boss_changed.emit(maxf(hp, 0.0), max_hp)


func _behave(delta: float) -> void:
	var p := _player()
	_state_time -= delta
	furnace_glow.modulate.a = 0.65 + 0.25 * sin(t * 6.0)
	match _state:
		&"rise":
			var k := clampf(1.0 - _state_time / RISE_TIME, 0.0, 1.0)
			var e := ease(k, -2.2)
			sprite.scale = Vector2.ONE * lerpf(0.2, 0.55, e)
			sprite.modulate = Color(0.1, 0.05, 0.03).lerp(Color.WHITE, e)
			telegraph.rise_strength = 1.0 - k * 0.6
			GameState.world.shake(0.2)
			if _state_time <= 0.0:
				telegraph.rise_strength = 0.0
				GameState.world.shake(0.7)
				GameState.world.spawn_explosion(global_position, 2.2)
				_end_attack(1.2)
		&"idle":
			var target := HOME + Vector2(sin(t * 0.6) * 150.0, sin(t * 1.1) * 20.0)
			global_position = global_position.move_toward(target, move_speed * delta)
			if p:
				_face((p.global_position - global_position).angle(), delta, 2.0)
			if _state_time <= 0.0:
				_start_attack(CYCLE[_cycle % CYCLE.size()])
				_cycle += 1
		&"slam_warn":
			telegraph.warn_progress = clampf(1.0 - _state_time / SLAM_WARN, 0.0, 1.0)
			# Wind-up: crouch back and shake before the leap.
			global_position = global_position.move_toward(_leap_from - Vector2(0, 30), 60.0 * delta)
			sprite.position = Vector2(randf_range(-2, 2), randf_range(-2, 2)) * telegraph.warn_progress
			if _state_time <= 0.0:
				_state = &"slam_leap"
				_state_time = SLAM_LEAP
				_leap_from = global_position
				sprite.position = Vector2.ZERO
				Sfx.play(&"dash", -2.0, 0.0)
		&"slam_leap":
			var k := clampf(1.0 - _state_time / SLAM_LEAP, 0.0, 1.0)
			global_position = _leap_from.lerp(_slam_target, ease(k, 0.6))
			sprite.scale = Vector2.ONE * 0.55 * (1.0 + sin(k * PI) * 0.3)  # "jump" toward the camera
			if _state_time <= 0.0:
				_slam_impact()
		&"slam_recover":
			if _state_time <= 0.0:
				_state = &"return"
		&"return":
			global_position = global_position.move_toward(HOME, 320.0 * delta)
			if global_position.distance_to(HOME) < 6.0:
				_end_attack(1.0)
		&"fireballs":
			_volley_timer -= delta
			if _volleys_left > 0 and _volley_timer <= 0.0:
				_volley_timer = 0.55
				_volleys_left -= 1
				if p:
					var origin := to_global(FURNACE)
					var base := (p.global_position - origin).angle()
					for i in 7:
						var a := base + deg_to_rad(12.0) * (i - 3)
						GameState.world.fire_enemy_fireball(origin, Vector2.from_angle(a) * 190.0, 12.0)
					Sfx.play(&"enemy_shoot", -4.0, 0.0)
			if _volleys_left <= 0 and _volley_timer <= 0.0:
				_end_attack(1.4)
		&"summon":
			if _state_time <= 0.0:
				for side in [-1.0, 1.0]:
					var from := Vector2(360 + side * 420.0, 260.0)
					GameState.world.spawn_enemy(&"heat_drone", from, Vector2(360 + side * 200.0, 420.0), true)
				_end_attack(1.4)


func _start_attack(kind: StringName) -> void:
	var p := _player()
	match kind:
		&"slam":
			_state = &"slam_warn"
			_state_time = SLAM_WARN
			_leap_from = global_position
			_slam_target = (p.global_position if p else Vector2(360, 900)).clamp(Vector2(120, 260), Vector2(600, 1150))
			telegraph.warn_pos = _slam_target
			telegraph.warn_radius = _slam_radius
			telegraph.warn_progress = 0.0
			telegraph.warn_active = true
			Sfx.play(&"charge", -8.0, 0.1)
		&"fireballs":
			_state = &"fireballs"
			_volleys_left = 2
			_volley_timer = 0.4
		&"summon":
			_state = &"summon"
			_state_time = 0.7
			Sfx.play(&"alarm", -14.0, 0.0)


func _slam_impact() -> void:
	telegraph.warn_active = false
	telegraph.flame_ring(_slam_target, _slam_radius)
	sprite.scale = Vector2.ONE * 0.55
	GameState.world.area_blast(_slam_target, _slam_radius, SLAM_DAMAGE, 0.0, 1.9, true)
	for i in 8:
		var a := i * TAU / 8.0
		GameState.world.spawn_explosion(_slam_target + Vector2.from_angle(a) * _slam_radius * 0.8, 0.7)
	GameState.world.shake(0.9)
	Sfx.play(&"slam", 2.0, 0.0)
	_state = &"slam_recover"
	_state_time = 0.7
	# Enraged below 40%: bigger slams.
	if hp < max_hp * 0.4:
		_slam_radius = SLAM_RADIUS * 1.3


func _end_attack(idle_time: float) -> void:
	_state = &"idle"
	_state_time = idle_time
	telegraph.warn_active = false


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	telegraph.warn_active = false
	GameState.boss_changed.emit(0.0, max_hp)
	for i in 8:
		get_tree().create_timer(i * 0.12, false).timeout.connect(func() -> void:
			GameState.world.spawn_explosion(global_position + Vector2(randf_range(-90, 90), randf_range(-90, 90)), randf_range(0.9, 1.5))
			GameState.world.shake(0.4)
			Sfx.play(&"explode", -4.0, 0.2))
	await get_tree().create_timer(1.1, false).timeout
	GameState.world.spawn_explosion(global_position, 3.0)
	GameState.world.shake(1.0)
	Sfx.play(&"big_explode", 2.0)
	for i in xp_orbs:
		GameState.world.spawn_xp(global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50)), xp_value)
	died.emit(self)
	queue_free()
