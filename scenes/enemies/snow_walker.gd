extends Enemy
## Snow walker (Cryo Reactor): a slow four-legged walker that lobs big snowballs at the player.
## Each snowball shows its landing circle, then bursts in a chilling splash.

const LOB := preload("res://scenes/enemies/snowball_lob.gd")

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
	var p := _player()
	if p:
		_face((p.global_position - global_position).angle(), delta, 2.5)
	global_position += _separation() * delta * 0.5
	_fire_timer -= delta
	if _fire_timer <= 0.0 and p:
		_fire_timer = randf_range(2.8, 3.6)
		var lob := Node2D.new()
		lob.set_script(LOB)
		lob.set("from", to_global(Vector2(0, -10)))
		lob.set("to", p.global_position + p.velocity * 0.4)
		GameState.world.add_fx(lob)
		Sfx.play(&"slam", -16.0, 0.2)


func _pick_target() -> void:
	_target = Vector2(randf_range(170, 550), randf_range(240, 560))
