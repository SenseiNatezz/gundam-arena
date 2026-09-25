extends Node2D
## Arena root. Owns projectile pools and spawn helpers (reached via GameState.world),
## runs the wave director, level-up flow, pause / end screens and screen effects.

const PLAYER_BULLET := preload("res://scenes/player_bullet.tscn")
const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const MISSILE := preload("res://scenes/missile.tscn")
const XP_ORB := preload("res://scenes/xp_orb.tscn")
const EXPLOSION := preload("res://scenes/fx/explosion.tscn")
const DAMAGE_NUMBER := preload("res://scenes/fx/damage_number.tscn")
const GLOW := preload("res://assets/fx/glow.tres")
const CAMERA_HOME := Vector2(360, 640)
const ENEMY_MISSILE := preload("res://scenes/enemy_missile.tscn")
const ENEMY_SCENES := {
	&"drone": preload("res://scenes/enemies/drone.tscn"),
	&"gunship": preload("res://scenes/enemies/gunship.tscn"),
	&"boss": preload("res://scenes/enemies/boss.tscn"),
	&"wasp": preload("res://scenes/enemies/wasp.tscn"),
	&"crawler": preload("res://scenes/enemies/crawler.tscn"),
	&"mine": preload("res://scenes/enemies/mine.tscn"),
	&"leviathan": preload("res://scenes/enemies/leviathan.tscn"),
}
const BOSS_TYPES := [&"boss", &"leviathan"]

## Per level: a list of waves. Each wave is a list of groups; a group spawns `count` enemies of
## `type` in a `formation`, `delay` seconds after the previous group.
## Formations: line, row, vee, swarm, sides, center.
const STAGE_WAVES := {
	1: STAGE_1_WAVES,
	2: STAGE_2_WAVES,
}
const STAGE_2_WAVES := [
	[
		{"type": &"wasp", "count": 4, "formation": &"row", "delay": 0.0},
		{"type": &"crawler", "count": 1, "formation": &"center", "delay": 4.0},
		{"type": &"wasp", "count": 4, "formation": &"vee", "delay": 5.0},
	],
	[
		{"type": &"mine", "count": 6, "formation": &"swarm", "delay": 0.0},
		{"type": &"crawler", "count": 2, "formation": &"row", "delay": 3.0},
		{"type": &"wasp", "count": 6, "formation": &"swarm", "delay": 5.0},
	],
	[
		{"type": &"drone", "count": 8, "formation": &"swarm", "delay": 0.0},
		{"type": &"wasp", "count": 6, "formation": &"line", "delay": 4.0},
		{"type": &"crawler", "count": 2, "formation": &"row", "delay": 4.0},
		{"type": &"mine", "count": 8, "formation": &"sides", "delay": 5.0},
	],
	[
		{"type": &"crawler", "count": 3, "formation": &"row", "delay": 0.0},
		{"type": &"wasp", "count": 8, "formation": &"swarm", "delay": 3.0},
		{"type": &"mine", "count": 10, "formation": &"sides", "delay": 6.0},
		{"type": &"gunship", "count": 2, "formation": &"row", "delay": 5.0},
		{"type": &"wasp", "count": 6, "formation": &"vee", "delay": 4.0},
	],
	[
		{"type": &"leviathan", "count": 1, "formation": &"center", "delay": 0.0},
	],
]
const STAGE_1_WAVES := [
	[
		{"type": &"drone", "count": 6, "formation": &"line", "delay": 0.0},
		{"type": &"drone", "count": 6, "formation": &"vee", "delay": 6.0},
	],
	[
		{"type": &"drone", "count": 8, "formation": &"swarm", "delay": 0.0},
		{"type": &"gunship", "count": 1, "formation": &"center", "delay": 4.0},
		{"type": &"drone", "count": 6, "formation": &"vee", "delay": 6.0},
		{"type": &"gunship", "count": 1, "formation": &"center", "delay": 5.0},
	],
	[
		{"type": &"drone", "count": 8, "formation": &"line", "delay": 0.0},
		{"type": &"gunship", "count": 2, "formation": &"row", "delay": 3.0},
		{"type": &"drone", "count": 10, "formation": &"swarm", "delay": 6.0},
		{"type": &"drone", "count": 6, "formation": &"sides", "delay": 5.0},
	],
	[
		{"type": &"gunship", "count": 3, "formation": &"row", "delay": 0.0},
		{"type": &"drone", "count": 10, "formation": &"swarm", "delay": 3.0},
		{"type": &"drone", "count": 8, "formation": &"sides", "delay": 6.0},
		{"type": &"gunship", "count": 3, "formation": &"row", "delay": 6.0},
		{"type": &"drone", "count": 8, "formation": &"vee", "delay": 4.0},
	],
	[
		{"type": &"boss", "count": 1, "formation": &"center", "delay": 0.0},
	],
]

