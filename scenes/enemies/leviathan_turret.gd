extends Enemy
## Leviathan wing turret: a separate target mounted on the battleship. Tracks the player and
## fires four-round bursts from its twin barrels.

const MUZZLES := [Vector2(-7, 42), Vector2(7, 42)]

var _fire_timer := 1.5
var _burst_left := 0
var _burst_timer := 0.0


func _ready() -> void:
	super()
	_fire_timer = randf_range(1.0, 2.2)


func _behave(delta: float) -> void:
	var p := _player()
	if p:
		var desired := (p.global_position - global_position).angle() - PI / 2
		global_rotation = lerp_angle(global_rotation, desired, 1.0 - exp(-5.0 * delta))
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 2.3
		_burst_left = 4
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.12
			_burst_left -= 1
			_fire_at(MUZZLES[_burst_left % 2], 340.0, 10.0)
