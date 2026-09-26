class_name Player
extends CharacterBody2D
## The Gundam: movement, dash, auto-aim fire, missiles, shield and damage handling.

signal died

const DASH_SPEED := 1250.0
const DASH_TIME := 0.18
const SHIELD_RECHARGE := 7.0
const MISSILE_INTERVAL := 1.4
## Where the mech may move; each level sets this from Arena.play_rect() (walls, reactors etc.).
var bounds := Rect2(78, 200, 564, 1030)
const AIM_RANGE := 1000.0
const BEAM_RIFLE := preload("res://scenes/abilities/beam_rifle.gd")
const BEAM_COOLDOWN := 12.0
const BEAM_DAMAGE_MULT := 12.0
const SABER_SLASH := preload("res://scenes/abilities/saber_slash.gd")
const SABER_COOLDOWN := 6.0
const SABER_DAMAGE_MULT := 6.0
const SABER_TIME := 0.5  # matches SaberSlash.DURATION

var hp := 100.0
var dead := false
var aim_angle := -PI / 2
var dash_cooldown_left := 0.0
var shield_charges := 0
## Beam Rifle special (E / Q or the HUD button). Ready at the start of every level.
var beam_cooldown_left := 0.0
## Beam Saber spin slash (F / R or the HUD button).
var saber_cooldown_left := 0.0
var _slash_time_left := 0.0

var _move_velocity := Vector2.ZERO
var _knockback := Vector2.ZERO
var _dash_time_left := 0.0
var _dash_dir := Vector2.UP
var _invuln := 0.0
var _fire_cooldown := 0.0
var _missile_cooldown := MISSILE_INTERVAL
var _shield_recharge := SHIELD_RECHARGE
var _flash := 0.0
var _muzzle_time := 0.0
var _afterimage_timer := 0.0
var _max_hp := 100.0
## Cryo Reactor status effects: chill slows movement; freeze encases the mech in ice (dash breaks it).
var _chill_time := 0.0
var _freeze_time := 0.0
const CHILL_SPEED := 0.55
var _target: Node2D

@onready var body: Node2D = $Body
@onready var sprite: AnimatedSprite2D = $Body/Sprite
@onready var muzzle: Marker2D = $Body/Muzzle
@onready var muzzle_flash: Sprite2D = $Body/MuzzleFlash
@onready var thrusters: Array[GPUParticles2D] = [$Body/ThrusterL, $Body/ThrusterR]
@onready var hurtbox: Area2D = $Hurtbox
@onready var shield_ring: Node2D = $ShieldRing
@onready var ice_shell: Node2D = $IceShell


func _ready() -> void:
	GameState.player = self
	_max_hp = GameState.stats.max_hp
	hp = _max_hp
	shield_charges = GameState.stats.shield
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.hp_changed.emit.call_deferred(hp, _max_hp)
	# Sword swing sprites live in their own sheet (tools/render_gundam_sword.py); merge them in.
	if not sprite.sprite_frames.has_animation(&"slash"):
		var sword: SpriteFrames = load("res://assets/sprites/gundam_sword_frames.tres")
		sprite.sprite_frames.add_animation(&"slash")
		sprite.sprite_frames.set_animation_loop(&"slash", false)
		sprite.sprite_frames.set_animation_speed(&"slash", sword.get_animation_speed(&"slash"))
		for i in sword.get_frame_count(&"slash"):
			sprite.sprite_frames.add_frame(&"slash", sword.get_frame_texture(&"slash", i))


