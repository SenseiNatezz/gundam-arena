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

	# Hyper Mega Cannon: unlock, wait for targets, fire via the touch button, check the full cycle.
	for u in GameState.upgrades:
		if u.id == &"mega_cannon" and not GameState.stacks.has(u.id):
			GameState.apply_upgrade(u)
	player.special_cooldown_left = 0.0
	await get_tree().create_timer(3.0).timeout  # let wave 1 fly in
	var kills_before := GameState.kills
	var special: Control = main.get_node("HUD/Root/SpecialButton")
	_check("cannon button visible after unlock", special.visible)
	var tap_special := InputEventScreenTouch.new()
	tap_special.index = 2
	tap_special.pressed = true
	tap_special.position = special.get_global_rect().get_center()
	vp.push_input(tap_special, true)
	await _frames(3)
	_check("cannon starts (slow-mo, rooted)", player.casting and Engine.time_scale < 0.5, "ts=%.2f" % Engine.time_scale)
	await get_tree().create_timer(2.2, true, false, true).timeout
	_check("cannon finishes and restores time", not player.casting and is_equal_approx(Engine.time_scale, 1.0)
		and player.special_cooldown_left > 0.0, "ts=%.2f cd=%.1f" % [Engine.time_scale, player.special_cooldown_left])
	_check("cannon destroyed enemies", GameState.kills > kills_before, "kills %d -> %d" % [kills_before, GameState.kills])

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
