extends Node2D
## Hyper Mega Cannon: the Gundam's unlockable special, drawn in a flat 2D "anime effects" style.
##   CHARGE (0.4s real time) - time slows, speed lines rush into a spiky energy ball at the muzzle.
##   FIRE   (0.9s)           - a cel-shaded beam with jagged edges, ring bands and a star burst at
##                              the tip; tracks slowly toward enemies and hits rapidly.
##   FADE   (0.25s)          - the beam thins out in steps and breaks into sparks.
## All shapes are redrawn at STEP_FPS (like hand-drawn animation "on twos"), not every frame.
## Spawned by Player.start_special(); frees itself when done.

signal finished

@export var beam_width := 54.0
@export var max_length := 820.0
@export var outline_color := Color(0.06, 0.08, 0.3)
@export var outer_color := Color(0.15, 0.7, 1.0)
@export var inner_color := Color(0.6, 0.95, 1.0)
@export var core_color := Color(1, 1, 1)

const CHARGE_TIME := 0.4
const FIRE_TIME := 0.9
const FADE_TIME := 0.25
const SLOWMO := 0.15
const STEP_FPS := 14.0
const TICK := 0.08
const TRACK_RATE := 0.8  # rad/s the beam sweeps toward enemies while firing
const EXTEND_SPEED := 5200.0  # px/s the beam front travels
const SCORCH := preload("res://scenes/abilities/beam_scorch.gd")

var player: Player
var power := 1.0  # damage multiplier from extra upgrade stacks

var _t := 0.0  # unscaled seconds since cast
var _phase := &"charge"
var _step := -1
var _tick_timer := 0.0
var _hits := 0
var _angle := 0.0
var _width := 0.0
var _length := 0.0
var _rng := RandomNumberGenerator.new()
var _sparks: Array[Dictionary] = []
## Time scale in effect when this frame's delta was computed (set at the end of the previous frame).
var _frame_scale := 1.0


