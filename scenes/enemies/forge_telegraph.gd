extends Node2D
## World-space effects for the Magma Forge Mech: the lava pool it rises from, the red flame-slam
## warning circle, and the expanding ring of fire on impact.

var rise_pos := Vector2.ZERO
var rise_strength := 1.0
var warn_active := false
var warn_pos := Vector2.ZERO
var warn_radius := 115.0
var warn_progress := 0.0
var _rings: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = -1  # under the mech, above the floor


func flame_ring(pos: Vector2, radius: float) -> void:
	_rings.append({"pos": pos, "radius": radius, "t": 0.0})


func _process(delta: float) -> void:
	_t += delta
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].t += delta
		if _rings[i].t > 0.55:
			_rings.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if rise_strength > 0.0:
		var r := 150.0 * (0.6 + 0.4 * sin(_t * 3.0))
		draw_circle(rise_pos, r * 1.3, Color(1, 0.3, 0.05, 0.18 * rise_strength))
		draw_circle(rise_pos, r, Color(1, 0.45, 0.08, 0.45 * rise_strength))
		draw_circle(rise_pos, r * 0.6, Color(1, 0.8, 0.35, 0.5 * rise_strength))
		for i in 10:
			var a := i * TAU / 10.0 + _t * 0.8
			draw_line(rise_pos + Vector2.from_angle(a) * r * 0.9, rise_pos + Vector2.from_angle(a) * r * 1.5, Color(1, 0.4, 0.05, 0.6 * rise_strength), 5.0)
	if warn_active:
		var blink := 0.55 + 0.45 * absf(sin(_t * (10.0 + warn_progress * 14.0)))
		draw_circle(warn_pos, warn_radius, Color(1, 0.05, 0.02, 0.14))
		draw_circle(warn_pos, warn_radius * warn_progress, Color(1, 0.15, 0.05, 0.3))
		draw_arc(warn_pos, warn_radius, 0.0, TAU, 56, Color(1, 0.15, 0.08, 0.95 * blink), 4.0, true)
		draw_arc(warn_pos, warn_radius * 0.55, 0.0, TAU, 40, Color(1, 0.3, 0.1, 0.5 * blink), 2.0, true)
		for i in 4:
			var a := i * TAU / 4.0 + _t * 2.0
			draw_line(warn_pos + Vector2.from_angle(a) * (warn_radius - 18.0), warn_pos + Vector2.from_angle(a) * (warn_radius + 8.0), Color(1, 0.35, 0.15, 0.9), 4.0)
	for ring in _rings:
		var k: float = ring.t / 0.55
		var rr: float = ring.radius * (0.6 + k * 0.7)
		draw_arc(ring.pos, rr, 0.0, TAU, 64, Color(1, 0.4, 0.05, 0.9 * (1.0 - k)), 26.0 * (1.0 - k) + 4.0, true)
		draw_arc(ring.pos, rr, 0.0, TAU, 64, Color(1, 0.85, 0.4, 0.9 * (1.0 - k)), 8.0 * (1.0 - k) + 2.0, true)
		draw_circle(ring.pos, ring.radius * 0.9, Color(1, 0.3, 0.05, 0.35 * (1.0 - k)))