func _physics_process(delta: float) -> void:
	if dead:
		return
	var s := GameState.stats
	var live_input: bool = not GameState.debug.no_input
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down") if live_input else Vector2.ZERO
	if GameState.touch_move != Vector2.ZERO:
		input = GameState.touch_move
	if GameState.debug.autopilot:
		input = _autopilot_input()

	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	_invuln -= delta
	beam_cooldown_left = maxf(beam_cooldown_left - delta, 0.0)
	var beam_pressed := (live_input and Input.is_action_just_pressed("special")) or GameState.consume_special_request()
	if GameState.debug.autopilot and beam_ready() and GameState.world.nearest_enemy(global_position, AIM_RANGE):
		beam_pressed = true
	if beam_pressed and beam_ready():
		fire_beam()
	saber_cooldown_left = maxf(saber_cooldown_left - delta, 0.0)
	var saber_pressed := (live_input and Input.is_action_just_pressed("saber")) or GameState.consume_saber_request()
	if GameState.debug.autopilot and saber_ready() and GameState.world.nearest_enemy(global_position, 170.0):
		saber_pressed = true
	if saber_pressed and saber_ready():
		start_slash()
	_chill_time = maxf(_chill_time - delta, 0.0)
	if _freeze_time > 0.0:
		_freeze_time -= delta
		input = Vector2.ZERO
	var dash_pressed := (live_input and Input.is_action_just_pressed("dash")) or GameState.consume_dash_request()
	if dash_pressed and _freeze_time > 0.0:
		_break_ice()
		dash_pressed = false
	if dash_pressed and dash_cooldown_left <= 0.0:
		_start_dash(input)

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		_move_velocity = _dash_dir * DASH_SPEED
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.03
			_spawn_afterimage()
	else:
		_move_velocity = _move_velocity.lerp(input * s.move_speed * (CHILL_SPEED if _chill_time > 0.0 else 1.0), 1.0 - exp(-16.0 * delta))
	velocity = _move_velocity + _knockback
	if _freeze_time > 0.0:
		# Encased in ice: no sliding from momentum or knockback.
		velocity = Vector2.ZERO
		_move_velocity = Vector2.ZERO
		_knockback = Vector2.ZERO
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	move_and_slide()
	global_position = global_position.clamp(bounds.position, bounds.end)

	_update_weapons(delta)
	if _slash_time_left > 0.0:
		# The mech spins with the blade.
		_slash_time_left -= delta
		var spin := 1.0 - clampf(_slash_time_left / SABER_TIME, 0.0, 1.0)
		body.rotation = aim_angle + PI / 2 + TAU * 1.05 * ease(spin, 0.55)
	_update_shield(delta)
	_check_contact_damage()
	_update_visuals(delta, input)


# --- weapons -----------------------------------------------------------------

func _update_weapons(delta: float) -> void:
	var s := GameState.stats
	_target = GameState.world.nearest_enemy(global_position, AIM_RANGE)
	var desired := -PI / 2
	if _target:
		desired = (_target.global_position - global_position).angle()
	aim_angle = lerp_angle(aim_angle, desired, 1.0 - exp(-14.0 * delta))
	body.rotation = aim_angle + PI / 2

	_fire_cooldown -= delta
	if _target and _fire_cooldown <= 0.0 and _dash_time_left <= 0.0:
		_fire_cooldown = 1.0 / s.fire_rate
		_fire()

	if s.homing > 0:
		_missile_cooldown -= delta
		if _target and _missile_cooldown <= 0.0:
			_missile_cooldown = MISSILE_INTERVAL
			for i in int(s.homing):
				var side := -1.0 if i % 2 == 0 else 1.0
				var dir := Vector2.from_angle(aim_angle + PI + side * (0.9 + 0.25 * (i / 2)))
				GameState.world.fire_missile(global_position + dir * 20.0, dir * 380.0, s.damage * 1.6)
			Sfx.play(&"missile", -10.0)


func _fire() -> void:
	var s := GameState.stats
	var origin := muzzle.global_position
	var base := (_target.global_position - origin).angle()
	var count := int(s.multishot)
	var step := deg_to_rad(s.spread_deg)
	for i in count:
		var angle := base + step * (i - (count - 1) / 2.0)
		var crit: bool = randf() < s.crit_chance
		var damage: float = s.damage * randf_range(0.85, 1.15) * (2.0 if crit else 1.0)
		GameState.world.fire_player_bullet(origin, Vector2.from_angle(angle) * s.bullet_speed, damage, crit, int(s.pierce))
	_muzzle_time = 0.05
	sprite.position = Vector2(0, 5)
	Sfx.play(&"shoot", -17.0)


# --- Beam Saber -------------------------------------------------------------------------

func saber_ready() -> bool:
	return saber_cooldown_left <= 0.0 and not dead and _slash_time_left <= 0.0


