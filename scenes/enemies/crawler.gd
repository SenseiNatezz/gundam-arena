extends Enemy
## Mortar crawler: a slow armored tank that trundles between spots and lobs shells at the
## player's position. Each shell shows a red target circle before it lands.

const MORTAR := preload("res://scenes/enemies/mortar_shell.gd")

var _target := Vector2.ZERO
var _fire_timer := 2.0


func _on_arrived() -> void:
	_pick_target()


func _behave(delta: float) -> void:
	var to_target := _target - global_position
	if to_target.length() < 8.0:
		_pick_target()
	else:
		global_position += to_target.normalized() * move_speed * delta
		_face(to_target.angle(), delta, 3.0)
	global_position += _separation() * delta * 0.5

	_fire_timer -= delta
	var p := _player()
	if _fire_timer <= 0.0 and p:
		_fire_timer = randf_range(2.6, 3.4)
		var shell := Node2D.new()
		shell.set_script(MORTAR)
		shell.set("from", to_global(Vector2(0, 40)))
		shell.set("to", p.global_position + p.velocity * 0.4)
		GameState.world.add_fx(shell)
		Sfx.play(&"slam", -14.0, 0.2)


func _pick_target() -> void:
	_target = Vector2(randf_range(120, 600), randf_range(230, 560))
