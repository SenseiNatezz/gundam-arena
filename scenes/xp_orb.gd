extends Node2D
## Green XP pickup: pops out of a destroyed enemy, then gets pulled into the player.

var value := 1
var attracted := false
var _velocity := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	add_to_group("orbs")
	_velocity = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 220.0)
	_t = randf() * 0.1


func attract() -> void:
	attracted = true


func _physics_process(delta: float) -> void:
	_t += delta
	_velocity = _velocity.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
	var player := GameState.player as Player
	if player and not player.dead and _t > 0.3:
		var to := player.global_position - global_position
		var dist := to.length()
		var magnet: float = GameState.stats.magnet
		if attracted or dist < magnet:
			var pull := 1200.0 if attracted else lerpf(900.0, 260.0, dist / magnet)
			global_position += to / maxf(dist, 1.0) * pull * delta
		if dist < 30.0:
			GameState.add_xp(value)
			Sfx.play(&"pickup", -14.0, 0.12)
			queue_free()
			return
	global_position += _velocity * delta
	var pulse := 1.0 + sin(_t * 9.0) * 0.12
	$Glow.scale = Vector2.ONE * 0.55 * pulse
