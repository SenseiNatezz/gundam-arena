extends Node2D
## Flat top-down rocket for the Homing Missiles upgrade: white body, red nose cone, dark band,
## four tail fins and a flickering exhaust flame. Drawn in local space pointing up (-Y), which
## is the direction the parent Bullet flies.

const LENGTH := 36.0
const WIDTH := 10.0

var _t := 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var half := WIDTH / 2.0
	var nose := -LENGTH * 0.5
	var tail := LENGTH * 0.5
	# Exhaust flame (flickers every frame).
	var flame := 12.0 + randf() * 7.0
	draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.8, tail), Vector2(half * 0.8, tail), Vector2(0, tail + flame)]),
		Color(1.0, 0.45, 0.08, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(-half * 0.45, tail), Vector2(half * 0.45, tail), Vector2(0, tail + flame * 0.6)]),
		Color(1.0, 0.9, 0.5))
	# Tail fins (four, seen from above: two sideways, two foreshortened).
	var fin := Color(0.55, 0.08, 0.06)
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(s * half, tail - 9.0), Vector2(s * (half + 5.0), tail + 1.0),
			Vector2(s * half, tail)]), fin)
	draw_line(Vector2(0, tail - 8.0), Vector2(0, tail + 1.0), fin.darkened(0.3), 2.0)
	# Body: dark outline, white tube, highlight stripe.
	var body := Rect2(-half, nose + 7.0, WIDTH, LENGTH - 7.0)
	draw_rect(body.grow(1.2), Color(0.1, 0.1, 0.12))
	draw_rect(body, Color(0.92, 0.93, 0.95))
	draw_rect(Rect2(-half + 1.2, body.position.y, 1.6, body.size.y), Color(1, 1, 1))
	draw_rect(Rect2(half - 2.2, body.position.y, 2.2, body.size.y), Color(0.7, 0.72, 0.78))
	# Dark band and nozzle.
	draw_rect(Rect2(-half, nose + 14.0, WIDTH, 3.0), Color(0.18, 0.2, 0.25))
	draw_rect(Rect2(-half * 0.75, tail - 1.5, WIDTH * 0.75, 3.0), Color(0.25, 0.25, 0.28))
	# Red nose cone.
	var cone := PackedVector2Array([Vector2(-half, nose + 7.0), Vector2(half, nose + 7.0), Vector2(0, nose)])
	draw_colored_polygon(PackedVector2Array([Vector2(-half - 1.2, nose + 7.6), Vector2(half + 1.2, nose + 7.6), Vector2(0, nose - 1.4)]),
		Color(0.1, 0.1, 0.12))
	draw_colored_polygon(cone, Color(0.9, 0.16, 0.1))
	draw_line(Vector2(-half + 1.5, nose + 6.5), Vector2(-0.5, nose + 1.0), Color(1, 0.6, 0.5), 1.2)
