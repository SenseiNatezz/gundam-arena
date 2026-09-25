extends Node2D
## Draws the Leviathan's attack warnings and hazards in world space: rotating reactor spokes
## (warning lines, then live beams) and the ramming lane.

var spoke_mode := 0  # 0 off, 1 warning, 2 firing
var spoke_origin := Vector2.ZERO
var spoke_angle := 0.0
var spoke_count := 3
var lane_mode := 0  # 0 off, 1 warning
var lane_x := 360.0
var lane_width := 190.0
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if lane_mode == 1:
		var blink := 0.5 + 0.5 * absf(sin(_t * 12.0))
		var rect := Rect2(lane_x - lane_width / 2.0, 150.0, lane_width, 1130.0)
		draw_rect(rect, Color(1, 0.35, 0.05, 0.12 + 0.1 * blink))
		draw_rect(rect, Color(1, 0.5, 0.15, 0.8 * blink), false, 4.0)
		# Chevrons pointing down the lane.
		var y := 260.0 + fmod(_t * 420.0, 120.0)
		while y < 1260.0:
			var c := Vector2(lane_x, y)
			draw_polyline(PackedVector2Array([c + Vector2(-40, -22), c, c + Vector2(40, -22)]), Color(1, 0.6, 0.2, 0.7 * blink), 6.0)
			y += 120.0
	if spoke_mode == 0:
		return
	for i in spoke_count:
		var dir := Vector2.from_angle(spoke_angle + i * TAU / spoke_count)
		var end := spoke_origin + dir * 1000.0
		if spoke_mode == 1:
			var a := 0.3 + 0.5 * absf(sin(_t * 18.0))
			draw_line(spoke_origin, end, Color(1, 0.55, 0.1, a), 3.0)
		else:
			var w := 44.0 * (1.0 + sin(_t * 40.0 + i) * 0.1)
			draw_line(spoke_origin, end, Color(1, 0.35, 0.05, 0.35), w * 1.6)
			draw_line(spoke_origin, end, Color(1, 0.6, 0.2, 0.9), w)
			draw_line(spoke_origin, end, Color(1, 0.95, 0.8, 1.0), w * 0.3)
	draw_circle(spoke_origin, 30.0 + sin(_t * 30.0) * 4.0, Color(1, 0.7, 0.3, 0.9 if spoke_mode == 2 else 0.5))
