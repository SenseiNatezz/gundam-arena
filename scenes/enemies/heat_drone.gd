extends Enemy
## Heat drone (Volcanic Forge): keeps its distance, drifting between hover spots, and lobs slow
## orange fireballs at the player. Its eyes flare up just before it fires.

const FIREBALL_SPEED := 175.0
const FIREBALL_DAMAGE := 12.0
const MUZZLE := Vector2(0, 30)

var _home := Vector2.ZERO
var _seed := 0.0
var _fire_timer := 0.0
var _move_timer := 0.0


func _on_arrived() -> void:
	_home = global_position
	_seed = randf() * TAU
	_fire_timer = randf_range(1.2, 2.6)
	_move_timer = randf_range(3.0, 5.0)


func _behave(delta: float) -> void:
	var p := _player()
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(3.0, 5.0)
		_home = Vector2(randf_range(110, 610), randf_range(230, 620))
	var bob := Vector2(sin(t * 1.4 + _seed) * 30.0, cos(t * 1.1 + _seed) * 16.0)
	global_position = global_position.lerp(_home + bob, 1.0 - exp(-1.6 * delta))
	global_position += _separation() * delta
	if p:
		_face((p.global_position - global_position).angle(), delta, 5.0)

	_fire_timer -= delta
	# Eyes glow brighter as the next shot charges.
	var charge := clampf(1.0 - _fire_timer / 0.6, 0.0, 1.0)
	for eye: Sprite2D in [$EyeL, $EyeR]:
		eye.scale = Vector2.ONE * (0.28 + charge * 0.22 + sin(t * 20.0) * 0.02)
		eye.modulate.a = 0.75 + charge * 0.25
	if _fire_timer <= 0.0:
		_fire_timer = randf_range(2.4, 3.4)
		if p:
			var origin := to_global(MUZZLE)
			var dir := (p.global_position - origin).normalized()
			GameState.world.fire_enemy_fireball(origin, dir * FIREBALL_SPEED, FIREBALL_DAMAGE)
			Sfx.play(&"enemy_shoot", -10.0, 0.1)
