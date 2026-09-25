extends Control
## On-screen stick (bottom-left). Touches anywhere in the lower-left of the screen grab it.
## Writes GameState.touch_move in the -1..1 range.
##
## Runs while the game is paused so it still sees the finger lift when a menu pops up mid-drag,
## and any new touch in the zone takes over (a missed release can never leave the stick stuck).

const RADIUS := 86.0
const DEADZONE := 0.12

var _touch := -1
var _knob := Vector2.ZERO
var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# A menu opening or closing resets the stick; the player re-touches to move again.
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		_release()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _in_zone(event.position):
				_touch = event.index
				_update(event.position)
		elif event.index == _touch:
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
	# While paused (upgrade / pause menu) only track the finger; don't feed movement.
	GameState.touch_move = v if v.length() > DEADZONE and not get_tree().paused else Vector2.ZERO
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	GameState.touch_move = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_release()


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
