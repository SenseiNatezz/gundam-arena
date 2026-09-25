extends Control
## Round "»" dash button (bottom-right) with a cooldown sweep. Tapping it requests a dash.

var _pressed_flash := 0.0


# Raw touch events (not GUI mouse emulation) so a second finger works while the stick is held.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not get_tree().paused:
		if get_global_rect().grow(16).has_point(event.position):
			GameState.dash_requested = true
			_pressed_flash = 1.0
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_pressed_flash = move_toward(_pressed_flash, 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 4
	var ready_frac := 1.0
	var player := GameState.player as Player
	if player:
		ready_frac = 1.0 - player.dash_cooldown_left / maxf(GameState.stats.dash_cooldown, 0.01)
	var is_ready := ready_frac >= 1.0
	draw_circle(c, r, Color(0.05, 0.25, 0.6, 0.85) if is_ready else Color(0.05, 0.12, 0.25, 0.75))
	if not is_ready:
		draw_arc(c, r - 5, -PI / 2, -PI / 2 + TAU * ready_frac, 48, Color(0.4, 0.75, 1, 0.9), 6.0, true)
	draw_arc(c, r, 0, TAU, 64, Color(0.6, 0.85, 1, 0.9 if is_ready else 0.4), 3.0, true)
	if _pressed_flash > 0:
		draw_circle(c, r, Color(1, 1, 1, 0.3 * _pressed_flash))
	var col := Color(1, 1, 1, 1.0 if is_ready else 0.45)
	for dx in [-14.0, 6.0]:
		var p := c + Vector2(dx, 0)
		draw_polyline(PackedVector2Array([p + Vector2(-8, -16), p + Vector2(8, 0), p + Vector2(-8, 16)]), col, 7.0, true)