@onready var player: Player = $Entities/Player
@onready var entities: Node2D = $Entities
@onready var projectiles: Node2D = $Projectiles
@onready var fx: Node2D = $FX
@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_menu: CanvasLayer = $UpgradeMenu
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var end_screen: CanvasLayer = $EndScreen
@onready var danger_tint: ColorRect = $Overlay/DangerTint

var _pools: Dictionary = {}
var _add_material := CanvasItemMaterial.new()
var _trauma := 0.0
var _tint_target := 0.0
var _state := &"intro"
var _state_time := 2.0
var _wave_queue: Array = []
var _group_timer := 0.0
var _debug_args: Dictionary = {}
var _cast_at := -1.0  # --cast-at: fire the special at this game time (run_time, not a timer)


func _ready() -> void:
	if GameState.carry_over:
		# "NEXT LEVEL" or retrying a later level: keep the run, start this level fresh.
		GameState.carry_over = false
		GameState.begin_stage()
	else:
		GameState.reset()
		var stage_arg := _early_arg("stage")
		if stage_arg != "":
			GameState.stage = clampi(int(stage_arg), 1, GameState.FINAL_STAGE)
	GameState.snapshot_stage()
	GameState.world = self
	$Arena.setup(GameState.stage)
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pools[&"player"] = _make_pool(PLAYER_BULLET, 160)
	_pools[&"enemy"] = _make_pool(ENEMY_BULLET, 220)
	_pools[&"missile"] = _make_pool(MISSILE, 24)
	_pools[&"enemy_missile"] = _make_pool(ENEMY_MISSILE, 24)
	player.died.connect(_on_player_died)
	GameState.level_up_ready.connect(_on_level_up_ready)
	upgrade_menu.chosen.connect(_on_upgrade_chosen)
	hud.pause_pressed.connect(_toggle_pause)
	pause_menu.primary_pressed.connect(_toggle_pause)
	pause_menu.secondary_pressed.connect(_retry_level)
	end_screen.primary_pressed.connect(_on_end_primary)
	end_screen.secondary_pressed.connect(_new_run)
	var info := GameState.stage_info()
	hud.show_banner(info.title, "Level %d  ·  Clear %d waves" % [GameState.stage, GameState.TOTAL_WAVES], Color(0.6, 0.85, 1.0), 1.0)
	_warm_up()
	_parse_debug_args()


