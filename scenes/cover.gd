class_name Cover
extends Area2D
## Destructible arena cover: crates, red barrels, reactor pylons and forge rocks.
## Blocks the player's movement and enemy projectiles (player shots fly over it), cracks as it
## takes hits, and breaks into walk-over rubble after `max_hits`. Red barrels explode when they
## break, damaging nearby enemies (never the player).
##
## Created by Arena.setup(); set kind/size/radius/max_hits before adding it to the tree.

const COVER_LAYER := 64  # physics layer 7 "cover"

var kind := &"crate"  # crate, barrel, pylon, rock
var size := Vector2(60, 60)  # crates
var radius := 20.0  # barrels, pylons, rocks
var max_hits := 5
var hits_left := 5
var broken := false

var _flash := 0.0
var _shake := 0.0
var _t := 0.0
var _seed := 0
var _body: StaticBody2D


func _ready() -> void:
	add_to_group("cover")
	z_as_relative = false
	z_index = -3  # above floor decals, below enemies and the player
	collision_layer = COVER_LAYER
	collision_mask = 0
	monitoring = false
	hits_left = max_hits
	_seed = int(global_position.x * 7 + global_position.y * 13)
	# Area shape: what enemy projectiles hit. Static body: what blocks the player's mech.
	add_child(_make_shape(1.0))
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.add_child(_make_shape(0.8 if kind == &"rock" else 1.0))
	add_child(_body)


func _make_shape(scale_factor: float) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	if kind == &"crate":
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
	else:
		var circle := CircleShape2D.new()
		circle.radius = radius * scale_factor
		shape.shape = circle
	return shape


## Called by enemy projectiles (1 hit) and explosions (several hits).
func take_hit(amount: int, from_pos: Vector2) -> void:
	if broken:
		return
	hits_left -= amount
	_flash = 1.0
	_shake = 1.0
	GameState.world.spawn_hit_spark(from_pos, Color(1, 0.8, 0.5))
	Sfx.play(&"hit", -12.0, 0.25)
	if hits_left <= 0:
		_break()
	queue_redraw()


func _break() -> void:
	broken = true
	set_deferred("monitorable", false)
	_body.queue_free()
	GameState.world.spawn_explosion(global_position, 0.9 if kind == &"barrel" else 0.7)
	GameState.world.shake(0.25)
	Sfx.play(&"explode", -8.0, 0.2)
	if kind == &"barrel":
		# Explosive barrel: hurts enemies around it, never the player.
		GameState.world.area_blast(global_position, 115.0, 0.0, 90.0, 1.3)


func _process(delta: float) -> void:
	_t += delta
	var animating := _flash > 0.0 or _shake > 0.0
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	_shake = move_toward(_shake, 0.0, delta * 8.0)
	if animating or (kind == &"pylon" and not broken and int(_t * 8.0) != int((_t - delta) * 8.0)):
		queue_redraw()


# --- drawing -----------------------------------------------------------------------------------

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	if broken:
		_draw_rubble(rng)
		return
	var o := Vector2(randf_range(-3, 3), randf_range(-3, 3)) * _shake
	match kind:
		&"crate":
			_draw_crate(Rect2(-size / 2 + o, size))
		&"barrel":
			_draw_barrel(o)
		&"pylon":
			_draw_pylon(o)
		&"rock":
			_draw_rock(o, rng)
	_draw_cracks(o, rng)
	if _flash > 0.0:
		var white := Color(1, 1, 1, 0.45 * _flash)
		if kind == &"crate":
			draw_rect(Rect2(-size / 2 + o, size), white)
		else:
			draw_circle(o, radius, white)


func _draw_cracks(o: Vector2, rng: RandomNumberGenerator) -> void:
	var damage := 1.0 - float(hits_left) / max_hits
	var count := int(damage * 6.0)
	var reach := (minf(size.x, size.y) * 0.5 if kind == &"crate" else radius) * 0.9
	for i in count:
		var p := o
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var pts := PackedVector2Array([p])
		for s in 3:
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir * reach / 3.0
			pts.append(p)
		draw_polyline(pts, Color(0.02, 0.02, 0.02, 0.85), 2.5)


