extends Enemy
## Spider-mech boss. Walks the top of the arena and cycles through telegraphed attacks:
## ground-slam circles, a charged laser, bullet rings and drone summons.

const ATTACK_CYCLE := [&"circles", &"laser", &"spray", &"summon", &"circles", &"laser", &"spray"]
const LASER_TIP := Vector2(0, 100)
const LASER_CHARGE := 1.3
const LASER_LOCK := 0.3
const LASER_FIRE := 1.1
const LASER_WIDTH := 64.0
const CIRCLE_RADIUS := 95.0
const CIRCLE_TIME := 1.15

var _state := &"walk"
var _state_time := 2.5
var _cycle := 0
var _walk_target := Vector2(360, 300)
var _laser_dir := Vector2.DOWN
var _laser_sound_played := false
var _spray_left := 0
var _spray_timer := 0.0
var _circles: Array[Dictionary] = []

@onready var telegraph: Node2D = $Telegraph


func _ready() -> void:
	super()
	GameState.boss_changed.emit(hp, max_hp)


func _on_arrived() -> void:
	_pick_walk_target()


func take_damage(amount: float, crit: bool, hit_dir: Vector2, knock := 170.0) -> void:
	super(amount, crit, hit_dir, knock)
	GameState.boss_changed.emit(maxf(hp, 0.0), max_hp)


func _behave(delta: float) -> void:
	var p := _player()
	_state_time -= delta
	telegraph.aura_pos = global_position
	telegraph.aura_strength = lerpf(telegraph.aura_strength, 0.35 if _state == &"walk" else 1.0, 1.0 - exp(-4.0 * delta))

	match _state:
		&"walk":
			global_position = global_position.move_toward(_walk_target, move_speed * delta)
			if global_position.distance_to(_walk_target) < 6.0:
				_pick_walk_target()
			if p:
				_face((p.global_position - global_position).angle(), delta, 1.5)
			if _state_time <= 0.0:
				_start_attack(ATTACK_CYCLE[_cycle % ATTACK_CYCLE.size()])
				_cycle += 1
		&"circles":
			for c in _circles:
				c.progress = clampf(1.0 - _state_time / CIRCLE_TIME, 0.0, 1.0)
			telegraph.circles = _circles
			if _state_time <= 0.0:
				_detonate_circles()
				_end_attack(1.6)
		&"laser":
			_update_laser(delta, p)
		&"spray":
			_spray_timer -= delta
			if _spray_left > 0 and _spray_timer <= 0.0:
				_spray_timer = 0.45
				_spray_left -= 1
				var count := 18
				var offset := randf() * TAU
				for i in count:
					var dir := Vector2.from_angle(offset + i * TAU / count)
					GameState.world.fire_enemy_bullet(global_position + dir * 60.0, dir * 230.0, 10.0)
				Sfx.play(&"enemy_shoot", -6.0)
			if _spray_left <= 0 and _spray_timer <= 0.0:
				_end_attack(1.4)
		&"summon":
			if _state_time <= 0.0:
				for i in 4:
					var from := global_position + Vector2(randf_range(-60, 60), 40)
					var to := Vector2(randf_range(120, 600), randf_range(420, 620))
					GameState.world.spawn_enemy(&"drone", from, to, true)
				_end_attack(1.5)


func _start_attack(kind: StringName) -> void:
	_state = kind
	var p := _player()
	match kind:
		&"circles":
			_state_time = CIRCLE_TIME
			_circles.clear()
			var center := p.global_position if p else Vector2(360, 900)
			var lead := p.velocity * 0.5 if p else Vector2.ZERO
			_circles.append({"pos": center, "radius": CIRCLE_RADIUS, "progress": 0.0})
			_circles.append({"pos": center + lead + Vector2(randf_range(-160, 160), randf_range(-120, 120)), "radius": CIRCLE_RADIUS, "progress": 0.0})
			_circles.append({"pos": center + Vector2(randf_range(-220, 220), randf_range(-200, 60)), "radius": CIRCLE_RADIUS, "progress": 0.0})
			for c in _circles:
				c.pos = c.pos.clamp(Vector2(90, 220), Vector2(630, 1200))
			Sfx.play(&"charge", -12.0, 0.2)
		&"laser":
			_state_time = LASER_CHARGE + LASER_LOCK + LASER_FIRE
			_laser_sound_played = false
			telegraph.laser_mode = 1
			Sfx.play(&"charge", -4.0, 0.0)
		&"spray":
			_spray_left = 3
			_spray_timer = 0.3
		&"summon":
			_state_time = 0.6
			Sfx.play(&"alarm", -14.0, 0.0)


func _end_attack(walk_time: float) -> void:
	_state = &"walk"
	_state_time = walk_time
	_circles.clear()
	telegraph.circles = _circles
	telegraph.laser_mode = 0
	GameState.world.set_danger_tint(0.0)


func _update_laser(delta: float, p: Player) -> void:
	var elapsed := LASER_CHARGE + LASER_LOCK + LASER_FIRE - _state_time
	if elapsed < LASER_CHARGE:
		# Track the player while charging.
		if p:
			_face((p.global_position - global_position).angle(), delta, 3.5)
		telegraph.laser_mode = 1
	elif elapsed < LASER_CHARGE + LASER_LOCK:
		telegraph.laser_mode = 2
	else:
		telegraph.laser_mode = 3
		if not _laser_sound_played:
			_laser_sound_played = true
			Sfx.play(&"laser", 0.0, 0.0)
			GameState.world.set_danger_tint(0.22)
		GameState.world.shake(0.3)
		if p and _laser_hits(p.global_position):
			p.take_damage(30.0, p.global_position - _laser_dir * 50.0)
	_laser_dir = Vector2.from_angle(rotation + PI / 2)
	telegraph.laser_origin = to_global(LASER_TIP)
	telegraph.laser_dir = _laser_dir
	telegraph.laser_width = LASER_WIDTH
	if _state_time <= 0.0:
		_end_attack(1.8)


func _laser_hits(point: Vector2) -> bool:
	var origin := to_global(LASER_TIP)
	var along := (point - origin).dot(_laser_dir)
	if along < 0.0:
		return false
	var closest := origin + _laser_dir * along
	return point.distance_to(closest) < LASER_WIDTH * 0.5 + 22.0


func _detonate_circles() -> void:
	var p := _player()
	for c in _circles:
		GameState.world.spawn_explosion(c.pos, 1.4)
		if p and p.global_position.distance_to(c.pos) < c.radius + 10.0:
			p.take_damage(22.0, c.pos)
	GameState.world.shake(0.55)
	Sfx.play(&"slam", 0.0)


func _pick_walk_target() -> void:
	_walk_target = Vector2(randf_range(170, 550), randf_range(250, 340))


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_end_attack(0.0)
	telegraph.aura_strength = 0.0
	GameState.boss_changed.emit(0.0, max_hp)
	for i in 9:
		get_tree().create_timer(i * 0.13, false).timeout.connect(func() -> void:
			GameState.world.spawn_explosion(global_position + Vector2(randf_range(-110, 110), randf_range(-90, 90)), randf_range(0.8, 1.4))
			GameState.world.shake(0.35)
			Sfx.play(&"explode", -4.0, 0.2))
	await get_tree().create_timer(1.25, false).timeout
	GameState.world.spawn_explosion(global_position, 3.2)
	GameState.world.shake(1.0)
	Sfx.play(&"big_explode", 2.0)
	for i in xp_orbs:
		GameState.world.spawn_xp(global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40)), xp_value)
	died.emit(self)
	queue_free()