func _ready() -> void:
	z_index = 1  # above enemies, below the player
	top_level = true
	global_position = Vector2.ZERO
	_angle = player.aim_angle
	Engine.time_scale = SLOWMO
	GameState.world.cinematic_focus(player.global_position, 1.06, 0.18)
	GameState.world.hud.show_cutin("HYPER MEGA CANNON")
	Sfx.play(&"super_flash", -4.0, 0.0)
	Sfx.play(&"charge", -5.0, 0.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var real := minf(delta / _frame_scale, 0.1)
	_t += real
	var muzzle := player.cannon_muzzle.global_position
	var dir := Vector2.from_angle(_angle)

	match _phase:
		&"charge":
			player.sprite.frame = mini(int(_t / CHARGE_TIME * 7.0), 5)
			if _t >= CHARGE_TIME:
				_start_fire()
		&"fire":
			var ft := _t - CHARGE_TIME
			_length = clampf(ft * EXTEND_SPEED, 90.0, max_length)
			# Pops in fat, then settles (the overshoot reads as impact).
			_width = beam_width * (1.35 if ft < 0.1 else 1.0)
			_track_target(real)
			_tick_timer -= real
			if _tick_timer <= 0.0:
				_tick_timer = TICK
				_damage_tick(muzzle, dir)
			GameState.world.shake(0.1)
			player.body.position = -dir.rotated(-player.body.rotation) * 3.0
			if ft >= FIRE_TIME:
				_phase = &"fade"
				_step = -1
				_leave_scorch(muzzle, dir)
				for i in 10:
					_spawn_spark(muzzle + dir * randf() * _length, 1.4)
		&"fade":
			var k := clampf((_t - CHARGE_TIME - FIRE_TIME) / FADE_TIME, 0.0, 1.0)
			_width = beam_width * [0.6, 0.3, 0.12, 0.0][mini(int(k * 4.0), 3)]  # stepped, not smooth
			player.body.position = player.body.position.lerp(Vector2.ZERO, 0.3)
			if k >= 1.0 and _sparks.is_empty():
				_finish()
				return

	player.aim_angle = _angle
	player.body.rotation = _angle + PI / 2
	_update_sparks(real)
	var step := int(_t * STEP_FPS)
	if step != _step:
		_step = step
		_on_new_step(muzzle, dir)
		queue_redraw()
	_frame_scale = Engine.time_scale


func _on_new_step(muzzle: Vector2, dir: Vector2) -> void:
	if _phase == &"fire":
		for i in 2:
			_spawn_spark(muzzle + dir * _length, 1.0)
		_spawn_spark(muzzle, 0.7)


func _start_fire() -> void:
	_phase = &"fire"
	Engine.time_scale = 1.0
	player.sprite.frame = 5
	# Start the beam this very frame (no empty gap between the charge and the shot).
	_width = beam_width * 1.35
	_length = 90.0
	_step = -1
	GameState.world.cinematic_focus(Vector2.ZERO, 1.0, 0.25)
	GameState.world.shake(0.45)
	Sfx.play(&"cannon_fire", -2.0, 0.0)


## Slowly sweep toward the enemy closest to the beam's current heading.
func _track_target(real: float) -> void:
	var best: Enemy = null
	var best_score := INF
	var origin := player.global_position
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not e.is_targetable():
			continue
		var off := angle_difference(_angle, (e.global_position - origin).angle())
		var score := absf(off) * 400.0 + origin.distance_to(e.global_position) * 0.2
		if score < best_score:
			best_score = score
			best = e
	if best:
		_angle = rotate_toward(_angle, (best.global_position - origin).angle(), TRACK_RATE * real)


func _damage_tick(origin: Vector2, dir: Vector2) -> void:
	var hit_any := false
	var damage: float = GameState.stats.damage * 1.8 * power
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.global_position.y < 0.0:
			continue
		var along := (e.global_position - origin).dot(dir)
		if along < -20.0 or along > _length + 20.0:
			continue
		var gap := e.global_position.distance_to(origin + dir * along)
		if gap < _width * 0.5 + e.hit_radius:
			var crit: bool = randf() < GameState.stats.crit_chance
			e.take_damage(damage * randf_range(0.9, 1.1) * (2.0 if crit else 1.0), crit, dir, 70.0)
			_spawn_spark(e.global_position, 1.0)
			_hits += 1
			hit_any = true
	if hit_any:
		GameState.world.hud.show_hit_counter(_hits)


func _spawn_spark(pos: Vector2, speed: float) -> void:
	_sparks.append({
		"pos": pos,
		"vel": Vector2.from_angle(randf() * TAU) * randf_range(180.0, 420.0) * speed,
		"life": randf_range(0.2, 0.35),
		"size": randf_range(5.0, 9.0),
	})


func _update_sparks(real: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.pos += s.vel * real
		s.vel *= 0.9
		s.life -= real
		if s.life <= 0.0:
			_sparks.remove_at(i)


func _leave_scorch(origin: Vector2, dir: Vector2) -> void:
	var scorch := Node2D.new()
	scorch.set_script(SCORCH)
	scorch.set("from", origin)
	scorch.set("to", origin + dir * _length)
	GameState.world.add_floor_decal(scorch)


func _finish() -> void:
	Engine.time_scale = 1.0
	player.body.position = Vector2.ZERO
	finished.emit()
	queue_free()


# --- drawing (flat cel layers, re-rolled every animation step) --------------------------------

func _draw() -> void:
	_rng.seed = _step * 7919 + 17
	var muzzle := player.cannon_muzzle.global_position
	var dir := Vector2.from_angle(_angle)
	match _phase:
		&"charge":
			_draw_charge(muzzle)
		&"fire", &"fade":
			if _width > 0.5:
				_draw_beam(muzzle, dir)
	for s in _sparks:
		_diamond(s.pos, s.size * clampf(s.life / 0.2, 0.3, 1.0), s.vel.angle())


func _draw_charge(muzzle: Vector2) -> void:
	var k := clampf(_t / CHARGE_TIME, 0.0, 1.0)
	# Light dim of the arena (under the player, so the mech stays lit).
	draw_rect(Rect2(-100, -100, 920, 1480), Color(0.02, 0.02, 0.08, 0.3 * minf(k * 3.0, 1.0)))
	# Speed lines rushing into the muzzle.
	for i in 9:
		var a := _rng.randf() * TAU
		var far := _rng.randf_range(120.0, 240.0) * (1.0 - k * 0.5)
		var near := far * _rng.randf_range(0.3, 0.5)
		var p0 := muzzle + Vector2.from_angle(a) * far
		var p1 := muzzle + Vector2.from_angle(a) * near
		var side := Vector2.from_angle(a).orthogonal()
		# Tapered streak: dark outline underneath, bright fill on top.
		draw_colored_polygon(PackedVector2Array([p0 + (p0 - p1).normalized() * 4.0, p1 + side * 7.0, p1 - side * 7.0]), outline_color)
		draw_colored_polygon(PackedVector2Array([p0, p1 + side * 4.0, p1 - side * 4.0]), inner_color)
	# Spiky energy ball that grows in steps, with an outline ring pulsing around it.
	var r := lerpf(12.0, 30.0, ease(k, 1.4))
	draw_arc(muzzle, r * 2.1 * (1.1 if _step % 2 == 0 else 0.95), 0.0, TAU, 24, outline_color, 6.0)
	draw_arc(muzzle, r * 2.1 * (1.1 if _step % 2 == 0 else 0.95), 0.0, TAU, 24, inner_color, 2.5)
	_star(muzzle, r * 1.6, r * 0.85, 10, _rng.randf() * TAU, [outline_color, outer_color, core_color])


func _draw_beam(muzzle: Vector2, dir: Vector2) -> void:
	# One-step "impact frame" flash the instant it fires.
	if _phase == &"fire" and _t - CHARGE_TIME < 1.0 / STEP_FPS:
		draw_rect(Rect2(-100, -100, 920, 1480), Color(inner_color, 0.28))
	var half := _width * 0.5
	_band(muzzle, dir, _length, half + 5.0, 5.0, outline_color)
	_band(muzzle, dir, _length, half, 5.0, outer_color)
	_band(muzzle, dir, _length, half * 0.62, 3.5, inner_color)
	_band(muzzle, dir, _length, half * 0.28, 2.0, core_color)
	# Ring bands travelling down the beam (positions advance each step).
	var perp := dir.orthogonal()
	for i in 3:
		var d := fmod(_step * 70.0 + i * _length / 3.0, maxf(_length, 1.0))
		if d < 40.0:
			continue
		var c := muzzle + dir * d
		var ring := PackedVector2Array()
		for j in 13:
			var a := j * TAU / 12.0
			ring.append(c + dir * cos(a) * 7.0 + perp * sin(a) * (half + 11.0))
		draw_polyline(ring, outline_color, 7.0)
		draw_polyline(ring, inner_color, 3.5)
	# Star burst at the tip and a flash at the muzzle.
	var tip := muzzle + dir * _length
	var burst := half * (1.5 if _step % 2 == 0 else 1.25)
	_star(tip, burst, burst * 0.5, 9, _rng.randf() * TAU, [outline_color, outer_color, core_color])
	_star(muzzle, half * 1.05, half * 0.5, 7, _rng.randf() * TAU, [outline_color, inner_color, core_color])


## One flat layer of the beam: a band with jagged edges, a slight taper at the muzzle and a
## pointed cap at the tip.
func _band(origin: Vector2, dir: Vector2, length: float, half_w: float, jag: float, color: Color) -> void:
	if length < 4.0 or half_w < 1.0:
		return
	var perp := dir.orthogonal()
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var seg := 26.0
	var n := maxi(int(length / seg), 1)
	for i in n + 1:
		var d := minf(i * seg, length)
		var taper := lerpf(0.45, 1.0, minf(d / 40.0, 1.0))
		var j := minf(jag, half_w * taper * 0.6)  # keep edges from crossing on thin bands
		top.append(origin + dir * d + perp * (half_w * taper + _rng.randf_range(-j, j)))
		bottom.append(origin + dir * d - perp * (half_w * taper + _rng.randf_range(-j, j)))
	var poly := PackedVector2Array()
	poly.append(origin - dir * half_w * 0.3)
	poly.append_array(top)
	poly.append(origin + dir * (length + half_w * 0.7))
	bottom.reverse()
	poly.append_array(bottom)
	draw_colored_polygon(poly, color)


## Layered spiky star (outline → colour → core), used for the charge ball, tip burst and muzzle flash.
func _star(c: Vector2, outer_r: float, inner_r: float, points: int, rot: float, colors: Array) -> void:
	var scales := [1.0, 0.8, 0.5]
	for layer in 3:
		var pts := PackedVector2Array()
		for i in points * 2:
			var r: float = (outer_r if i % 2 == 0 else inner_r) * scales[layer]
			r *= _rng.randf_range(0.85, 1.15) if i % 2 == 0 else 1.0
			pts.append(c + Vector2.from_angle(rot + i * PI / points) * r)
		draw_colored_polygon(pts, colors[layer])


func _diamond(c: Vector2, size: float, rot: float) -> void:
	var fwd := Vector2.from_angle(rot) * size
	var side := fwd.orthogonal() * 0.45
	draw_colored_polygon(PackedVector2Array([c + fwd + fwd * 0.3, c + side, c - fwd, c - side]), outline_color)
	draw_colored_polygon(PackedVector2Array([c + fwd * 0.9, c + side * 0.5, c - fwd * 0.6, c - side * 0.5]), core_color)
