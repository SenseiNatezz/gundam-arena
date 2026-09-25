extends Node2D
## I-Field shield bubble drawn around the player while it has charges.

var charges := 0:
	set(value):
		if value != charges:
			charges = value
			queue_redraw()
var _pop := 0.0
var _t := 0.0


func pop() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pop = move_toward(_pop, 0.0, delta * 3.0)
	if charges > 0 or _pop > 0.0:
		queue_redraw()


func _draw() -> void:
	var radius := 64.0 + _pop * 30.0
	if _pop > 0.0:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.4, 1.0, 0.9, _pop), 6.0 * _pop)
	if charges <= 0:
		return
	var a := 0.35 + sin(_t * 4.0) * 0.1
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(Vector2.from_angle(i * TAU / 6.0 + _t * 0.4) * 62.0)
	draw_colored_polygon(hex, Color(0.3, 1.0, 0.85, 0.06))
	hex.append(hex[0])
	draw_polyline(hex, Color(0.4, 1.0, 0.9, a), 2.5, true)
	for i in charges:
		draw_circle(Vector2(-10.0 * (charges - 1) + 20.0 * i, 74.0), 4.0, Color(0.5, 1.0, 0.9, 0.9))
