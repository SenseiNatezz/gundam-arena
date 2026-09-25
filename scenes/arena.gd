extends Node2D
## Procedurally painted arena floors: the hangar ("AREA A-1", level 1) and the reactor deck
## ("SECTOR B-7", level 2). Also builds the colliders for walls and obstacles.

const W := 720.0
const H := 1280.0
const WALL := 46.0
const GATE := 150.0
const PLATE := 104.0
const CRATES := [
	Rect2(60, 740, 74, 74), Rect2(64, 822, 56, 56), Rect2(128, 816, 48, 48),
	Rect2(596, 600, 72, 72), Rect2(612, 680, 50, 50), Rect2(64, 430, 58, 58),
]
const BARRELS := [Vector2(636, 940), Vector2(600, 972), Vector2(92, 510), Vector2(640, 280)]
## Level 2 (reactor deck): round reactor pylons instead of crates.
const PYLONS := [Vector2(150, 430), Vector2(575, 700), Vector2(120, 880), Vector2(600, 330)]
const PYLON_RADIUS := 36.0

var _font: Font
var _rng := RandomNumberGenerator.new()
var _stage := 1
var _crates: Array = []
var _barrels: Array = []
var _pylons: Array = []
var _t := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var theme := load("res://ui_theme.tres") as Theme
	if theme and theme.default_font:
		_font = theme.default_font


## Called by Main once the level is known: picks the layout, builds colliders and paints the floor.
func setup(stage: int) -> void:
	_stage = stage
	_crates = CRATES if stage == 1 else []
	_barrels = BARRELS if stage == 1 else []
	_pylons = PYLONS if stage == 2 else []
	_build_colliders()
	queue_redraw()


func _process(delta: float) -> void:
	# The reactor deck's coolant glow pulses; the hangar is static and never redraws.
	if _stage == 2:
		_t += delta
		if int(_t * 8.0) != int((_t - delta) * 8.0):
			queue_redraw()


func _build_colliders() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var rects: Array[Rect2] = [
		Rect2(0, 0, WALL, H), Rect2(W - WALL, 0, WALL, H), Rect2(0, 0, W, GATE + 30.0), Rect2(0, H - 30.0, W, 30.0),
	]
	for c in _crates:
		rects.append(c)
	for r in rects:
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = r.size
		shape.shape = rect_shape
		shape.position = r.get_center()
		body.add_child(shape)
	var circles: Array = []
	for b in _barrels:
		circles.append([b, 20.0])
	for p in _pylons:
		circles.append([p, PYLON_RADIUS])
	for c in circles:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = c[1]
		shape.shape = circle
		shape.position = c[0]
		body.add_child(shape)


func _draw() -> void:
	if _stage == 2:
		_draw_reactor_deck()
		return
	_rng.seed = 1337
	draw_rect(Rect2(0, 0, W, H), Color(0.075, 0.085, 0.105))
	_draw_plates()
	_draw_markings()
	_draw_grate(Rect2(WALL + 34, 560, W - 2 * WALL - 68, 58))
	_draw_grate(Rect2(WALL + 90, 900, W - 2 * WALL - 180, 40))
	_draw_hazard(Rect2(WALL, GATE + 8, W - 2 * WALL, 14))
	_draw_hazard(Rect2(WALL, H - 44, W - 2 * WALL, 14))
	_draw_stains()
	_draw_gate()
	_draw_wall(Rect2(0, GATE, WALL, H - GATE), 1.0)
	_draw_wall(Rect2(W - WALL, GATE, WALL, H - GATE), -1.0)
	_draw_sign(Vector2(23, 520), "AREA A-1", Color(0.85, 0.87, 0.9))
	_draw_sign(Vector2(W - 23, 860), "FIGHT ZONE", Color(0.95, 0.75, 0.2))
	for b in _barrels:
		_draw_barrel(b)
	for c in _crates:
		_draw_crate(c)


