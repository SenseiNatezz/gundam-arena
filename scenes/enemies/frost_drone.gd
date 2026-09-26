extends Enemy
## Frost drone (Cryo Reactor): hovers at range, drifting between spots, and fires spreads of
## three snowballs that chill (slow) the player.

const SNOWBALL_SPEED := 210.0
const SNOWBALL_DAMAGE := 8.0
const MUZZLE := Vector2(0, 32)

var _home := Vector2.ZERO
var _seed := 0.0
var _fire_timer := 0.0
var _move_timer := 0.0


func _on_arrived() -> void:
	_home = global_position
	_seed = randf() * TAU
	_fire_timer = randf_range(1.0, 2.4)
	_move_timer = randf_range(3.0, 5.0)


func _behave(delta: float) -> void:
	var p := _player()
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(3.0, 5.0)
		_home = Vector2(randf_range(160, 560), randf_range(240, 620))
	var bob := Vector2(sin(t * 1.5 + _seed) * 30.0, cos(t * 1.2 + _seed) * 16.0)
	global_position = global_position.lerp(_home + bob, 1.0 - exp(-1.8 * delta))
	global_position += _separation() * delta
	if p:
		_face((p.global_position - global_position).angle(), delta, 5.0)
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = randf_range(2.6, 3.4)
		if p:
			var origin := to_global(MUZZLE)
			var base := (p.global_position - origin).angle()
			for i in 3:
				var a := base + deg_to_rad(14.0) * (i - 1)
				GameState.world.fire_enemy_snowball(origin, Vector2.from_angle(a) * SNOWBALL_SPEED, SNOWBALL_DAMAGE)
			Sfx.play(&"snow_hit", -12.0, 0.2)
