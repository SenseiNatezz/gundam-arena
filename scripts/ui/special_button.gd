extends Control
## Hyper Mega Cannon button (above the dash button). Hidden until the upgrade is taken;
## shows a charge sweep while recharging and pulses when ready.

var _t := 0.0
var _pressed_flash := 0.0
var _was_ready := false


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch and event.pressed and get_global_rect().grow(12).has_point(event.position):
		GameState.special_requested = true
		_pressed_flash = 1.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var player := GameState.player as Player
	visible = player != null and player.special_unlocked()
	if not visible:
		return
	var is_ready := player.special_ready()
	if is_ready and not _was_ready:
		_pressed_flash = 0.8  # little pop when it comes off cooldown
	_was_ready = is_ready
	_pressed_flash = move_toward(_pressed_flash, 0.0, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	var player := GameState.player as Player
	if player == null:
		return
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 4
	var total := player.special_cooldown_total()
	var frac := 1.0 - player.special_cooldown_left / maxf(total, 0.01)
	var is_ready := frac >= 1.0 and not player.casting
	var pink := Color(1, 0.4, 0.85)
	if is_ready:
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_circle(c, r + 8 + pulse * 5, Color(pink, 0.18 + 0.12 * pulse))
	draw_circle(c, r, Color(0.35, 0.05, 0.3, 0.9) if is_ready else Color(0.12, 0.05, 0.14, 0.8))
	if not is_ready:
		draw_arc(c, r - 5, -PI / 2, -PI / 2 + TAU * frac, 48, Color(pink, 0.9), 6.0, true)
	draw_arc(c, r, 0, TAU, 64, Color(pink.lightened(0.3), 0.95 if is_ready else 0.45), 3.0, true)
	if _pressed_flash > 0:
		draw_circle(c, r, Color(1, 1, 1, 0.35 * _pressed_flash))
	# Icon: cannon barrel firing a beam.
	var a := 1.0 if is_ready else 0.45
	draw_line(c + Vector2(-20, 14), c + Vector2(4, -10), Color(0.85, 0.9, 1, a), 12.0)
	draw_line(c + Vector2(0, -6), c + Vector2(22, -28), Color(0.5, 0.9, 1, 0.6 * a), 12.0)
	draw_line(c + Vector2(0, -6), c + Vector2(22, -28), Color(1, 1, 1, a), 4.0)
	draw_circle(c + Vector2(2, -8), 7.0, Color(1, 0.6, 0.95, a))
	if not is_ready:
		var secs := ceili(player.special_cooldown_left)
		draw_string(get_theme_default_font(), c + Vector2(-20, r - 10), str(secs), HORIZONTAL_ALIGNMENT_CENTER, 40, 18, Color(1, 1, 1, 0.8))