func _draw_plates() -> void:
	var floor_rect := Rect2(WALL, GATE, W - 2 * WALL, H - GATE)
	var y := GATE
	while y < H:
		var x := WALL
		while x < W - WALL:
			var r := Rect2(x, y, PLATE, PLATE).intersection(floor_rect)
			var v := _rng.randf_range(-0.014, 0.014)
			var base := Color(0.13 + v, 0.145 + v, 0.175 + v)
			draw_rect(r.grow(-1.5), base)
			draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), Color(1, 1, 1, 0.055), 2.0)
			draw_line(r.position + Vector2(2, 2), Vector2(r.position.x + 2, r.end.y - 2), Color(1, 1, 1, 0.04), 2.0)
			draw_line(Vector2(r.position.x + 2, r.end.y - 2), r.end - Vector2(2, 2), Color(0, 0, 0, 0.4), 2.0)
			draw_line(Vector2(r.end.x - 2, r.position.y + 2), r.end - Vector2(2, 2), Color(0, 0, 0, 0.3), 2.0)
			for corner in [Vector2(9, 9), Vector2(r.size.x - 9, 9), Vector2(9, r.size.y - 9), r.size - Vector2(9, 9)]:
				draw_circle(r.position + corner, 2.6, Color(0.05, 0.055, 0.07))
				draw_circle(r.position + corner - Vector2(0.7, 0.7), 1.4, Color(0.32, 0.35, 0.4))
			if _rng.randf() < 0.22:
				_draw_tread(r.grow(-16))
			elif _rng.randf() < 0.2:
				var p := r.position + Vector2(_rng.randf_range(15, 60), _rng.randf_range(15, 60))
				draw_line(p, p + Vector2(_rng.randf_range(10, 40), _rng.randf_range(-8, 8)), Color(1, 1, 1, 0.05), 1.0)
			x += PLATE
		y += PLATE


func _draw_tread(r: Rect2) -> void:
	var step := 14.0
	var y := r.position.y
	var row := 0
	while y < r.end.y - 4:
		var x := r.position.x + (7.0 if row % 2 else 0.0)
		while x < r.end.x - 8:
			var a := Vector2(x, y)
			var b := a + (Vector2(8, 4) if row % 2 else Vector2(8, -4)) + Vector2(0, 4)
			draw_line(a + Vector2(0, 4), b, Color(1, 1, 1, 0.045), 2.0)
			x += step
		y += step * 0.7
		row += 1


func _draw_markings() -> void:
	var yellow := Color(0.95, 0.72, 0.15, 0.16)
	draw_arc(Vector2(360, 760), 160, 0, TAU, 72, yellow, 5.0, true)
	draw_arc(Vector2(360, 760), 120, 0, TAU, 72, Color(0.95, 0.72, 0.15, 0.08), 2.0, true)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		draw_line(Vector2(360, 760) + Vector2.from_angle(a) * 130, Vector2(360, 760) + Vector2.from_angle(a) * 190, yellow, 5.0)
	draw_string(_font, Vector2(360 - 150, 800), "A-1", HORIZONTAL_ALIGNMENT_CENTER, 300, 110, Color(0.95, 0.75, 0.2, 0.07))
	# lane lines
	var y := 230.0
	while y < H - 60:
		draw_line(Vector2(WALL + 26, y), Vector2(WALL + 26, y + 34), Color(0.95, 0.72, 0.15, 0.22), 4.0)
		draw_line(Vector2(W - WALL - 26, y), Vector2(W - WALL - 26, y + 34), Color(0.95, 0.72, 0.15, 0.22), 4.0)
		y += 64.0


func _draw_grate(r: Rect2) -> void:
	draw_rect(r.grow(4), Color(0.05, 0.055, 0.07))
	draw_rect(r, Color(0.02, 0.022, 0.03))
	var x := r.position.x + 6
	while x < r.end.x - 4:
		draw_rect(Rect2(x, r.position.y + 3, 5, r.size.y - 6), Color(0.2, 0.22, 0.26))
		draw_line(Vector2(x, r.position.y + 3), Vector2(x, r.end.y - 3), Color(1, 1, 1, 0.08), 1.0)
		x += 12
	draw_rect(r.grow(4), Color(0.3, 0.33, 0.38, 0.5), false, 2.0)


