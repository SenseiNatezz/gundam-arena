extends Enemy
## Seeker mine: drifts toward the player, blinking faster as it closes in, then arms and blows up.
## Shooting it first detonates it early, which also damages nearby enemies (chain reactions!).

const TRIGGER_RANGE := 75.0
const ARM_TIME := 0.4
const BLAST_RADIUS := 95.0
const BLAST_DAMAGE := 22.0

var _speed := 0.0
var _arming := -1.0


func _on_arrived() -> void:
	_speed = move_speed * 0.5


func _behave(delta: float) -> void:
	var p := _player()
	var core: Sprite2D = $Core
	if _arming >= 0.0:
		_arming += delta
		core.modulate = Color(1, 1, 1) if int(_arming * 24.0) % 2 == 0 else Color(1, 0.2, 0.9)
		core.scale = Vector2.ONE * (0.55 + _arming * 1.2)
		if _arming >= ARM_TIME:
			_explode(true)
		return
	if p:
		var to := p.global_position - global_position
		_speed = minf(_speed + 60.0 * delta, move_speed * 1.8)
		global_position += to.normalized() * _speed * delta
		if to.length() < TRIGGER_RANGE:
			_arming = 0.0
			Sfx.play(&"select", -6.0, 0.0)
		var rate := lerpf(3.0, 16.0, clampf(1.0 - to.length() / 500.0, 0.0, 1.0))
		core.modulate.a = 0.45 + 0.55 * absf(sin(t * rate))
	global_position += _separation() * delta * 0.4


func _die() -> void:
	_explode(false)


func _explode(hurt_player: bool) -> void:
	if dead:
		return
	var pos := global_position
	super._die()
	# Popped by gunfire: harmless to the player but it still damages nearby enemies.
	GameState.world.area_blast(pos, BLAST_RADIUS, BLAST_DAMAGE if hurt_player else 0.0, 60.0, 0.9)
