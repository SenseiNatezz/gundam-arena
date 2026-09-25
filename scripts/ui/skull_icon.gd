extends Control
## Small skull glyph for the enemy counter.

func _draw() -> void:
	var c := size / 2 + Vector2(0, -3)
	var col := Color(0.92, 0.94, 0.98)
	draw_circle(c, 15, col)
	draw_rect(Rect2(c + Vector2(-9, 8), Vector2(18, 11)), col)
	draw_circle(c + Vector2(-6, 0), 4.5, Color(0.05, 0.07, 0.12))
	draw_circle(c + Vector2(6, 0), 4.5, Color(0.05, 0.07, 0.12))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 5), c + Vector2(-3, 10), c + Vector2(3, 10)]), Color(0.05, 0.07, 0.12))
	for x in [-4.0, 0.0, 4.0]:
		draw_line(c + Vector2(x, 14), c + Vector2(x, 19), Color(0.05, 0.07, 0.12), 1.5)