func _draw_hazard(r: Rect2) -> void:
	draw_rect(r, Color(0.05, 0.05, 0.06))
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var pts := PackedVector2Array([
			Vector2(clampf(x, r.position.x, r.end.x), r.end.y),
			Vector2(clampf(x + r.size.y, r.position.x, r.end.x), r.position.y),
			Vector2(clampf(x + r.size.y + 14, r.position.x, r.end.x), r.position.y),
			Vector2(clampf(x + 14, r.position.x, r.end.x), r.end.y),
		])
		if pts[0].distance_to(pts[3]) > 0.5 or pts[1].distance_to(pts[2]) > 0.5:
			draw_colored_polygon(pts, Color(0.92, 0.68, 0.1, 0.85))
		x += 28


func _draw_stains() -> void:
	for i in 7:
		var p := Vector2(_rng.randf_range(120, 600), _rng.randf_range(260, 1150))
		var r := _rng.randf_range(20, 55)
		for k in 4:
			draw_circle(p + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12)), r * (1.0 - k * 0.2), Color(0, 0, 0, 0.07))


func _draw_gate() -> void:
	draw_rect(Rect2(0, 0, W, GATE), Color(0.06, 0.07, 0.09))
	# shutter slats
	var y := 12.0
	while y < GATE - 10:
		draw_rect(Rect2(WALL + 20, y, W - 2 * WALL - 40, 9), Color(0.11, 0.12, 0.15))
		draw_line(Vector2(WALL + 20, y), Vector2(W - WALL - 20, y), Color(1, 1, 1, 0.06), 1.0)
		y += 14.0
	draw_rect(Rect2(0, GATE - 12, W, 12), Color(0.16, 0.17, 0.2))
	draw_line(Vector2(0, GATE - 12), Vector2(W, GATE - 12), Color(1, 1, 1, 0.12), 2.0)
	for x in [WALL + 30, W - WALL - 30]:
		draw_circle(Vector2(x, GATE - 6), 9, Color(1, 0.15, 0.1, 0.25))
		draw_circle(Vector2(x, GATE - 6), 4, Color(1, 0.35, 0.3))


func _draw_wall(r: Rect2, inward: float) -> void:
	draw_rect(r, Color(0.09, 0.1, 0.125))
	var edge := r.end.x if inward > 0 else r.position.x
	draw_rect(Rect2(edge - (8 if inward > 0 else 0), r.position.y, 8, r.size.y), Color(0.2, 0.22, 0.26))
	draw_line(Vector2(edge, r.position.y), Vector2(edge, r.end.y), Color(1, 1, 1, 0.14), 2.0)
	var pipe_x := r.position.x + 14
	draw_line(Vector2(pipe_x, r.position.y), Vector2(pipe_x, r.end.y), Color(0.22, 0.24, 0.28), 6.0)
	draw_line(Vector2(pipe_x - 2, r.position.y), Vector2(pipe_x - 2, r.end.y), Color(1, 1, 1, 0.08), 1.0)
	var y := r.position.y + 60
	while y < r.end.y - 20:
		draw_rect(Rect2(r.position.x + 4, y, r.size.x - 8, 3), Color(0, 0, 0, 0.5))
		var light := Vector2(r.get_center().x + 6 * inward, y + 40)
		draw_circle(light, 10, Color(0.3, 0.8, 1, 0.18))
		draw_circle(light, 4, Color(0.55, 0.9, 1, 0.9))
		y += 180


