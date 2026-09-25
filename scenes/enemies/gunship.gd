extends Enemy
## Gunship: strafes along the upper arena and fires three-round bursts from twin cannons.

const CANNONS := [Vector2(-9, 64), Vector2(9, 64)]

var _home := Vector2.ZERO
var _phase := 0.0
var _fire_timer := 1.2
var _burst_left := 0
var _burst_timer := 0.0


func _on_arrived() -> void:
	_home = global_position
	_phase = randf() * TAU


func _behave(delta: float) -> void:
	var target_x := 360.0 + sin(t * 0.55 + _phase) * 220.0
	global_position.x = move_toward(global_position.x, target_x, move_speed * delta)
	global_position.y = lerpf(global_position.y, _home.y + sin(t * 0.9) * 30.0, 1.0 - exp(-2.0 * delta))
	global_position += _separation() * delta
	var p := _player()
	if p:
		_face((p.global_position - global_position).angle(), delta, 3.0)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 2.2
		_burst_left = 3
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.14
			_burst_left -= 1
			for c in CANNONS:
				_fire_at(c, 360.0, 10.0)
	var flicker := 0.75 + randf() * 0.25
	for glow: Sprite2D in [$ExhaustL, $ExhaustR, $ExhaustC]:
		glow.modulate.a = flicker
