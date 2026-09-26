extends Node2D
## Beam Rifle special: a piercing beam with a white-hot core, crackling lightning wrapped around
## it and energy rings pulsing at the muzzle. Every enemy on the line takes one big hit; the first
## one hit erupts in a starburst of sparks and flying debris. The beam flickers out over LIFE seconds.
## Spawned by Player.fire_beam(); frees itself when done.

const LIFE := 0.55
const HIT_WIDTH := 22.0  # beam half-width used for hits (plus each enemy's radius)
const SCREEN := Rect2(-20, -20, 760, 1320)  # the beam runs to the edge of the screen
const BOLT_REFRESH := 0.035  # lightning re-rolls this often (fast crackle)

var origin := Vector2.ZERO
var dir := Vector2.UP
var damage := 100.0

var _t := 0.0
var _length := 1200.0
var _impact := Vector2.ZERO
var _has_impact := false
var _bolts: Array[PackedVector2Array] = []
var _bolt_timer := 0.0
var _sparks: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_as_relative = false
	z_index = 6  # above enemies and the player, under the HUD
	_length = _exit_distance()
	_fire()
	_roll_bolts()


## Distance from the muzzle to where the beam leaves the screen. (The muzzle can sit past the
## arena walls when the mech hugs them, so only exits ahead of the beam count.)
func _exit_distance() -> float:
	var best := 1600.0
	for axis in 2:
		var d: float = dir[axis]
		if absf(d) < 0.0001:
			continue
		var edge: float = (SCREEN.end[axis] if d > 0.0 else SCREEN.position[axis])
		var dist := (edge - origin[axis]) / d
		if dist > 0.0:
			best = minf(best, dist)
	return best


func _fire() -> void:
	var hits: Array = []
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not e.is_targetable():
			continue
		var along := (e.global_position - origin).dot(dir)
		if along < 0.0 or along > _length + e.hit_radius:
			continue
		if e.global_position.distance_to(origin + dir * along) < HIT_WIDTH + e.hit_radius:
			hits.append([along, e])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for h in hits:
		var e: Enemy = h[1]
		var crit: bool = randf() < GameState.stats.crit_chance
		GameState.world.big_damage_numbers = true  # beam hits get the big number style
		e.take_damage(damage * randf_range(0.95, 1.05) * (1.5 if crit else 1.0), crit, dir, 260.0)
		GameState.world.big_damage_numbers = false
		GameState.world.spawn_hit_spark(e.global_position, Color(0.6, 0.9, 1.0))
	if not hits.is_empty():
		_has_impact = true
		_impact = origin + dir * hits[0][0]
		GameState.world.spawn_explosion(_impact, 0.8)
		_spawn_debris(_impact)
	# Sparks shed along the whole beam.
	for i in 44:
		var along := _rng.randf() * _length
		var side := dir.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
		_sparks.append({
			"pos": origin + dir * along,
			"vel": (side * _rng.randf_range(120.0, 380.0) + dir * _rng.randf_range(-80.0, 160.0)),
			"life": _rng.randf_range(0.2, 0.45),
		})
	GameState.world.shake(0.35)
	Sfx.play(&"beam_rifle", -2.0, 0.05)


func _spawn_debris(at: Vector2) -> void:
	for i in 16:
		var a := dir.angle() + _rng.randf_range(-1.3, 1.3)
		_debris.append({
			"pos": at,
			"vel": Vector2.from_angle(a) * _rng.randf_range(160.0, 520.0),
			"rot": _rng.randf() * TAU,
			"spin": _rng.randf_range(-12.0, 12.0),
			"size": _rng.randf_range(6.0, 13.0),
			"life": _rng.randf_range(0.5, 0.9),
		})


func _process(delta: float) -> void:
	_t += delta
	_bolt_timer -= delta
	if _bolt_timer <= 0.0 and _t < LIFE:
		_bolt_timer = BOLT_REFRESH
		_roll_bolts()
	for list in [_sparks, _debris]:
		for i in range(list.size() - 1, -1, -1):
			var p: Dictionary = list[i]
			p.pos += p.vel * delta
			p.vel *= 0.92
			p.life -= delta
			if p.has("rot"):
				p.rot += p.spin * delta
			if p.life <= 0.0:
				list.remove_at(i)
	if _t > LIFE and _sparks.is_empty() and _debris.is_empty():
		queue_free()
		return
	queue_redraw()