func _draw_sign(center: Vector2, text: String, color: Color) -> void:
	var size := Vector2(34, 190)
	draw_rect(Rect2(center - size / 2, size), Color(0.13, 0.14, 0.17))
	draw_rect(Rect2(center - size / 2, size), Color(0.35, 0.37, 0.42), false, 2.0)
	draw_set_transform(center, -PI / 2)
	draw_string(_font, Vector2(-90, 8), text, HORIZONTAL_ALIGNMENT_CENTER, 180, 19, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_crate(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(7, 9), r.size), Color(0, 0, 0, 0.4))
	draw_rect(r, Color(0.2, 0.13, 0.05))
	var top := r.grow(-4)
	draw_rect(top, Color(0.62, 0.42, 0.12))
	draw_rect(top.grow(-6), Color(0.52, 0.34, 0.09))
	draw_line(top.position + Vector2(6, 6), top.end - Vector2(6, 6), Color(0.68, 0.48, 0.16), 5.0)
	draw_line(Vector2(top.end.x - 6, top.position.y + 6), Vector2(top.position.x + 6, top.end.y - 6), Color(0.68, 0.48, 0.16), 5.0)
	draw_line(top.position, Vector2(top.end.x, top.position.y), Color(1, 0.9, 0.6, 0.35), 2.0)
	for corner in [top.position, Vector2(top.end.x - 12, top.position.y), Vector2(top.position.x, top.end.y - 12), top.end - Vector2(12, 12)]:
		draw_rect(Rect2(corner, Vector2(12, 12)), Color(0.12, 0.12, 0.13))
		draw_line(corner + Vector2(0, 12), corner + Vector2(12, 0), Color(0.95, 0.7, 0.1), 3.0)


func _draw_barrel(p: Vector2) -> void:
	draw_circle(p + Vector2(6, 8), 22, Color(0, 0, 0, 0.4))
	draw_circle(p, 21, Color(0.35, 0.07, 0.05))
	draw_circle(p, 17, Color(0.62, 0.12, 0.08))
	draw_arc(p, 12, 0, TAU, 32, Color(0.3, 0.05, 0.04), 2.0)
	draw_circle(p + Vector2(-6, -6), 4, Color(0.2, 0.2, 0.22))
	draw_arc(p, 19, PI, PI * 1.5, 16, Color(1, 0.8, 0.7, 0.35), 2.0)


# --- level 2: reactor deck -----------------------------------------------------------------

func _draw_reactor_deck() -> void:
	_rng.seed = 7331
	var pulse := 0.75 + 0.25 * sin(_t * 3.0)
	draw_rect(Rect2(0, 0, W, H), Color(0.07, 0.055, 0.05))
	# Rust-toned deck plates.
	var floor_rect := Rect2(WALL, GATE, W - 2 * WALL, H - GATE)
	var y := GATE
	while y < H:
		var x := WALL
		while x < W - WALL:
			var r := Rect2(x, y, PLATE, PLATE).intersection(floor_rect)
			var v := _rng.randf_range(-0.012, 0.012)
			draw_rect(r.grow(-1.5), Color(0.15 + v, 0.12 + v, 0.105 + v))
			draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), Color(1, 0.9, 0.8, 0.05), 2.0)
			draw_line(Vector2(r.position.x + 2, r.end.y - 2), r.end - Vector2(2, 2), Color(0, 0, 0, 0.45), 2.0)
			for corner in [Vector2(9, 9), Vector2(r.size.x - 9, 9), Vector2(9, r.size.y - 9), r.size - Vector2(9, 9)]:
				draw_circle(r.position + corner, 2.6, Color(0.05, 0.04, 0.035))
			if _rng.randf() < 0.18:
				_draw_vent(r.grow(-22))
			x += PLATE
		y += PLATE
	# Reactor emblem in the middle of the deck.
	var c := Vector2(360, 760)
	draw_arc(c, 150, 0, TAU, 72, Color(1, 0.5, 0.1, 0.14), 6.0, true)
	for i in 3:
		var a := i * TAU / 3.0 - PI / 2
		var pts := PackedVector2Array([c + Vector2.from_angle(a - 0.45) * 40, c + Vector2.from_angle(a - 0.3) * 125,
			c + Vector2.from_angle(a + 0.3) * 125, c + Vector2.from_angle(a + 0.45) * 40])
		draw_colored_polygon(pts, Color(1, 0.55, 0.1, 0.09))
	draw_circle(c, 26, Color(1, 0.55, 0.1, 0.1))
	draw_string(_font, Vector2(360 - 150, 800), "B-7", HORIZONTAL_ALIGNMENT_CENTER, 300, 110, Color(1, 0.6, 0.2, 0.06))
	# Glowing coolant channels crossing the deck (replace the hangar's grates).
	for ch in [Rect2(WALL + 20, 575, W - 2 * WALL - 40, 34), Rect2(WALL + 110, 985, W - 2 * WALL - 220, 26)]:
		_draw_coolant(ch, pulse)
	_draw_hazard(Rect2(WALL, GATE + 8, W - 2 * WALL, 14))
	_draw_hazard(Rect2(WALL, H - 44, W - 2 * WALL, 14))
	_draw_gate()
	_draw_reactor_wall(Rect2(0, GATE, WALL, H - GATE), 1.0, pulse)
	_draw_reactor_wall(Rect2(W - WALL, GATE, WALL, H - GATE), -1.0, pulse)
	_draw_sign(Vector2(23, 520), "SECTOR B-7", Color(1, 0.65, 0.25))
	_draw_sign(Vector2(W - 23, 860), "REACTOR", Color(0.35, 0.9, 1.0))
	for p in _pylons:
		_draw_pylon(p, pulse)