## Spin slash: a crescent sweeps one full turn around the mech (see SaberSlash).
func start_slash() -> void:
	var slash := Node2D.new()
	slash.set_script(SABER_SLASH)
	slash.set("damage", GameState.stats.damage * SABER_DAMAGE_MULT)
	slash.set("start_angle", aim_angle)
	add_child(slash)
	saber_cooldown_left = SABER_COOLDOWN
	_slash_time_left = SABER_TIME
	_invuln = maxf(_invuln, SABER_TIME + 0.1)  # untouchable mid-spin
	_fire_cooldown = SABER_TIME
	sprite.play(&"slash")


# --- Beam Rifle -------------------------------------------------------------------------

func beam_ready() -> bool:
	return beam_cooldown_left <= 0.0 and not dead


## Fires a piercing beam from the rifle at the current target (or straight ahead).
func fire_beam() -> void:
	var target: Node2D = GameState.world.nearest_enemy(global_position, AIM_RANGE)
	if target:
		aim_angle = (target.global_position - global_position).angle()
		body.rotation = aim_angle + PI / 2
	var origin := muzzle.global_position
	var dir := (target.global_position - origin).normalized() if target else Vector2.from_angle(aim_angle)
	var beam := Node2D.new()
	beam.set_script(BEAM_RIFLE)
	beam.set("origin", origin)
	beam.set("dir", dir)
	beam.set("damage", GameState.stats.damage * BEAM_DAMAGE_MULT)
	GameState.world.add_fx(beam)
	beam_cooldown_left = BEAM_COOLDOWN
	_fire_cooldown = 0.35  # brief pause in normal fire while the beam is out
	_knockback = -dir * 280.0
	_muzzle_time = 0.12
	sprite.position = Vector2(0, 9)


func _break_ice() -> void:
	_freeze_time = 0.0
	ice_shell.set("frozen", false)
	GameState.world.spawn_snow_burst(global_position, 0.9)
	Sfx.play(&"freeze", -8.0, 0.2)


func make_invulnerable() -> void:
	_invuln = INF


# --- dash / shield / damage -------------------------------------------------------

func _start_dash(input: Vector2) -> void:
	_dash_dir = input.normalized() if input.length() > 0.1 else Vector2.from_angle(aim_angle)
	_dash_time_left = DASH_TIME
	dash_cooldown_left = GameState.stats.dash_cooldown
	_invuln = DASH_TIME + 0.12
	sprite.play(&"dash")
	Sfx.play(&"dash", -6.0)


func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.rotation = body.rotation
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.35, 0.75, 1.0, 0.55)
	ghost.z_index = -1
	GameState.world.add_fx(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)


func _update_shield(delta: float) -> void:
	var max_charges := int(GameState.stats.shield)
	if shield_charges < max_charges:
		_shield_recharge -= delta
		if _shield_recharge <= 0.0:
			shield_charges += 1
			_shield_recharge = SHIELD_RECHARGE
			Sfx.play(&"shield", -12.0)
	shield_ring.set("charges", shield_charges)


func _check_contact_damage() -> void:
	if _invuln > 0.0:
		return
	for area in hurtbox.get_overlapping_areas():
		if area is Enemy and not area.dead and area.contact_damage > 0.0:
			take_damage(area.contact_damage, area.global_position)
			return


## `heat`: fire damage (fireballs, eruptions, flame slams) - reduced by the Heat Shield upgrade.
## `chill` / `freeze`: seconds of slow / ice-encasement from snow and ice attacks.
func take_damage(amount: float, from_pos: Vector2, heat := false, chill := 0.0, freeze := 0.0) -> void:
	if dead or _invuln > 0.0 or _dash_time_left > 0.0 or GameState.debug.god:
		return
	_knockback = (global_position - from_pos).normalized() * 520.0
	if heat:
		amount *= 1.0 - minf(GameState.stats.heat_resist, 0.8)
	if shield_charges > 0:
		shield_charges -= 1
		_shield_recharge = SHIELD_RECHARGE
		_invuln = 0.45
		shield_ring.call("pop")
		Sfx.play(&"shield", -4.0)
		return
	hp -= amount
	if chill > 0.0 or freeze > 0.0:
		_chill_time = maxf(_chill_time, maxf(chill, freeze + 1.0))
		if freeze > 0.0 and _freeze_time <= 0.0:
			_freeze_time = freeze
			_move_velocity = Vector2.ZERO
			Sfx.play(&"freeze", -4.0, 0.1)
			ice_shell.set("frozen", true)
		else:
			Sfx.play(&"snow_hit", -8.0, 0.15)
	_invuln = 0.8
	_flash = 1.0
	GameState.world.shake(0.5)
	GameState.world.spawn_damage_number(global_position + Vector2(0, -60), amount, false, true)
	Sfx.play(&"hurt", -3.0)
	GameState.hp_changed.emit(maxf(hp, 0.0), _max_hp)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	hurtbox.set_deferred("monitoring", false)
	for t in thrusters:
		t.emitting = false
	GameState.world.spawn_explosion(global_position, 1.8)
	GameState.world.shake(1.0)
	Sfx.play(&"big_explode")
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.5)
	died.emit()


