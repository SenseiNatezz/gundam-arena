extends Control
## Round special-ability button with a label and a cooldown box that counts down with one decimal
## ("12.4"). Glows when ready; tapping it triggers the ability. Used for the Beam Rifle and the
## Beam Saber (set `ability` in the scene).

const RADIUS := 52.0

## &"beam" (Beam Rifle) or &"saber" (Beam Saber).
@export var ability := &"beam"
@export var label_text := "BEAM RIFLE"
@export var accent := Color(0.35, 0.75, 1.0)

var _t := 0.0
var _pressed_flash := 0.0
var _was_ready := false


func _input(event: InputEvent) -> void:
	if GameState.debug.no_input:
		return  # capture runs ignore real input
	if get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed \
			and event.position.distance_to(global_position + _center()) < RADIUS + 14.0:
		if ability == &"saber":
			GameState.saber_requested = true
		else:
			GameState.special_requested = true
		_pressed_flash = 1.0
		get_viewport().set_input_as_handled()


func _center() -> Vector2:
	return Vector2(size.x / 2, RADIUS + 4)


func _cooldown(player: Player) -> Vector2:  # (time left, total)
	if ability == &"saber":
		return Vector2(player.saber_cooldown_left, player.SABER_COOLDOWN)
	return Vector2(player.beam_cooldown_left, player.BEAM_COOLDOWN)


func _is_ready(player: Player) -> bool:
	return player.saber_ready() if ability == &"saber" else player.beam_ready()


func _process(delta: float) -> void:
	_t += delta
	var player := GameState.player as Player
	var is_ready := player != null and _is_ready(player)
	if is_ready and not _was_ready:
		_pressed_flash = 0.7  # pop when it comes off cooldown
	_was_ready = is_ready
	_pressed_flash = move_toward(_pressed_flash, 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var player := GameState.player as Player
	if player == null:
		return
	var c := _center()
	var r := RADIUS
	var cd := _cooldown(player)
	var frac := 1.0 - cd.x / cd.y
	var is_ready := _is_ready(player)
	if is_ready:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_circle(c, r + 8 + pulse * 5, Color(accent, 0.18 + 0.14 * pulse))
	draw_circle(c, r, Color(0.04, 0.1, 0.22, 0.92))
	if not is_ready:
		draw_arc(c, r - 4, -PI / 2, -PI / 2 + TAU * frac, 48, Color(accent, 0.9), 6.0, true)
	draw_arc(c, r, 0, TAU, 64, Color(accent.lightened(0.3), 0.95 if is_ready else 0.45), 3.0, true)
	if _pressed_flash > 0:
		draw_circle(c, r, Color(1, 1, 1, 0.35 * _pressed_flash))
	if ability == &"saber":
		_draw_saber_icon(c, 1.0 if is_ready else 0.45)
	else:
		_draw_beam_icon(c, 1.0 if is_ready else 0.45)
	# Label and cooldown box.
	var font := get_theme_default_font()
	var label_y := c.y + r + 22
	draw_string_outline(font, Vector2(0, label_y), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(0, label_y), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(0.9, 0.96, 1.0))
	var box := Rect2(size.x / 2 - 38, label_y + 6, 76, 28)
	draw_rect(box, Color(0.03, 0.07, 0.14, 0.9))
	draw_rect(box, Color(accent, 0.8), false, 2.0)
	var text := "READY" if is_ready else "%.1f" % cd.x
	draw_string(font, Vector2(box.position.x, box.position.y + 21), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 18,
		Color(0.6, 1.0, 0.8) if is_ready else Color(1, 1, 1))


## Rifle barrel firing a lightning-wrapped beam up and to the right.
func _draw_beam_icon(c: Vector2, a: float) -> void:
	var d := Vector2(1, -0.75).normalized()
	var perp := d.orthogonal()
	var gun := c - d * 18.0
	draw_line(gun - d * 20.0, gun + d * 6.0, Color(0.75, 0.8, 0.9, a), 11.0)
	draw_line(gun - d * 20.0 + perp * 5.0, gun + perp * 5.0, Color(0.35, 0.4, 0.5, a), 4.0)
	var tip := gun + d * 8.0
	var end := c + d * 40.0
	draw_line(tip, end, Color(0.3, 0.7, 1.0, 0.55 * a), 14.0)
	draw_line(tip, end, Color(0.9, 0.98, 1.0, a), 4.0)
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(tip + d * (i * 8.0) + perp * s * (6.0 if i % 2 == 0 else 1.0))
		draw_polyline(pts, Color(0.6, 0.9, 1.0, 0.9 * a), 1.5)
	draw_circle(tip, 6.0, Color(1, 1, 1, a))
	draw_circle(end, 5.0, Color(0.7, 0.9, 1.0, 0.8 * a))


## Energy blade with a crescent slash arc behind it.
func _draw_saber_icon(c: Vector2, a: float) -> void:
	draw_arc(c, 30.0, PI * 0.75, PI * 2.1, 32, Color(accent, 0.45 * a), 10.0, true)
	draw_arc(c, 30.0, PI * 1.3, PI * 2.1, 24, Color(0.9, 0.98, 1.0, 0.9 * a), 3.5, true)
	var d := Vector2(1, -1).normalized()
	var hilt := c - d * 16.0
	draw_line(hilt - d * 8.0, hilt, Color(0.6, 0.62, 0.7, a), 7.0)
	draw_line(hilt + d.orthogonal() * 8.0, hilt - d.orthogonal() * 8.0, Color(0.6, 0.62, 0.7, a), 4.0)
	draw_line(hilt, c + d * 30.0, Color(accent, 0.6 * a), 11.0)
	draw_line(hilt, c + d * 30.0, Color(0.92, 0.99, 1.0, a), 4.0)