## Jagged lightning strands that hug the beam, each with a few short forks.
func _roll_bolts() -> void:
	_bolts.clear()
	var perp := dir.orthogonal()
	for strand in 4:
		var pts := PackedVector2Array()
		var d := 0.0
		while d < _length:
			var envelope := minf(d / 120.0, 1.0)  # tight at the muzzle, wilder further out
			pts.append(origin + dir * d + perp * _rng.randf_range(-19.0, 19.0) * envelope)
			d += _rng.randf_range(22.0, 40.0)
		pts.append(origin + dir * _length)
		_bolts.append(pts)
		for f in 3:
			var start := pts[_rng.randi_range(1, maxi(pts.size() - 2, 1))]
			var fork := PackedVector2Array([start])
			var fdir := (dir * _rng.randf_range(0.3, 0.8) + perp * (1.0 if _rng.randf() < 0.5 else -1.0)).normalized()
			for s in 3:
				fdir = fdir.rotated(_rng.randf_range(-0.6, 0.6))
				fork.append(fork[fork.size() - 1] + fdir * _rng.randf_range(10.0, 22.0))
			_bolts.append(fork)


func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	if k < 1.0:
		var fade := 1.0 - k * k
		var flicker := 1.0 + 0.15 * sin(_t * 90.0)
		var end := origin + dir * _length
		# Beam: soft blue glow → cyan body → white-hot core.
		draw_line(origin, end, Color(0.15, 0.35, 1.0, 0.25 * fade), 64.0 * flicker * fade)
		draw_line(origin, end, Color(0.3, 0.75, 1.0, 0.75 * fade), 30.0 * flicker * fade)
		draw_line(origin, end, Color(0.85, 0.97, 1.0, fade), 12.0 * flicker * fade)
		# Lightning wrapped around it.
		for bolt in _bolts:
			draw_polyline(bolt, Color(0.4, 0.8, 1.0, 0.45 * fade), 5.0)
			draw_polyline(bolt, Color(0.9, 0.98, 1.0, 0.95 * fade), 1.8)
		# Flat, top-down shockwave rings bursting out from the muzzle (no perspective, like the
		# rest of the game's straight-down view).
		for i in 2:
			var rk := clampf(k * 1.6 - i * 0.25, 0.0, 1.0)
			if rk <= 0.0 or rk >= 1.0:
				continue
			var rr := 14.0 + rk * (70.0 + i * 40.0)
			var ra := 1.0 - rk
			draw_arc(origin, rr, 0.0, TAU, 48, Color(0.3, 0.7, 1.0, 0.5 * ra), 8.0 * ra + 2.0)
			draw_arc(origin, rr, 0.0, TAU, 48, Color(0.85, 0.97, 1.0, 0.95 * ra), 3.0 * ra + 1.0)
		# Muzzle flash.
		draw_circle(origin, 22.0 * fade, Color(0.5, 0.85, 1.0, 0.5 * fade))
		draw_circle(origin, 10.0 * fade, Color(1, 1, 1, 0.95 * fade))
		# Impact starburst.
		if _has_impact:
			var burst := 1.0 - k
			draw_circle(_impact, 46.0 * burst, Color(0.55, 0.85, 1.0, 0.35 * burst))
			draw_circle(_impact, 20.0 * burst, Color(1, 1, 1, 0.9 * burst))
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_t * 30.0)
			for i in 14:
				var a := i * TAU / 14.0 + rng.randf_range(-0.2, 0.2)
				var len := rng.randf_range(40.0, 115.0) * burst
				var col := Color(1, 1, 1) if i % 3 == 0 else (Color(0.5, 0.85, 1.0) if i % 3 == 1 else Color(1, 0.6, 0.85))
				draw_line(_impact, _impact + Vector2.from_angle(a) * len, Color(col, 0.9 * burst), 3.0)
	for s in _sparks:
		var a: float = clampf(s.life / 0.3, 0.0, 1.0)
		draw_line(s.pos, s.pos - s.vel * 0.035, Color(0.7, 0.92, 1.0, a), 2.0)
	for d in _debris:
		var a: float = clampf(d.life / 0.4, 0.0, 1.0)
		var sz: float = d.size
		var pts := PackedVector2Array()
		for j in 3:
			pts.append(d.pos + Vector2.from_angle(d.rot + j * 2.2) * sz * (1.0 if j != 1 else 0.6))
		draw_colored_polygon(pts, Color(0.22, 0.24, 0.28, a))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.75, 0.9, 1.0, 0.8 * a), 1.5)
