extends Node2D
## Translucent block of ice drawn around the mech while it's frozen (Cryo Titan ice attacks).
## The Player toggles `frozen`; dashing breaks free early.

var frozen := false:
	set(value):
		frozen = value
		visible = value
		_t = 0.0
		queue_redraw()
var _t := 0.0


func _ready() -> void:
	visible = false
	z_index = 2


func _process(delta: float) -> void:
	if frozen:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var pop := minf(_t / 0.12, 1.0)  # quick grow-in
	var r := 58.0 * (0.7 + 0.3 * pop)
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(Vector2.from_angle(i * TAU / 6.0 + PI / 6.0) * r * (1.0 if i % 2 == 0 else 0.93))
	draw_colored_polygon(hex, Color(0.6, 0.85, 1.0, 0.42))
	var outline := hex.duplicate()
	outline.append(hex[0])
	draw_polyline(outline, Color(0.9, 0.97, 1.0, 0.95), 3.0, true)
	# Inner facets and a glint.
	for i in 3:
		draw_line(Vector2.ZERO, hex[i * 2], Color(1, 1, 1, 0.25), 2.0)
	draw_line(Vector2(-r * 0.5, -r * 0.35), Vector2(-r * 0.1, -r * 0.7), Color(1, 1, 1, 0.8), 3.0)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-70, r + 24), "DASH TO BREAK", HORIZONTAL_ALIGNMENT_CENTER, 140, 16, 5, Color(0.02, 0.08, 0.2, 0.95))
	draw_string(font, Vector2(-70, r + 24), "DASH TO BREAK", HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(0.9, 0.97, 1.0))