func _draw_coolant(r: Rect2, pulse: float) -> void:
	draw_rect(r.grow(5), Color(0.05, 0.04, 0.035))
	draw_rect(r.grow(5), Color(0.35, 0.3, 0.27, 0.5), false, 2.0)
	draw_rect(r, Color(1.0, 0.35, 0.05, 0.75 * pulse))
	draw_rect(Rect2(r.position.x, r.get_center().y - r.size.y * 0.18, r.size.x, r.size.y * 0.36), Color(1, 0.8, 0.4, 0.8 * pulse))
	# Flow streaks sliding along the channel.
	var x := r.position.x + fmod(_t * 90.0, 60.0)
	while x < r.end.x - 20:
		draw_line(Vector2(x, r.get_center().y), Vector2(x + 20, r.get_center().y), Color(1, 1, 0.8, 0.55), 3.0)
		x += 60.0
	# Glow spill onto the floor.
	draw_rect(r.grow(18), Color(1, 0.4, 0.1, 0.06 * pulse))


func _draw_vent(r: Rect2) -> void:
	draw_rect(r, Color(0.04, 0.035, 0.03))
	var y := r.position.y + 5
	while y < r.end.y - 3:
		draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), Color(0.3, 0.25, 0.22, 0.8), 2.0)
		y += 7
	draw_rect(r, Color(1, 0.4, 0.1, 0.05))


func _draw_reactor_wall(r: Rect2, inward: float, pulse: float) -> void:
	draw_rect(r, Color(0.09, 0.075, 0.07))
	var edge := r.end.x if inward > 0 else r.position.x
	draw_rect(Rect2(edge - (8 if inward > 0 else 0), r.position.y, 8, r.size.y), Color(0.22, 0.18, 0.16))
	draw_line(Vector2(edge, r.position.y), Vector2(edge, r.end.y), Color(1, 0.9, 0.8, 0.12), 2.0)
	# Teal conduit with energy nodes.
	var cx := r.position.x + 16
	draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), Color(0.05, 0.25, 0.28), 9.0)
	draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), Color(0.3, 0.9, 1.0, 0.35 * pulse), 3.0)
	var y := r.position.y + 90
	while y < r.end.y - 20:
		draw_circle(Vector2(cx, y), 9, Color(0.3, 0.9, 1.0, 0.2 * pulse))
		draw_circle(Vector2(cx, y), 4, Color(0.6, 1.0, 1.0, 0.9))
		y += 160


func _draw_pylon(p: Vector2, pulse: float) -> void:
	draw_circle(p + Vector2(7, 10), PYLON_RADIUS + 2, Color(0, 0, 0, 0.45))
	draw_circle(p, PYLON_RADIUS, Color(0.2, 0.17, 0.15))
	draw_arc(p, PYLON_RADIUS - 3, 0, TAU, 40, Color(0.45, 0.4, 0.36), 4.0, true)
	for i in 6:
		var a := i * TAU / 6.0
		draw_line(p + Vector2.from_angle(a) * 18, p + Vector2.from_angle(a) * (PYLON_RADIUS - 6), Color(0.08, 0.07, 0.06), 3.0)
	draw_circle(p, 18, Color(0.05, 0.25, 0.28))
	draw_circle(p, 13, Color(0.3, 0.9, 1.0, 0.6 + 0.4 * pulse))
	draw_circle(p - Vector2(4, 4), 5, Color(0.85, 1.0, 1.0))
