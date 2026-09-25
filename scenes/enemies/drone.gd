extends Enemy
## Scout drone: hovers in formation for a while, then dives at the player, taking pot-shots.

var _state := &"hover"
var _state_time := 0.0
var _fire_timer := 0.0
var _home := Vector2.ZERO
var _seed := 0.0


func _on_arrived() -> void:
	_home = global_position
	_state_time = randf_range(1.5, 4.5)
	_fire_timer = randf_range(1.0, 3.0)
	_seed = randf() * TAU


func _behave(delta: float) -> void:
	var p := _player()
	var to := (p.global_position - global_position) if p else Vector2.DOWN
	_state_time -= delta
	if _state == &"hover" or p == null:
		var bob := Vector2(sin(t * 1.7 + _seed) * 40.0, cos(t * 1.3 + _seed) * 18.0)
		global_position = global_position.lerp(_home + bob, 1.0 - exp(-3.0 * delta))
		if _state_time <= 0.0:
			_state = &"dive"
			_state_time = randf_range(2.2, 3.2)
	else:
		# Dive at the player for a few seconds, then peel off to a new hover spot.
		var dir := to.normalized().rotated(sin(t * 2.2 + _seed) * 0.55)
		global_position += dir * move_speed * delta
		if _state_time <= 0.0:
			_state = &"hover"
			_state_time = randf_range(2.0, 4.0)
			_home = Vector2(randf_range(110, 610), randf_range(240, 620))
	global_position += _separation() * delta
	_face(to.angle(), delta, 8.0)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = randf_range(2.6, 4.4)
		if p and to.length() > 180.0:
			_fire_at(Vector2(0, 22), 290.0, 7.0)
	$Eye.modulate.a = 0.7 + sin(t * 12.0) * 0.3