func _draw_rubble(rng: RandomNumberGenerator) -> void:
	var spread := maxf(size.x, size.y) * 0.6 if kind == &"crate" else radius * 1.2
	var color: Color = {&"crate": Color(0.5, 0.33, 0.1), &"barrel": Color(0.45, 0.1, 0.07),
		&"pylon": Color(0.25, 0.22, 0.2), &"rock": Color(0.12, 0.1, 0.095)}[kind]
	draw_circle(Vector2.ZERO, spread * 0.8, Color(0, 0, 0, 0.3))
	for i in 9:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0, spread)
		var s := rng.randf_range(4.0, 9.0)
		var a := rng.randf() * TAU
		var chunk := PackedVector2Array([p + Vector2.from_angle(a) * s, p + Vector2.from_angle(a + 2.1) * s * 0.7,
			p + Vector2.from_angle(a + 4.0) * s * 0.8])
		draw_colored_polygon(chunk, color.darkened(rng.randf_range(0.0, 0.4)))


func _draw_crate(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(7, 9), r.size), Color(0, 0, 0, 0.4))
	draw_rect(r, Color(0.2, 0.13, 0.05))
	var top := r.grow(-4)
	draw_rect(top, Color(0.62, 0.42, 0.12))
	draw_rect(top.grow(-6), Color(0.52, 0.34, 0.09))
	draw_line(top.position + Vector2(6, 6), top.end - Vector2(6, 6), Color(0.68, 0.48, 0.16), 5.0)
	draw_line(Vector2(top.end.x - 6, top.position.y + 6), Vector2(top.position.x + 6, top.end.y - 6), Color(0.68, 0.48, 0.16), 5.0)
	draw_line(top.position, Vector2(top.end.x, top.position.y), Color(1, 0.9, 0.6, 0.35), 2.0)
	for corner in [top.position, Vector2(top.end.x - 12, top.position.y), Vector2(top.position.x, top.end.y - 12), top.end - Vector2(12, 12)]:
		draw_rect(Rect2(corner, Vector2(12, 12)), Color(0.12, 0.12, 0.13))
		draw_line(corner + Vector2(0, 12), corner + Vector2(12, 0), Color(0.95, 0.7, 0.1), 3.0)


func _draw_barrel(p: Vector2) -> void:
	draw_circle(p + Vector2(6, 8), radius + 2, Color(0, 0, 0, 0.4))
	draw_circle(p, radius + 1, Color(0.35, 0.07, 0.05))
	draw_circle(p, radius - 3, Color(0.62, 0.12, 0.08))
	draw_arc(p, radius - 8, 0, TAU, 32, Color(0.3, 0.05, 0.04), 2.0)
	draw_circle(p + Vector2(-6, -6), 4, Color(0.2, 0.2, 0.22))
	draw_arc(p, radius - 1, PI, PI * 1.5, 16, Color(1, 0.8, 0.7, 0.35), 2.0)
	# Hazard mark so players learn barrels go boom.
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 5), p + Vector2(-6, 5)]), Color(1, 0.8, 0.15, 0.9))


func _draw_pylon(p: Vector2) -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 3.0)
	draw_circle(p + Vector2(7, 10), radius + 2, Color(0, 0, 0, 0.45))
	draw_circle(p, radius, Color(0.2, 0.17, 0.15))
	draw_arc(p, radius - 3, 0, TAU, 40, Color(0.45, 0.4, 0.36), 4.0, true)
	for i in 6:
		var a := i * TAU / 6.0
		draw_line(p + Vector2.from_angle(a) * 18, p + Vector2.from_angle(a) * (radius - 6), Color(0.08, 0.07, 0.06), 3.0)
	draw_circle(p, 18, Color(0.05, 0.25, 0.28))
	draw_circle(p, 13, Color(0.3, 0.9, 1.0, 0.6 + 0.4 * pulse))
	draw_circle(p - Vector2(4, 4), 5, Color(0.85, 1.0, 1.0))


func _draw_rock(p: Vector2, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(p + Vector2.from_angle(i * TAU / 9.0) * radius * rng.randf_range(0.75, 1.1))
	draw_colored_polygon(pts, Color(0.12, 0.1, 0.095))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 0.35, 0.05, 0.6), 2.5, true)
	draw_circle(p - Vector2(radius * 0.25, radius * 0.25), radius * 0.35, Color(1, 0.9, 0.8, 0.05))
