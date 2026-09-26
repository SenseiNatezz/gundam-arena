class_name Bullet
extends Area2D
## Pooled projectile shared by player bolts, homing missiles and enemy shots.
## Main keeps a pool per scene; call launch() to fire and deactivate() to return it.

const LIVE_AREA := Rect2(-100, -250, 920, 1650)

@export var player_owned := true
@export var homing := false
@export var turn_rate := 6.0
@export var lifetime := 1.6
@export var spark_color := Color(0.5, 0.85, 1.0)
## Fire damage (reduced by the Heat Shield upgrade).
@export var heat := false
## Player rockets: size of the small explosion on impact (0 = just a hit spark).
@export var impact_explosion := 0.0

var active := false
var velocity := Vector2.ZERO
var damage := 10.0
var crit := false
var pierce_left := 0
var _life := 0.0
var _hit: Array[Node] = []
@onready var _trail: GPUParticles2D = get_node_or_null("Trail")


func _ready() -> void:
	monitorable = false
	area_entered.connect(_on_area_entered)


func launch(pos: Vector2, vel: Vector2, dmg: float, is_crit := false, pierce := 0) -> void:
	global_position = pos
	velocity = vel
	rotation = vel.angle() + PI / 2
	damage = dmg
	crit = is_crit
	pierce_left = pierce
	_life = lifetime
	_hit.clear()
	active = true
	show()
	set_deferred("monitoring", true)
	set_physics_process(true)
	if _trail:
		_trail.restart()
		_trail.emitting = true


func deactivate() -> void:
	active = false
	hide()
	set_deferred("monitoring", false)
	set_physics_process(false)
	if _trail:
		_trail.emitting = false


func _physics_process(delta: float) -> void:
	_life -= delta
	if homing:
		var target: Node2D = GameState.world.nearest_enemy(global_position) if player_owned else GameState.player
		if target and not (target is Player and target.dead):
			var angle := rotate_toward(velocity.angle(), (target.global_position - global_position).angle(), turn_rate * delta)
			velocity = Vector2.from_angle(angle) * minf(velocity.length() * (1.0 + 1.5 * delta), 1100.0)
	global_position += velocity * delta
	rotation = velocity.angle() + PI / 2
	if _life <= 0.0 or not LIVE_AREA.has_point(global_position):
		deactivate()


func _on_area_entered(area: Area2D) -> void:
	if not active:
		return
	if player_owned:
		if area is Enemy and not _hit.has(area):
			_hit.append(area)
			area.take_damage(damage, crit, velocity.normalized())
			GameState.world.spawn_hit_spark(global_position, spark_color)
			if impact_explosion > 0.0:
				GameState.world.spawn_explosion(global_position, impact_explosion)
				Sfx.play(&"explode", -12.0, 0.2)
			if pierce_left > 0:
				pierce_left -= 1
			else:
				deactivate()
	elif area is Cover:
		# Cover soaks up enemy fire until it breaks.
		area.take_hit(1, global_position)
		deactivate()
	elif area.get_parent() is Player:
		area.get_parent().take_damage(damage, global_position - velocity.normalized() * 40.0, heat)
		GameState.world.spawn_hit_spark(global_position, spark_color)
		deactivate()