## Reads a `--name=value` user arg before the full debug parse (needed before the arena is built).
func _early_arg(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.split("=", true, 1)[1]
	return ""


func _process(delta: float) -> void:
	# Main keeps processing while paused (so Esc can unpause); gameplay children are pausable.
	if get_tree().paused:
		return
	_update_waves(delta)
	if _cast_at >= 0.0 and GameState.run_time >= _cast_at:
		_cast_at = -1.0
		GameState.special_requested = true
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var amount := _trauma * _trauma
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 22.0 * amount
	camera.rotation = randf_range(-1, 1) * 0.015 * amount
	danger_tint.color.a = lerpf(danger_tint.color.a, _tint_target, 1.0 - exp(-8.0 * delta))


func _notification(what: int) -> void:
	# Phones: switching apps / locking the screen pauses instead of letting enemies keep shooting.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not get_tree().paused \
			and _state in [&"intro", &"fighting", &"between"]:
		_toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


# --- waves -------------------------------------------------------------------------

func _update_waves(delta: float) -> void:
	_state_time -= delta
	match _state:
		&"intro", &"between":
			if _state_time <= 0.0:
				_start_wave(GameState.wave + 1)
		&"fighting":
			if not _wave_queue.is_empty():
				_group_timer -= delta
				if _group_timer <= 0.0:
					_spawn_group(_wave_queue.pop_front())
					if not _wave_queue.is_empty():
						_group_timer = _wave_queue[0].delay
			elif GameState.enemies_remaining <= 0:
				_on_wave_cleared()


func _start_wave(n: int) -> void:
	GameState.wave = n
	GameState.wave_changed.emit(n, GameState.TOTAL_WAVES)
	_wave_queue = STAGE_WAVES[GameState.stage][n - 1].duplicate(true)
	var total := 0
	for group in _wave_queue:
		total += group.count
	GameState.enemies_remaining = total
	GameState.enemies_changed.emit(total)
	_group_timer = 1.4
	_state = &"fighting"
	if GameState.debug.autopilot:
		print("WAVE %d  t=%.1f  hp=%d  level=%d  stacks=%s" % [n, GameState.run_time, player.hp, GameState.level, GameState.stacks])
	if n == GameState.TOTAL_WAVES:
		hud.show_banner("WARNING", GameState.stage_info().boss.capitalize() + " approaching", Color(1.0, 0.25, 0.2), 1.6)
		Sfx.play(&"alarm", -4.0, 0.0)
		_group_timer = 2.4
	else:
		hud.show_banner("WAVE %d" % n, "", Color.WHITE, 1.0)


func _on_wave_cleared() -> void:
	for orb in get_tree().get_nodes_in_group("orbs"):
		orb.attract()
	if GameState.wave >= GameState.TOTAL_WAVES:
		_state = &"won"
		GameState.pending_levels = 0
		player.make_invulnerable()  # leftover bullets can't kill you after the boss falls
		get_tree().create_timer(2.2, false).timeout.connect(_show_victory)
	else:
		_state = &"between"
		_state_time = 2.8
		hud.show_banner("WAVE CLEAR", "", Color(0.5, 1.0, 0.6), 1.0)


func _spawn_group(group: Dictionary) -> void:
	var points := _formation(group.formation, group.count)
	for i in points.size():
		spawn_enemy(group.type, points[i][0], points[i][1])


## Returns [spawn_position, arrive_position] pairs.
func _formation(kind: StringName, count: int) -> Array:
	var out := []
	for i in count:
		var k := float(i) / maxf(count - 1, 1)
		match kind:
			&"line":
				var x := lerpf(130, 590, k)
				out.append([Vector2(x, -60 - i * 22), Vector2(x, 300)])
			&"row":
				var x := lerpf(180, 540, k) if count > 1 else 360.0
				out.append([Vector2(x, -120), Vector2(x, 280)])
			&"vee":
				var off := i - (count - 1) / 2.0
				var target := Vector2(360 + off * 80, 440 - absf(off) * 55)
				out.append([Vector2(target.x, -60 - absf(off) * 45), target])
			&"swarm":
				var target := Vector2(randf_range(110, 610), randf_range(230, 560))
				out.append([Vector2(target.x + randf_range(-80, 80), -60 - i * 35), target])
			&"sides":
				var left := i % 2 == 0
				var y := 260.0 + (i / 2) * 70.0
				out.append([Vector2(-60 if left else 780, y), Vector2(randf_range(130, 330) if left else randf_range(390, 590), y)])
			_:
				out.append([Vector2(360, -160), Vector2(360, 300)])
	return out


func spawn_enemy(type: StringName, from: Vector2, to: Vector2, extra := false) -> Enemy:
	var enemy: Enemy = ENEMY_SCENES[type].instantiate()
	enemy.position = from
	enemy.enter_target = to
	enemy.died.connect(_on_enemy_died)
	entities.add_child(enemy)
	if type in BOSS_TYPES and _debug_args.has("boss-hp"):
		enemy.hp = enemy.max_hp * float(_debug_args["boss-hp"])  # debug: start a boss already damaged
	if extra:
		GameState.enemies_remaining += 1
		GameState.enemies_changed.emit(GameState.enemies_remaining)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	GameState.kills += 1
	GameState.enemies_remaining -= 1
	GameState.enemies_changed.emit(GameState.enemies_remaining)
	var is_boss := BOSS_TYPES.any(func(t: StringName) -> bool: return ENEMY_SCENES[t].resource_path == enemy.scene_file_path)
	if is_boss:
		for other: Enemy in get_tree().get_nodes_in_group("enemies"):
			other.kill()


func nearest_enemy(from: Vector2, max_dist := INF) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist * max_dist
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not e.is_targetable():
			continue
		var d := from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- spawning helpers (called through GameState.world) -------------------------------

func _make_pool(scene: PackedScene, count: int) -> Dictionary:
	var pool := {"scene": scene, "items": [], "cursor": 0}
	for i in count:
		_grow_pool(pool)
	return pool


func _grow_pool(pool: Dictionary) -> Bullet:
	var b: Bullet = pool.scene.instantiate()
	projectiles.add_child(b)
	b.deactivate()
	pool.items.append(b)
	return b


func _take(pool: Dictionary) -> Bullet:
	var items: Array = pool.items
	for i in items.size():
		var idx: int = (pool.cursor + i) % items.size()
		if not items[idx].active:
			pool.cursor = idx + 1
			return items[idx]
	return _grow_pool(pool)


func fire_player_bullet(pos: Vector2, vel: Vector2, damage: float, crit: bool, pierce: int) -> void:
	_take(_pools[&"player"]).launch(pos, vel, damage, crit, pierce)


func fire_missile(pos: Vector2, vel: Vector2, damage: float) -> void:
	_take(_pools[&"missile"]).launch(pos, vel, damage)


func fire_enemy_bullet(pos: Vector2, vel: Vector2, damage: float) -> void:
	_take(_pools[&"enemy"]).launch(pos, vel, damage)


func fire_enemy_missile(pos: Vector2, vel: Vector2, damage: float) -> void:
	_take(_pools[&"enemy_missile"]).launch(pos, vel, damage)


## Explosion that hurts the player and/or enemies inside `radius` (mines, mortar shells).
func area_blast(pos: Vector2, radius: float, player_damage: float, enemy_damage: float, size := 1.0) -> void:
	spawn_explosion(pos, size)
	shake(0.2 * size)
	Sfx.play(&"explode", -6.0, 0.15)
	if player_damage > 0.0 and not player.dead and player.global_position.distance_to(pos) < radius + 20.0:
		player.take_damage(player_damage, pos)
	if enemy_damage > 0.0:
		for e: Enemy in get_tree().get_nodes_in_group("enemies"):
			if not e.dead and e.global_position.distance_to(pos) < radius + e.hit_radius:
				e.take_damage(enemy_damage, false, (e.global_position - pos).normalized(), 200.0)


func spawn_explosion(pos: Vector2, size := 1.0) -> void:
	var e := EXPLOSION.instantiate()
	e.position = pos
	e.size = size
	fx.add_child(e)


func spawn_damage_number(pos: Vector2, amount: float, crit := false, player_hit := false) -> void:
	var label := DAMAGE_NUMBER.instantiate()
	fx.add_child(label)
	label.position = pos - label.size / 2
	label.setup(amount, crit, player_hit)


func spawn_hit_spark(pos: Vector2, color: Color) -> void:
	var s := Sprite2D.new()
	s.texture = GLOW
	s.material = _add_material
	s.modulate = color
	s.position = pos
	s.scale = Vector2.ONE * 0.3
	s.z_index = 6
	fx.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE * 0.9, 0.12)
	tw.tween_property(s, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(s.queue_free)


func spawn_xp(pos: Vector2, value: int) -> void:
	var orb := XP_ORB.instantiate()
	orb.position = pos
	orb.value = value
	fx.add_child.call_deferred(orb)


func add_fx(node: Node2D) -> void:
	fx.add_child(node)


## Floor-level decals (drawn above the arena, below everything else).
func add_floor_decal(node: Node2D) -> void:
	node.z_index = -5
	add_child(node)
	move_child(node, $Arena.get_index() + 1)


var _cinematic_tween: Tween

## Punches the camera toward `focus` (zoom > 1) or back to the arena (focus = Vector2.ZERO).
## Uses real time so it stays smooth during the cannon's slow-motion charge.
func cinematic_focus(focus: Vector2, zoom: float, duration: float) -> void:
	var target := CAMERA_HOME if focus == Vector2.ZERO else CAMERA_HOME.lerp(focus, 0.35)
	if _cinematic_tween:
		_cinematic_tween.kill()
	_cinematic_tween = create_tween().set_parallel().set_ignore_time_scale()
	_cinematic_tween.tween_property(camera, "position", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cinematic_tween.tween_property(camera, "zoom", Vector2.ONE * zoom, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func set_danger_tint(alpha: float) -> void:
	_tint_target = alpha


## Draws one of everything almost invisibly (behind the top HUD) during the intro banner, so the
## browser compiles shaders / particle programs, uploads enemy textures and rasterizes damage-number
## glyphs up front. Without this, the web build hitches the first time each effect appears.
func _warm_up() -> void:
	var warm := Node2D.new()
	warm.position = Vector2(360, 56)
	warm.modulate.a = 0.02
	fx.add_child(warm)
	warm.add_child(EXPLOSION.instantiate())
	for scene: PackedScene in [PLAYER_BULLET, ENEMY_BULLET, MISSILE]:
		var b: Bullet = scene.instantiate()
		b.monitoring = false
		warm.add_child(b)
		b.set_physics_process(false)
		b.show()
		var trail := b.get_node_or_null("Trail") as GPUParticles2D
		if trail:
			trail.emitting = true
	for type in ENEMY_SCENES:
		var enemy: Node = ENEMY_SCENES[type].instantiate()
		warm.add_child(enemy.get_node("Sprite").duplicate())
		enemy.free()
	for style in [[false, false], [true, false], [false, true]]:
		var label := DAMAGE_NUMBER.instantiate()
		warm.add_child(label)
		label.setup(0.0, style[0], style[1])
		label.text = "-0123456789!"
	spawn_hit_spark(Vector2(360, 56), Color(1, 1, 1, 0.02))
	Sfx.warm_up()
	get_tree().create_timer(1.5, false).timeout.connect(warm.queue_free)


# --- level ups / pause / end ---------------------------------------------------------------

func _on_level_up_ready() -> void:
	if upgrade_menu.visible or _state == &"lost" or _state == &"won" or player.dead:
		return
	_open_upgrade_menu.call_deferred()


func _open_upgrade_menu() -> void:
	if upgrade_menu.visible:
		return
	var choices := GameState.roll_upgrades(3)
	if choices.is_empty():
		GameState.pending_levels = 0
		return
	get_tree().paused = true
	upgrade_menu.open(choices)
	if GameState.debug.autopilot:
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if upgrade_menu.visible:
				_on_upgrade_chosen(choices[0]))


func _on_upgrade_chosen(u: Upgrade) -> void:
	GameState.apply_upgrade(u)
	GameState.pending_levels -= 1
	upgrade_menu.close()
	if GameState.pending_levels > 0:
		_open_upgrade_menu()
	else:
		get_tree().paused = false


func _toggle_pause() -> void:
	if upgrade_menu.visible or end_screen.visible:
		return
	if pause_menu.visible:
		pause_menu.close()
		get_tree().paused = false
	else:
		get_tree().paused = true
		pause_menu.open("PAUSED", "Wave %d/%d  ·  Level %d" % [GameState.wave, GameState.TOTAL_WAVES, GameState.level],
			Color(0.7, 0.88, 1.0), "RESUME", "RESTART")


func _on_player_died() -> void:
	if _state == &"won":
		return
	if GameState.debug.autopilot:
		print("DIED  wave=%d  t=%.1f  level=%d" % [GameState.wave, GameState.run_time, GameState.level])
	_state = &"lost"
	set_danger_tint(0.0)
	get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
		get_tree().paused = true
		_end_action = &"retry"
		end_screen.open("MISSION FAILED", _run_summary(), Color(1.0, 0.3, 0.25), "RETRY LEVEL",
			"NEW RUN" if GameState.stage > 1 else ""))


var _end_action := &"retry"

func _show_victory() -> void:
	if GameState.debug.autopilot:
		print("VICTORY  stage=%d  t=%.1f  hp=%d  level=%d" % [GameState.stage, GameState.run_time, player.hp, GameState.level])
	get_tree().paused = true
	if GameState.stage < GameState.FINAL_STAGE:
		_end_action = &"next"
		end_screen.open("SECTOR %s CLEARED" % GameState.stage_info().sector, _run_summary() + "\nYour upgrades carry over.",
			Color(0.45, 1.0, 0.55), "NEXT LEVEL", "NEW RUN")
		if GameState.debug.autopilot:
			get_tree().create_timer(1.0).timeout.connect(_on_end_primary)
	else:
		_end_action = &"new_run"
		end_screen.open("ALL SECTORS CLEARED", _run_summary(), Color(0.45, 1.0, 0.55), "PLAY AGAIN")


func _run_summary() -> String:
	var secs := int(GameState.run_time)
	return "Level %d  ·  Wave %d/%d\nKills %d  ·  Pilot LV %d\nTime %d:%02d" % [
		GameState.stage, GameState.wave, GameState.TOTAL_WAVES, GameState.kills, GameState.level, secs / 60, secs % 60]


func _on_end_primary() -> void:
	match _end_action:
		&"next":
			GameState.stage += 1
			GameState.carry_over = true
			_reload()
		&"retry":
			_retry_level()
		_:
			_new_run()


## Restart the current level with the build the player entered it with.
func _retry_level() -> void:
	if GameState.stage > 1:
		GameState.restore_stage_snapshot()
		GameState.carry_over = true
	_reload()


func _new_run() -> void:
	GameState.carry_over = false
	_reload()


func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- debug -----------------------------------------------------------------------------
# Command-line flags after "--", e.g.:
#   godot --path . -- --god --autopilot --wave=5 --level=6 --hp=10 --shot=shot.png --shot-time=8
#   --cannon (unlock the Hyper Mega Cannon)  --cast-at=S (fire it at S seconds)

func _parse_debug_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_debug_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	# Screenshot / movie capture runs pop a window on the desktop: ignore real mouse/keyboard input
	# (and let clicks pass through) so the recording is deterministic and can't be disturbed.
	GameState.debug.no_input = _debug_args.has("shot") or OS.get_cmdline_args().has("--write-movie")
	if GameState.debug.no_input:
		get_viewport().set_disable_input(true)
		get_window().unfocusable = true
		get_window().mouse_passthrough = true
	GameState.debug.god = _debug_args.has("god")
	GameState.debug.autopilot = _debug_args.has("autopilot")
	if _debug_args.has("level"):
		for i in int(_debug_args.level) - 1:
			var roll := GameState.roll_upgrades(1)
			if not roll.is_empty():
				GameState.apply_upgrade(roll[0])
		GameState.level = int(_debug_args.level)
		GameState.xp_needed = GameState._xp_for(GameState.level)
		GameState.xp_changed.emit(0, GameState.xp_needed, GameState.level)
	if _debug_args.has("hp"):
		player.hp = float(_debug_args.hp)
		GameState.hp_changed.emit(player.hp, GameState.stats.max_hp)
	if _debug_args.has("wave"):
		GameState.wave = int(_debug_args.wave) - 1
		_state_time = 0.3
	if _debug_args.has("upgrade-menu"):
		get_tree().create_timer(float(_debug_args.get("upgrade-menu-time", "1.5"))).timeout.connect(func() -> void:
			GameState.pending_levels += 1
			_open_upgrade_menu())
	if _debug_args.has("pause-menu"):
		get_tree().create_timer(1.0).timeout.connect(_toggle_pause)
	if _debug_args.has("cannon"):
		for u in GameState.upgrades:
			if u.id == &"mega_cannon":
				GameState.apply_upgrade(u)
	if _debug_args.has("cast-at"):
		_cast_at = float(_debug_args["cast-at"])
	if _debug_args.has("smoke-test"):
		add_child(load("res://tools/smoke_test.gd").new())
	if _debug_args.has("shot"):
		get_tree().create_timer(float(_debug_args.get("shot-time", "5"))).timeout.connect(_take_screenshot)


func _take_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var path: String = _debug_args.shot
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT %s  fps=%d  nodes=%d" % [path, Engine.get_frames_per_second(), get_tree().get_node_count()])
	get_tree().quit()
