extends Node2D
## Flat ice-shard projectile (Cryo Titan): a long cyan crystal with a white edge, pointing up (-Y)
## along the parent Bullet's flight direction.

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(0, -18), Vector2(6, -2), Vector2(3, 14), Vector2(-3, 14), Vector2(-6, -2)])
	var outline := PackedVector2Array([Vector2(0, -20), Vector2(8, -2), Vector2(4, 16), Vector2(-4, 16), Vector2(-8, -2)])
	draw_colored_polygon(outline, Color(0.1, 0.3, 0.55))
	draw_colored_polygon(pts, Color(0.6, 0.9, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(-6, -2), Vector2(-1, 12)]), Color(0.9, 0.98, 1.0))
