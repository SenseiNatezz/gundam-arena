extends Node2D
## Glowing scorch line the Hyper Mega Cannon leaves on the floor; cools and fades over ~2.5s.

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0

const LIFE := 2.5


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var fade := 1.0 - k
	var heat := clampf(1.0 - k * 4.0, 0.0, 1.0)
	draw_line(from, to, Color(0.02, 0.02, 0.03, 0.5 * fade), 34.0)
	draw_line(from, to, Color(0.05, 0.04, 0.05, 0.45 * fade), 20.0)
	if heat > 0.0:
		draw_line(from, to, Color(1.0, 0.45, 0.15, 0.5 * heat), 9.0)
		draw_line(from, to, Color(1.0, 0.85, 0.5, 0.55 * heat), 3.0)
