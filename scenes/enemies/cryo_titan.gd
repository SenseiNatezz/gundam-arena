extends Enemy
## Cryo Titan (Cryo Reactor boss): a crystalline golem that drifts across the top of the arena.
##   SHARD FAN : volleys of ice shards spread toward the player (chill).
##   SPIKE LINES: warning lines, then rows of ice spikes erupt along them; a spike hit freezes you.
##   HAILSTORM : icicles fall with growing shadows (several aimed at the player), bursting on impact.
##   SUMMON    : calls in frost drones.
## Below 50% HP it attacks faster with more spike lines and icicles.

const HOME := Vector2(360, 330)
const CORE := Vector2(0, 16)
const CYCLE := [&"shards", &"spikes", &"hail", &"shards", &"summon", &"spikes", &"hail"]
const SPIKE_WARN := 1.0
const SPIKE_TRAVEL := 0.45
const SPIKE_LINGER := 0.6
const SPIKE_LENGTH := 900.0
const SPIKE_SPACING := 48.0
const SPIKE_HIT_RADIUS := 34.0
const HAIL_FALL := 1.15
const HAIL_RADIUS := 58.0

var _state := &"idle"
var _state_time := 2.5
var _cycle := 0
var _volleys_left := 0
var _volley_timer := 0.0
var _spike_hit := false
var _enraged := false

@onready var telegraph: Node2D = $Telegraph


func _ready() -> void:
	super()
	GameState.boss_changed.emit(hp, max_hp)


func take_damage(amount: float, crit: bool, hit_dir: Vector2, knock := 170.0) -> void:
	super(amount, crit, hit_dir, knock)
	GameState.boss_changed.emit(maxf(hp, 0.0), max_hp)


func _behave(delta: float) -> void:
	var p := _player()
	_state_time -= delta
	if not _enraged and hp <= max_hp * 0.5:
		_enraged = true
		GameState.world.hud.show_banner("DEEP FREEZE", "The Cryo Titan grows colder", Color(0.6, 0.9, 1.0), 1.0)
		GameState.world.shake(0.5)
		Sfx.play(&"freeze", 0.0, 0.0)
	var target := HOME + Vector2(sin(t * 0.5) * 150.0, sin(t * 0.9) * 18.0)
	global_position = global_position.move_toward(target, move_speed * delta)
	if p:
		_face((p.global_position - global_position).angle(), delta, 1.5)
	match _state:
		&"idle":
			if _state_time <= 0.0:
				_start(CYCLE[_cycle % CYCLE.size()])
				_cycle += 1
		&"shards":
			_volley_timer -= delta
			if _volleys_left > 0 and _volley_timer <= 0.0 and p:
				_volley_timer = 0.45
				_volleys_left -= 1
				var origin := to_global(CORE)
				var base := (p.global_position - origin).angle()
				var count := 11 if _enraged else 9
				for i in count:
					var a := base + deg_to_rad(10.0) * (i - (count - 1) / 2.0)
					GameState.world.fire_enemy_ice_shard(origin, Vector2.from_angle(a) * 270.0, 12.0)
				Sfx.play(&"freeze", -10.0, 0.15)
			if _volleys_left <= 0 and _volley_timer <= 0.0:
				_end(1.4)
		&"spikes":
			var elapsed := SPIKE_WARN + SPIKE_TRAVEL + SPIKE_LINGER - _state_time
			var reach := clampf((elapsed - SPIKE_WARN) / SPIKE_TRAVEL, 0.0, 1.0) * SPIKE_LENGTH
			telegraph.spike_reach = reach
			if elapsed >= SPIKE_WARN and not _spike_hit and p and _spike_touches(p.global_position, reach):
				_spike_hit = true
				p.take_damage(20.0, telegraph.spike_origin, false, 1.5, 0.75)
			if _state_time <= 0.0:
				for tip in telegraph.spike_tips():
					GameState.world.spawn_snow_burst(tip, 0.35)
				_end(1.2)
		&"hail":
			for icicle in telegraph.icicles:
				if not icicle.landed and icicle.t >= HAIL_FALL:
					icicle.landed = true
					GameState.world.frost_blast(icicle.pos, HAIL_RADIUS, 16.0, 1.8, 0.0, 0.9)
			if _state_time <= 0.0:
				telegraph.icicles.clear()
				_end(1.2)
		&"summon":
			if _state_time <= 0.0:
				for side in [-1.0, 1.0]:
					var from := Vector2(360 + side * 420.0, 260.0)
					GameState.world.spawn_enemy(&"frost_drone", from, Vector2(360 + side * 170.0, 440.0), true)
				_end(1.4)


func _start(kind: StringName) -> void:
	var p := _player()
	_state = kind
	match kind:
		&"shards":
			_volleys_left = 3
			_volley_timer = 0.3
		&"spikes":
			_state_time = SPIKE_WARN + SPIKE_TRAVEL + SPIKE_LINGER
			_spike_hit = false
			var base := (p.global_position - to_global(CORE)).angle() if p else PI / 2
			var lines := 5 if _enraged else 3
			var dirs: Array[Vector2] = []
			for i in lines:
				dirs.append(Vector2.from_angle(base + deg_to_rad(22.0) * (i - (lines - 1) / 2.0)))
			telegraph.start_spikes(to_global(CORE), dirs, SPIKE_LENGTH, SPIKE_SPACING)
			Sfx.play(&"charge", -8.0, 0.1)
		&"hail":
			_state_time = HAIL_FALL + 0.4
			var count := 12 if _enraged else 8
			var spots: Array[Vector2] = []
			for i in count:
				var spot: Vector2
				if p and i < count / 2:
					spot = p.global_position + Vector2(randf_range(-110, 110), randf_range(-110, 110))
				else:
					spot = Vector2(randf_range(150, 570), randf_range(240, 1050))
				spots.append(spot.clamp(Vector2(140, 215), Vector2(580, 1055)))
			telegraph.start_hail(spots, HAIL_FALL, HAIL_RADIUS)
			Sfx.play(&"alarm", -16.0, 0.0)
		&"summon":
			_state_time = 0.6


func _end(idle_time: float) -> void:
	_state = &"idle"
	_state_time = idle_time * (0.75 if _enraged else 1.0)
	telegraph.stop_spikes()


func _spike_touches(point: Vector2, reach: float) -> bool:
	for tip in telegraph.spike_points(reach):
		if point.distance_to(tip) < SPIKE_HIT_RADIUS:
			return true
	return false


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	telegraph.stop_spikes()
	telegraph.icicles.clear()
	GameState.boss_changed.emit(0.0, max_hp)
	for i in 10:
		get_tree().create_timer(i * 0.11, false).timeout.connect(func() -> void:
			var at := global_position + Vector2(randf_range(-120, 120), randf_range(-110, 110))
			GameState.world.spawn_snow_burst(at, randf_range(0.9, 1.5))
			GameState.world.spawn_explosion(at, randf_range(0.6, 1.0))
			GameState.world.shake(0.35)
			Sfx.play(&"freeze", -4.0, 0.2))
	await get_tree().create_timer(1.25, false).timeout
	GameState.world.spawn_snow_burst(global_position, 3.0)
	GameState.world.spawn_explosion(global_position, 2.6)
	GameState.world.shake(1.0)
	Sfx.play(&"big_explode", 2.0)
	for i in xp_orbs:
		GameState.world.spawn_xp(global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60)), xp_value)
	died.emit(self)
	queue_free()
