extends Enemy
## Wasp interceptor: hovers while it lines up, flashes a warning lane, then streaks straight
## through the arena along it and loops back in from the top.

const DASH_SPEED := 980.0
const WARN_TIME := 0.65
const ARENA := Rect2(-80, -120, 880, 1480)

var _state := &"hover"
var _state_time := 0.0
var _home := Vector2.ZERO
var _dash_dir := Vector2.DOWN
var _seed := 0.0


func _on_arrived() -> void:
	_home = global_position
	_state_time = randf_range(1.2, 2.6)
	_seed = randf() * TAU


func _behave(delta: float) -> void:
	var p := _player()
	_state_time -= delta
	match _state:
		&"hover":
			var bob := Vector2(sin(t * 2.3 + _seed) * 26.0, cos(t * 1.7 + _seed) * 12.0)
			global_position = global_position.lerp(_home + bob, 1.0 - exp(-4.0 * delta))
			if p:
				_face((p.global_position - global_position).angle(), delta, 10.0)
			if _state_time <= 0.0 and p:
				_state = &"warn"
				_state_time = WARN_TIME
				_dash_dir = (p.global_position - global_position).normalized()
		&"warn":
			rotation = lerp_angle(rotation, _dash_dir.angle() - PI / 2, 1.0 - exp(-14.0 * delta))
			global_position -= _dash_dir * 30.0 * delta  # small wind-up backwards
			if _state_time <= 0.0:
				_state = &"dash"
				Sfx.play(&"dash", -8.0, 0.2)
		&"dash":
			global_position += _dash_dir * DASH_SPEED * delta
			if not ARENA.has_point(global_position):
				# Loop back in from the top at a fresh spot.
				_state = &"hover"
				global_position = Vector2(randf_range(100, 620), -80)
				enter_target = Vector2(randf_range(110, 610), randf_range(220, 520))
				entering = true
	if _state != &"dash":
		global_position += _separation() * delta
	queue_redraw()


func _draw() -> void:
	if _state != &"warn" or dead:
		return
	# Warning lane in local space (the node is rotated to face along the dash).
	var blink := 0.35 + 0.45 * absf(sin(t * 28.0))
	var local_dir := _dash_dir.rotated(-rotation)
	var end := local_dir * 1500.0
	draw_line(Vector2.ZERO, end, Color(1, 0.85, 0.1, 0.18), 34.0)
	draw_line(Vector2.ZERO, end, Color(1, 0.9, 0.2, blink), 3.0)
