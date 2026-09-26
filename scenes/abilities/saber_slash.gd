extends Node2D
## Beam Saber spin slash: a flat crescent of energy sweeps one full turn around the mech.
## Enemies are hit (once each) the moment the blade passes their angle and are knocked outward;
## enemy projectiles inside the circle are sliced out of the air. Added as a child of the Player
## so it follows the mech; frees itself when done.

const DURATION := 0.5
const RADIUS := 150.0  # outer reach of the blade
const INNER := 70.0  # inner edge of the crescent
const SWEEP := TAU * 1.05  # a touch more than a full circle so the start overlaps
const TAIL := 1.9  # radians of trailing crescent behind the leading edge
const KNOCKBACK := 420.0

var damage := 100.0
var start_angle := 0.0

var _t := 0.0
var _head := 0.0
var _hit: Array[Node] = []
var _sparks: Array[Dictionary] = []


func _ready() -> void:
	z_as_relative = false
	z_index = 5
	_head = start_angle
	Sfx.play(&"saber", -2.0, 0.08)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var prev := _head
	_head = start_angle + SWEEP * ease(k, 0.55)  # fast start, eases out
	if k < 1.0:
		_sweep_hits(prev, _head)
		for i in 2:
			var a := _head + randf_range(-0.1, 0.1)
			var p := global_position + Vector2.from_angle(a) * randf_range(INNER + 30.0, RADIUS)
			_sparks.append({"pos": p, "vel": Vector2.from_angle(a + PI / 2) * randf_range(250.0, 520.0), "life": randf_range(0.15, 0.3)})
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.pos += s.vel * delta
		s.vel *= 0.9
		s.life -= delta
		if s.life <= 0.0:
			_sparks.remove_at(i)
	if k >= 1.0 and _t > DURATION + 0.18 and _sparks.is_empty():
		queue_free()
		return
	queue_redraw()


## Hit every enemy / enemy bullet whose angle the blade swept past this frame.
func _sweep_hits(from_angle: float, to_angle: float) -> void:
	var center := global_position
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(e) or not e.is_targetable():
			continue
		var off := e.global_position - center
		if off.length() > RADIUS + e.hit_radius:
			continue
		if _swept(off.angle(), from_angle, to_angle) or off.length() < INNER:
			_hit.append(e)
			var crit: bool = randf() < GameState.stats.crit_chance
			var out := off.normalized() if off.length() > 1.0 else Vector2.from_angle(to_angle)
			e.take_damage(damage * randf_range(0.95, 1.05) * (1.5 if crit else 1.0), crit, out, KNOCKBACK)
			GameState.world.spawn_hit_spark(e.global_position, Color(0.6, 0.9, 1.0))
			GameState.world.shake(0.12)
	# Slice enemy projectiles out of the air.
	for b: Bullet in GameState.world.enemy_projectiles():
		if not b.active:
			continue
		var off := b.global_position - center
		if off.length() < RADIUS and _swept(off.angle(), from_angle, to_angle):
			GameState.world.spawn_hit_spark(b.global_position, Color(0.8, 0.95, 1.0))
			b.deactivate()


func _swept(angle: float, from_angle: float, to_angle: float) -> bool:
	var span := to_angle - from_angle
	var rel := fposmod(angle - from_angle, TAU)
	return rel <= span + 0.05


func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var fade := 1.0 - clampf((_t - DURATION) / 0.18, 0.0, 1.0)
	# Faint afterimage ring of the whole swing.
	draw_arc(Vector2.ZERO, (INNER + RADIUS) * 0.5, 0.0, TAU, 64, Color(0.4, 0.75, 1.0, 0.12 * fade * k), RADIUS - INNER)
	if fade > 0.0:
		# Crescent layers: soft blue glow, cyan body, white-hot leading edge.
		_crescent(RADIUS + 16.0, INNER - 10.0, TAIL, Color(0.2, 0.5, 1.0, 0.45 * fade))
		_crescent(RADIUS, INNER, TAIL * 0.85, Color(0.35, 0.85, 1.0, 0.92 * fade))
		_crescent(RADIUS - 6.0, INNER + 22.0, TAIL * 0.55, Color(0.92, 0.99, 1.0, fade))
		# Bright rim along the outer edge near the tip.
		var rim := PackedVector2Array()
		for i in 13:
			var a := _head - TAIL * 0.6 * i / 12.0
			rim.append(Vector2.from_angle(a) * RADIUS)
		draw_polyline(rim, Color(1, 1, 1, 0.95 * fade), 5.0, true)
		var inner_rim := PackedVector2Array()
		for i in 9:
			inner_rim.append(Vector2.from_angle(_head - TAIL * 0.35 * i / 8.0) * (INNER + 6.0))
		draw_polyline(inner_rim, Color(0.7, 0.95, 1.0, 0.8 * fade), 3.0, true)
	for s in _sparks:
		var a: float = clampf(s.life / 0.2, 0.0, 1.0)
		var p: Vector2 = s.pos - global_position
		draw_line(p, p - s.vel * 0.03, Color(0.75, 0.95, 1.0, a), 2.0)


## Crescent from the leading edge back `tail` radians: full thickness at the head, tapering to a
## point at the tail.
func _crescent(outer: float, inner: float, tail: float, color: Color) -> void:
	var steps := 20
	var outer_pts := PackedVector2Array()
	var inner_pts := PackedVector2Array()
	for i in steps + 1:
		var u := float(i) / steps  # 0 at the head, 1 at the tail
		var a := _head - tail * u
		var thick := 1.0 - pow(u, 1.4)
		var mid := (outer + inner) * 0.5
		var half := (outer - inner) * 0.5 * thick
		outer_pts.append(Vector2.from_angle(a) * (mid + half))
		inner_pts.append(Vector2.from_angle(a) * (mid - half * 0.6))
	inner_pts.reverse()
	var poly := outer_pts
	poly.append_array(inner_pts)
	draw_colored_polygon(poly, color)
