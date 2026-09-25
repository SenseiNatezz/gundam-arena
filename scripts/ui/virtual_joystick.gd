extends Control
## On-screen stick (bottom-left). Touches anywhere in the lower-left of the screen grab it.
## Writes GameState.touch_move in the -1..1 range.

const RADIUS := 86.0
const DEADZONE := 0.12

var _touch := -1
var _knob := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and _in_zone(event.position):
			_touch = event.index
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)


func _in_zone(pos: Vector2) -> bool:
	var vp := get_viewport_rect().size
	return pos.x < vp.x * 0.55 and pos.y > vp.y * 0.55


func _center() -> Vector2:
	return get_global_rect().get_center()


func _update(pos: Vector2) -> void:
	_knob = (pos - _center()).limit_length(RADIUS)
	var v := _knob / RADIUS
	GameState.touch_move = v if v.length() > DEADZONE else Vector2.ZERO
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	GameState.touch_move = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		GameState.touch_move = Vector2.ZERO


func _draw() -> void:
	var c := size / 2
	var active := _touch != -1
	draw_circle(c, RADIUS + 14, Color(0.05, 0.1, 0.18, 0.35 if active else 0.22))
	draw_arc(c, RADIUS + 14, 0, TAU, 64, Color(0.5, 0.75, 1, 0.55 if active else 0.35), 3.0, true)
	for i in 4:
		var dir := Vector2.from_angle(i * PI / 2)
		var tip := c + dir * (RADIUS + 2)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12 + dir.orthogonal() * 8, tip - dir * 12 - dir.orthogonal() * 8]), Color(0.7, 0.85, 1, 0.45))
	draw_circle(c + _knob, 40, Color(0.75, 0.85, 0.95, 0.55 if active else 0.4))
	draw_arc(c + _knob, 40, 0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)
