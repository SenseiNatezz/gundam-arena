extends Control
## Procedural icon for an Upgrade card (so upgrades need no image files).

var kind := "triple"
var color := Color.WHITE


func _draw() -> void:
	var c := size / 2
	var s := minf(size.x, size.y) / 100.0
	draw_circle(c, 46 * s, Color(color, 0.14))
	draw_arc(c, 46 * s, 0, TAU, 48, Color(color, 0.6), 2.5 * s, true)
	match kind:
		"triple":
			for a in [-0.35, 0.0, 0.35]:
				_bolt(c + Vector2(0, 26) * s, Vector2.UP.rotated(a), 44 * s, s)
		"thrusters":
			for x in [-14.0, 14.0]:
				var p := c + Vector2(x, 0) * s
				draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -24) * s, p + Vector2(9, -24) * s, p + Vector2(5, 4) * s, p + Vector2(-5, 4) * s]), color.darkened(0.2))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 6) * s, p + Vector2(6, 6) * s, p + Vector2(0, 30) * s]), Color(0.6, 0.9, 1))
		"speed":
			for dy in [8.0, -12.0]:
				var p := c + Vector2(0, dy) * s
				draw_polyline(PackedVector2Array([p + Vector2(-20, 12) * s, p + Vector2(0, -8) * s, p + Vector2(20, 12) * s]), color, 9 * s, true)
		"pierce":
			draw_circle(c + Vector2(0, -2) * s, 15 * s, Color(color, 0.35))
			draw_arc(c + Vector2(0, -2) * s, 15 * s, 0, TAU, 32, color, 3 * s, true)
			_bolt(c + Vector2(0, 36) * s, Vector2.UP, 70 * s, s)
		"shield":
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(i * TAU / 6 + PI / 6) * 30 * s)
			draw_colored_polygon(hex, Color(color, 0.3))
			hex.append(hex[0])
			draw_polyline(hex, color, 4 * s, true)
		"homing":
			draw_arc(c + Vector2(14, 6) * s, 24 * s, PI * 0.9, PI * 1.9, 24, color, 5 * s, true)
			draw_circle(c + Vector2(24, -16) * s, 9 * s, Color(1, 0.3, 0.2))
			draw_arc(c + Vector2(24, -16) * s, 14 * s, 0, TAU, 24, Color(1, 0.4, 0.3), 2 * s, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 12) * s, c + Vector2(-4, 22) * s, c + Vector2(-20, 26) * s]), color)
		"power":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(6, -32) * s, c + Vector2(-16, 4) * s, c + Vector2(-2, 4) * s,
				c + Vector2(-8, 32) * s, c + Vector2(16, -6) * s, c + Vector2(2, -6) * s]), color)
		"cannon":
			var o := c + Vector2(-26, 22) * s
			var d := Vector2(1, -1).normalized()
			draw_line(o + d * 16 * s, o + d * 80 * s, Color(1, 0.3, 0.85, 0.45), 26 * s)
			draw_line(o + d * 16 * s, o + d * 80 * s, Color(0.4, 0.9, 1, 0.9), 14 * s)
			draw_line(o + d * 16 * s, o + d * 80 * s, Color(1, 1, 1), 5 * s)
			draw_line(o - d * 4 * s, o + d * 18 * s, Color(0.75, 0.8, 0.9), 16 * s)
			draw_circle(o + d * 18 * s, 10 * s, Color(1, 0.7, 0.95))
		"heat":
			# Shield with a flame on it.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -24) * s, c + Vector2(24, -24) * s, c + Vector2(20, 10) * s, c + Vector2(0, 30) * s, c + Vector2(-20, 10) * s]), Color(color, 0.35))
			draw_polyline(PackedVector2Array([c + Vector2(-24, -24) * s, c + Vector2(24, -24) * s, c + Vector2(20, 10) * s, c + Vector2(0, 30) * s, c + Vector2(-20, 10) * s, c + Vector2(-24, -24) * s]), color, 3.5 * s, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -18) * s, c + Vector2(11, 2) * s, c + Vector2(6, 16) * s, c + Vector2(-6, 16) * s, c + Vector2(-11, 2) * s]), Color(1, 0.45, 0.1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4) * s, c + Vector2(5, 8) * s, c + Vector2(0, 14) * s, c + Vector2(-5, 8) * s]), Color(1, 0.9, 0.5))
		"move":
			# Forward arrow with speed streaks.
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -30) * s, c + Vector2(20, -6) * s, c + Vector2(8, -6) * s, c + Vector2(8, 24) * s, c + Vector2(-8, 24) * s, c + Vector2(-8, -6) * s, c + Vector2(-20, -6) * s]), color)
			for x in [-26.0, 26.0]:
				draw_line(c + Vector2(x, 0) * s, c + Vector2(x, 24) * s, Color(color, 0.6), 4 * s)
		"armor":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -24) * s, c + Vector2(24, -24) * s, c + Vector2(20, 10) * s, c + Vector2(0, 30) * s, c + Vector2(-20, 10) * s]), Color(color, 0.35))
			draw_rect(Rect2(c + Vector2(-4, -16) * s, Vector2(8, 30) * s), color)
			draw_rect(Rect2(c + Vector2(-14, -5) * s, Vector2(28, 8) * s), color)


func _bolt(from: Vector2, dir: Vector2, length: float, s: float) -> void:
	var to := from + dir * length
	draw_line(from, to, Color(color, 0.45), 10 * s)
	draw_line(from, to, Color(0.9, 0.97, 1), 4 * s)
	draw_colored_polygon(PackedVector2Array([to + dir * 8 * s, to + dir.orthogonal() * 6 * s, to - dir.orthogonal() * 6 * s]), Color(0.9, 0.97, 1))