func _on_stats_changed() -> void:
	var new_max: float = GameState.stats.max_hp
	if new_max > _max_hp:
		hp = minf(hp + new_max - _max_hp, new_max)
	_max_hp = new_max
	var max_charges := int(GameState.stats.shield)
	if shield_charges < max_charges and _shield_recharge >= SHIELD_RECHARGE - 0.01:
		shield_charges += 1
	GameState.hp_changed.emit(hp, _max_hp)


# --- visuals -----------------------------------------------------------------------

func _update_visuals(delta: float, input: Vector2) -> void:
	var anim := &"idle"
	if _slash_time_left > 0.0:
		anim = &"slash"
	elif _dash_time_left > 0.0:
		anim = &"dash"
	elif input.length() > 0.2:
		var local := input.rotated(-body.rotation)
		if local.x < -0.55:
			anim = &"bank_left"
		elif local.x > 0.55:
			anim = &"bank_right"
		else:
			anim = &"boost"
	elif _target:
		anim = &"fire"
	if sprite.animation != anim and not (sprite.animation == &"dash" and sprite.is_playing()):
		sprite.play(anim)

	var moving := input.length() > 0.2 or _dash_time_left > 0.0
	for t in thrusters:
		t.amount_ratio = 1.0 if moving else 0.45
		t.speed_scale = 1.3 if _dash_time_left > 0.0 else 1.0

	sprite.position = sprite.position.lerp(Vector2.ZERO, 1.0 - exp(-30.0 * delta))
	_muzzle_time -= delta
	muzzle_flash.visible = _muzzle_time > 0.0
	if muzzle_flash.visible:
		muzzle_flash.rotation = randf() * TAU
		muzzle_flash.scale = Vector2.ONE * randf_range(0.7, 1.0)

	_flash = move_toward(_flash, 0.0, delta * 5.0)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	var blinking := _invuln > 0.0 and _dash_time_left <= 0.0 and _flash < 0.9 and hp < _max_hp
	sprite.modulate.a = 0.45 if blinking and int(_invuln * 20.0) % 2 == 0 else 1.0
	# Frosty tint while chilled.
	var tint := Color(0.7, 0.88, 1.0) if _chill_time > 0.0 else Color.WHITE
	sprite.modulate = Color(tint, sprite.modulate.a)
	if _freeze_time <= 0.0 and ice_shell.get("frozen"):
		ice_shell.set("frozen", false)


## Debug-only bot (--autopilot): wanders the lower arena, steers away from threats, dashes through bullets.
func _autopilot_input() -> Vector2:
	var t := GameState.run_time
	var goal := Vector2(360.0 + sin(t * 0.8) * 230.0, 1000.0 + sin(t * 1.6) * 110.0)
	var steer := (goal - global_position).limit_length(60.0) / 60.0
	var danger := false
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		var away := global_position - e.global_position
		if away.length() < 190.0:
			steer += away.normalized() * (190.0 - away.length()) / 60.0
	for b: Bullet in GameState.world._pools[&"enemy"].items:
		if not b.active:
			continue
		var away := global_position - b.global_position
		if away.length() < 150.0 and b.velocity.dot(away) > 0.0:
			steer += away.normalized().orthogonal() * signf(away.cross(b.velocity)) * -1.5
			danger = danger or away.length() < 70.0
	if danger and dash_cooldown_left <= 0.0:
		GameState.dash_requested = true
	return steer.limit_length(1.0)
