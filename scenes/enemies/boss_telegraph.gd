extends Node2D
## Draws the boss's danger aura, slam circles and laser (aim line, lock, beam) in world space.

var aura_pos := Vector2.ZERO
var aura_strength := 0.35
var circles: Array[Dictionary] = []
var laser_mode := 0  # 0 off, 1 aiming, 2 locked, 3 firing
var laser_origin := Vector2.ZERO
var laser_dir := Vector2.DOWN
var laser_width := 64.0
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	rotation = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if aura_strength > 0.01:
		var pulse := 1.0 + sin(_t * 5.0) * 0.04
		draw_circle(aura_pos, 165.0 * pulse, Color(1, 0.08, 0.04, 0.13 * aura_strength))
		draw_arc(aura_pos, 165.0 * pulse, 0.0, TAU, 72, Color(1, 0.2, 0.1, 0.55 * aura_strength), 3.0, true)

	for c in circles:
		var pos: Vector2 = c.pos
		var r: float = c.radius
		var blink := 0.6 + 0.4 * absf(sin(_t * 14.0))
		draw_circle(pos, r, Color(1, 0.08, 0.04, 0.14))
		draw_circle(pos, r * c.progress, Color(1, 0.18, 0.06, 0.28))
		draw_arc(pos, r, 0.0, TAU, 56, Color(1, 0.25, 0.15, 0.9 * blink), 3.0, true)
		for i in 4:
			var a := i * TAU / 4.0 + _t * 1.5
			draw_line(pos + Vector2.from_angle(a) * (r - 16.0), pos + Vector2.from_angle(a) * (r + 6.0), Color(1, 0.3, 0.2, 0.9), 3.0)

	if laser_mode == 0:
		return
	var end := laser_origin + laser_dir * 1900.0
	match laser_mode:
		1:
			var a := 0.25 + 0.55 * absf(sin(_t * 18.0))
			draw_line(laser_origin, end, Color(1, 0.15, 0.1, a), 3.0)
			draw_circle(laser_origin, 10.0 + sin(_t * 30.0) * 3.0, Color(1, 0.3, 0.2, 0.9))
		2:
			draw_line(laser_origin, end, Color(1, 0.12, 0.08, 0.35), laser_width)
			draw_line(laser_origin, end, Color(1, 0.35, 0.25, 1.0), 5.0)
			draw_circle(laser_origin, 18.0, Color(1, 0.5, 0.4, 1.0))
		3:
			var w := laser_width * (1.0 + sin(_t * 40.0) * 0.08)
			draw_line(laser_origin, end, Color(1, 0.1, 0.05, 0.35), w * 1.6)
			draw_line(laser_origin, end, Color(1, 0.3, 0.2, 0.85), w)
			draw_line(laser_origin, end, Color(1, 0.95, 0.9, 1.0), w * 0.35)
			draw_circle(laser_origin, w * 0.7, Color(1, 0.6, 0.5, 0.9))
