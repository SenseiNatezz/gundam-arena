extends Node2D
## Snow / ice impact: an expanding frosty ring, a white puff and flakes flung outward. Frees itself.

const LIFE := 0.5

var size := 1.0
var _t := 0.0
var _flakes: Array[Dictionary] = []


func _ready() -> void:
	z_index = 5
	for i in int(14 * size):
		_flakes.append({"pos": Vector2.ZERO, "vel": Vector2.from_angle(randf() * TAU) * randf_range(80.0, 260.0) * size,
			"r": randf_range(2.5, 5.0) * size})


func _process(delta: float) -> void:
	_t += delta
	for f in _flakes:
		f.pos += f.vel * delta
		f.vel *= 0.9
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var fade := 1.0 - k
	var r := (20.0 + 60.0 * ease(k, 0.4)) * size
	draw_circle(Vector2.ZERO, r * 0.8, Color(0.92, 0.97, 1.0, 0.45 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.7, 0.9, 1.0, 0.9 * fade), 4.0 * fade + 1.0, true)
	for f in _flakes:
		draw_circle(f.pos, f.r * fade, Color(1, 1, 1, 0.95 * fade))
