extends Node
## Input smoke test, attached by Main when launched with `-- --smoke-test`:
##   godot --headless --path . -- --smoke-test --god
## Pushes real input events through the viewport and prints PASS/FAIL lines.

var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(name: String, ok: bool, detail := "") -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var main := get_parent()
	var vp := get_viewport()
	var player: Player = main.get_node("Entities/Player")
	await _frames(5)
	if GameState.has_meta("smoke_restarted"):
		# Second pass after Main._new_run(): the fresh scene must be playable again.
		await _frames(260)  # intro (2s) + first group delay (1.4s)
		_check("restart reloads a clean run", GameState.wave == 1 and GameState.stacks.is_empty() and not player.dead
			and get_tree().get_nodes_in_group("enemies").size() > 0, "wave=%d enemies=%d" % [GameState.wave, get_tree().get_nodes_in_group("enemies").size()])
		print("SMOKE TEST DONE  failures=%d" % _failures)
		get_tree().quit(1 if _failures else 0)
		return

	# Touch joystick: press at its center, drag right.
	var joy: Control = main.get_node("HUD/Root/Joystick")
	var c := joy.get_global_rect().get_center()
	var start_x := player.global_position.x
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = c
	vp.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = c + Vector2(90, 0)
	vp.push_input(drag, true)
	await _frames(30)
	_check("joystick drives touch_move", GameState.touch_move.x > 0.9, str(GameState.touch_move))
	_check("player moves right", player.global_position.x - start_x > 100.0, "dx=%.0f" % (player.global_position.x - start_x))
	touch.pressed = false
	vp.push_input(touch, true)
	await _frames(2)
	_check("joystick release", GameState.touch_move == Vector2.ZERO)

	# Dash button tap (second finger).
	var dash: Control = main.get_node("HUD/Root/DashButton")
	var tap := InputEventScreenTouch.new()
	tap.index = 1
	tap.pressed = true
	tap.position = dash.get_global_rect().get_center()
	vp.push_input(tap, true)
	await _frames(3)
	_check("dash button starts cooldown", player.dash_cooldown_left > 0.0, "cd=%.2f" % player.dash_cooldown_left)
	tap.pressed = false
	vp.push_input(tap, true)

	# Pause action toggles pause + menu.
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	vp.push_input(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("pause opens menu", get_tree().paused and main.get_node("PauseMenu").visible)
	esc.pressed = false
	vp.push_input(esc)
	await get_tree().process_frame
	esc.pressed = true
	vp.push_input(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("pause again resumes", not get_tree().paused and not main.get_node("PauseMenu").visible)

	# Upgrade flow: force a level-up and pick card 1 with the keyboard.
	var level_before := GameState.level
	GameState.add_xp(GameState.xp_needed)
	await get_tree().process_frame
	await get_tree().process_frame
	var menu: CanvasLayer = main.get_node("UpgradeMenu")
	_check("level-up opens upgrade menu", menu.visible and get_tree().paused, "level %d -> %d" % [level_before, GameState.level])
	await get_tree().create_timer(0.5).timeout
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1
	key.pressed = true
	vp.push_input(key)
	await get_tree().process_frame
	await get_tree().process_frame
	var stacks := 0
	for v in GameState.stacks.values():
		stacks += v
	_check("key 1 picks upgrade", not menu.visible and not get_tree().paused and stacks == 1, str(GameState.stacks))

	# Regression (phone bug): holding the stick when the upgrade menu pops up, lifting the finger
	# while paused, then picking a card must not leave the stick stuck — and a new touch must work.
	touch.index = 0
	touch.pressed = true
	touch.position = c
	vp.push_input(touch, true)
	drag.position = c + Vector2(70, 70)
	vp.push_input(drag, true)
	await _frames(3)
	GameState.add_xp(GameState.xp_needed)
	await get_tree().process_frame
	await get_tree().process_frame
	touch.pressed = false
	touch.position = c + Vector2(70, 70)
	vp.push_input(touch, true)  # finger lifts while the menu has the game paused
	await get_tree().create_timer(0.5).timeout
	vp.push_input(key, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await _frames(3)
	_check("stick released after menu", GameState.touch_move == Vector2.ZERO and not get_tree().paused, str(GameState.touch_move))
	var touch2 := InputEventScreenTouch.new()
	touch2.index = 3  # browsers may hand out a fresh touch index
	touch2.pressed = true
	touch2.position = c
	vp.push_input(touch2, true)
	var drag2 := InputEventScreenDrag.new()
	drag2.index = 3
	drag2.position = c + Vector2(-90, 0)
	vp.push_input(drag2, true)
	await _frames(3)
	_check("new touch drives stick", GameState.touch_move.x < -0.9, str(GameState.touch_move))
	touch2.pressed = false
	vp.push_input(touch2, true)
	await _frames(2)

	# Beam Rifle: tap the HUD button once enemies are in range; it must hit and start its cooldown.
	# Wait until wave 1 has flown in far enough to be targetable (up to ~8s).
	for i in 480:
		if GameState.world.nearest_enemy(player.global_position, player.AIM_RANGE):
			break
		await get_tree().physics_frame
	var beam_btn: Control = main.get_node("HUD/Root/BeamButton")
	_check("beam button ready at start", player.beam_ready())
	var hp_before := 0.0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		hp_before += e.hp
	var kills_before := GameState.kills
	var tap_beam := InputEventScreenTouch.new()
	tap_beam.index = 2
	tap_beam.pressed = true
	tap_beam.position = beam_btn.global_position + Vector2(beam_btn.size.x / 2, 56)
	vp.push_input(tap_beam, true)
	await _frames(4)
	var hp_after := 0.0
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		hp_after += e.hp
	_check("beam fires and starts cooldown", player.beam_cooldown_left > 11.0, "cd=%.1f" % player.beam_cooldown_left)
	_check("beam damages enemies", hp_after < hp_before or GameState.kills > kills_before,
		"hp %.0f -> %.0f, kills %d -> %d" % [hp_before, hp_after, kills_before, GameState.kills])
	tap_beam.pressed = false
	vp.push_input(tap_beam, true)

	# Beam Saber: drones right next to the mech get hit by the spin, and nearby enemy shots are cut.
	var saber_btn: Control = main.get_node("HUD/Root/SaberButton")
	_check("saber button ready at start", player.saber_ready())
	var close_drones: Array[Enemy] = []
	for i in 3:
		var spot := player.global_position + Vector2.from_angle(i * TAU / 3.0) * 100.0
		close_drones.append(GameState.world.spawn_enemy(&"drone", spot, spot, true))
	var shot_origin := player.global_position + Vector2(0, -130)
	GameState.world.fire_enemy_bullet(shot_origin, Vector2(0, 40), 10.0)
	await _frames(3)
	var tap_saber := InputEventScreenTouch.new()
	tap_saber.index = 3
	tap_saber.pressed = true
	tap_saber.position = saber_btn.global_position + Vector2(saber_btn.size.x / 2, 56)
	vp.push_input(tap_saber, true)
	await _frames(40)
	_check("saber starts its cooldown", player.saber_cooldown_left > 4.0, "cd=%.1f" % player.saber_cooldown_left)
	var hurt := 0
	for d in close_drones:
		if not is_instance_valid(d) or d.dead or d.hp < d.max_hp:
			hurt += 1
	_check("saber hits all nearby drones", hurt == close_drones.size(), "%d/%d" % [hurt, close_drones.size()])
	var live_shots := 0
	for b in GameState.world.enemy_projectiles():
		if b.active and b.global_position.distance_to(player.global_position) < 150.0:
			live_shots += 1
	_check("saber cuts nearby enemy shots", live_shots == 0, "live=%d" % live_shots)
	tap_saber.pressed = false
	vp.push_input(tap_saber, true)

	# Ice damage: a freezing hit locks the mech in place; dashing breaks free early.
	player.dash_cooldown_left = 0.0
	player._invuln = 0.0
	var hp_before_ice := player.hp
	var god_was: bool = GameState.debug.god
	GameState.debug.god = false
	player.take_damage(5.0, player.global_position + Vector2(0, -50), false, 1.5, 1.0)
	GameState.debug.god = god_was
	_check("ice hit freezes the mech", player._freeze_time > 0.0 and player.ice_shell.visible and player.hp < hp_before_ice,
		"freeze=%.2f" % player._freeze_time)
	var frozen_at := player.global_position
	GameState.touch_move = Vector2(1, 0)
	await _frames(10)
	_check("frozen mech cannot move", player.global_position.distance_to(frozen_at) < 20.0,
		"moved %.0f" % player.global_position.distance_to(frozen_at))
	GameState.dash_requested = true
	await _frames(3)
	GameState.touch_move = Vector2.ZERO
	_check("dash breaks the ice", player._freeze_time <= 0.0 and not player.ice_shell.visible)
	await _frames(80)  # let the chill wear off

	# Destructible cover: enemy shots are stopped by a big crate and break it within 5 hits.
	var crate: Cover = null
	for cov: Cover in get_tree().get_nodes_in_group("cover"):
		if cov.kind == &"crate" and cov.max_hits == 5 and cov.global_position.x < 200.0:
			crate = cov
			break
	_check("level 1 has destructible crates", crate != null)
	if crate:
		var shots := 0
		while not crate.broken and shots < 10:
			GameState.world.fire_enemy_bullet(crate.global_position + Vector2(0, -150), Vector2(0, 600), 10.0)
			shots += 1
			await _frames(20)
		_check("enemy shots break a crate within 5 hits", crate.broken and shots <= 5, "shots=%d" % shots)
		await _frames(2)
		_check("broken crate no longer blocks", crate.get_node_or_null("StaticBody2D") == null and not crate.monitorable)

	# The corner from the bug report: right wall + crate stack. Ram it, then drive back out.
	player.global_position = Vector2(630, 540)
	GameState.touch_move = Vector2(0.707, 0.707)
	await _frames(60)
	var wedged := player.global_position
	GameState.touch_move = Vector2(-0.707, -0.707)
	await _frames(30)
	GameState.touch_move = Vector2.ZERO
	_check("escapes right-wall crate corner", wedged.distance_to(player.global_position) > 150.0,
		"%s -> %s" % [wedged.round(), player.global_position.round()])

	if _failures:
		print("SMOKE TEST DONE  failures=%d" % _failures)
		get_tree().quit(1)
		return
	GameState.set_meta("smoke_restarted", true)
	main._new_run()
