class_name Enemy
extends Area2D
## Base enemy: HP, hit flash, knockback, fly-in entry, death and XP drops.
## Subclasses override _on_arrived() and _behave().

signal died(enemy: Enemy)

@export var max_hp := 50.0
@export var move_speed := 120.0
@export var contact_damage := 12.0
@export var xp_orbs := 1
@export var xp_value := 1
@export var explosion_size := 1.0
@export_range(0.0, 1.0) var knockback_resist := 0.0
@export var frames := 1
@export var anim_fps := 18.0

var hp := 0.0
var dead := false
var entering := true
var enter_target := Vector2.ZERO
var t := 0.0

var _knockback := Vector2.ZERO
var _flash := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	hp = max_hp
	t = randf() * 10.0
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	if frames > 1:
		sprite.frame = int(t * anim_fps) % frames
	_flash = move_toward(_flash, 0.0, delta * 7.0)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	if entering:
		global_position = global_position.move_toward(enter_target, maxf(move_speed * 2.5, 280.0) * delta)
		_face((enter_target - global_position).angle(), delta, 6.0)
		if global_position.distance_to(enter_target) < 4.0:
			entering = false
			_on_arrived()
	else:
		_behave(delta)
	global_position += _knockback * delta
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))


## Enemies above the arena (still flying in) can't be targeted.
func is_targetable() -> bool:
	return not dead and global_position.y > 60.0


func take_damage(amount: float, crit: bool, hit_dir: Vector2, knock := 170.0) -> void:
	if dead:
		return
	hp -= amount
	_flash = 1.0
	_knockback += hit_dir * knock * (1.0 - knockback_resist)
	GameState.world.spawn_damage_number(global_position + Vector2(randf_range(-18, 18), -34), amount, crit)
	Sfx.play(&"hit", -18.0, 0.2)
	if hp <= 0.0:
		_die()


## Destroys the enemy without a damage number (used when the boss falls).
func kill() -> void:
	if not dead:
		_die()


func _die() -> void:
	dead = true
	remove_from_group("enemies")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	GameState.world.spawn_explosion(global_position, explosion_size)
	GameState.world.shake(0.12 * explosion_size)
	Sfx.play(&"explode", -8.0, 0.15)
	for i in xp_orbs:
		GameState.world.spawn_xp(global_position, xp_value)
	died.emit(self)
	queue_free()


func _player() -> Player:
	var p := GameState.player as Player
	return null if p == null or p.dead else p


## Sprites are rendered facing down (+Y), so rotation = angle - 90°.
func _face(angle: float, delta: float, speed: float) -> void:
	rotation = lerp_angle(rotation, angle - PI / 2, 1.0 - exp(-speed * delta))


## Fires from a point in local space toward the player (or straight ahead if there is none).
func _fire_at(local_origin: Vector2, speed: float, damage: float, count := 1, spread_deg := 0.0) -> void:
	var origin := to_global(local_origin)
	var p := _player()
	var base := (p.global_position - origin).angle() if p else rotation + PI / 2
	for i in count:
		var angle := base + deg_to_rad(spread_deg) * (i - (count - 1) / 2.0)
		GameState.world.fire_enemy_bullet(origin, Vector2.from_angle(angle) * speed, damage)
	Sfx.play(&"enemy_shoot", -16.0, 0.1)


## Soft push away from overlapping enemies so groups don't stack.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for area in get_overlapping_areas():
		if area is Enemy:
			var away := global_position - area.global_position
			push += away.normalized() * 140.0 if away.length() > 0.1 else Vector2.RIGHT.rotated(randf() * TAU) * 140.0
	return push


func _on_arrived() -> void:
	pass


func _behave(_delta: float) -> void:
	pass
