extends Control
## Main menu. The whole screen is an animated menu video (assets/title/menu_video.ogv, looping) with
## its buttons painted in. Invisible buttons sit exactly over the painted ones:
##   New Game · Continue · Gundam Customization · Settings · Exit
## Customization and Settings open overlay panels. Customization shows an animated preview Gundam.
##
## Launching the project with debug args (e.g. `-- --stage=3 --autopilot`, used by tests) skips
## straight into the game unless `--title` is given.

const MAIN := "res://scenes/main.tscn"
const HERO_FRAMES := 12
const HERO_FPS := 12.0
const HERO_HOME := Vector2(268, 1078)
## Painted button rectangles in the 720x1280 menu video.
const HOTSPOTS := {
	&"new_game": Rect2(33, 329, 264, 48),
	&"continue": Rect2(33, 389, 264, 48),
	&"customize": Rect2(33, 447, 264, 49),
	&"settings": Rect2(33, 506, 264, 48),
	&"exit": Rect2(33, 564, 264, 48),
}
## Real (not painted) button added under Exit, styled to match the painted ones.
const LEVEL_SELECT_RECT := Rect2(33, 624, 264, 48)
const LEVEL_COLORS := {1: Color(0.55, 0.65, 0.8), 2: Color(1.0, 0.55, 0.2), 3: Color(1.0, 0.35, 0.1), 4: Color(0.45, 0.85, 1.0)}

@onready var video: VideoStreamPlayer = $Video
@onready var hotspots: Control = $Hotspots
@onready var continue_dim: ColorRect = %ContinueDim
@onready var continue_info: Label = %ContinueInfo
@onready var toast: Label = %Toast
@onready var customize_layer: Control = %CustomizeLayer
@onready var settings_layer: Control = %SettingsLayer
@onready var hero: Node2D = %Hero
@onready var hero_sprite: Sprite2D = %Hero/Sprite
@onready var plume: GPUParticles2D = %Hero/Plume
@onready var engine_glow: Sprite2D = %Hero/EngineGlow
@onready var paint_row: HBoxContainer = %PaintRow
@onready var energy_row: HBoxContainer = %EnergyRow
@onready var paint_name: Label = %PaintName
@onready var energy_name: Label = %EnergyName
@onready var volume_slider: HSlider = %Volume
@onready var volume_value: Label = %VolumeValue
@onready var shake_toggle: CheckButton = %Shake
@onready var fade: ColorRect = %Fade
var level_layer: Control

var _t := 0.0
var _leaving := false
var _has_save := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and not args.has("--title"):
		get_tree().change_scene_to_file.call_deferred(MAIN)
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameState.world = null
	if Engine.get_write_movie_path() != "":
		get_window().unfocusable = true  # preview recordings: ignore stray real input
		get_window().mouse_passthrough = true
	_build_hotspots()
	_build_level_select()
	_refresh_continue()
	_build_swatches()
	_apply_customization()
	%CustomizeBack.pressed.connect(_close_overlays)
	%SettingsBack.pressed.connect(_close_overlays)
	volume_slider.value = GameState.volume * 100.0
	shake_toggle.button_pressed = GameState.screen_shake
	_update_volume_label()
	volume_slider.value_changed.connect(_on_volume_changed)
	shake_toggle.toggled.connect(_on_shake_toggled)
	customize_layer.visible = false
	settings_layer.visible = false
	toast.modulate.a = 0.0
	video.finished.connect(video.play)  # belt-and-braces looping
	# Fade in from black.
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)
	if args.has("--title-customize"):
		_open(customize_layer)
	if args.has("--title-settings"):
		_open(settings_layer)
	if args.has("--title-levels"):
		_open(level_layer)
	for arg in args:  # test hook: --title-pick=4 picks a level from Level Select after the intro
		if arg.begins_with("--title-pick="):
			var pick := int(arg.get_slice("=", 1))
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				GameState.start_level_select(pick)
				_start_game())
	for arg in args:  # preview hook: --title-hover=settings shows that button's hover glow
		if arg.begins_with("--title-hover="):
			var b := hotspots.get_node_or_null(arg.get_slice("=", 1)) as Button
			if b:
				b.add_theme_stylebox_override("normal", _glow_box(0.0, 0.85))
	if args.has("--title-start"):  # test hook: press "play" after the intro (never touches the save)
		get_tree().create_timer(2.0).timeout.connect(_start_game)


func _process(delta: float) -> void:
	_t += delta
	if customize_layer.visible:
		hero_sprite.frame = int(_t * HERO_FPS) % HERO_FRAMES
		hero.position = HERO_HOME + Vector2(sin(_t * 0.9) * 10.0, sin(_t * 1.6) * 14.0)
		hero.rotation = sin(_t * 0.8) * 0.035
		engine_glow.scale = Vector2.ONE * (2.4 + sin(_t * 30.0) * 0.15)


# --- painted-button hotspots ---------------------------------------------------------------------

func _build_hotspots() -> void:
	for id in HOTSPOTS:
		var r: Rect2 = HOTSPOTS[id]
		var b := Button.new()
		b.name = String(id)
		b.position = r.position
		b.size = r.size
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", _glow_box(0.0, 0.85))
		b.add_theme_stylebox_override("pressed", _glow_box(0.25, 1.0))
		b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		b.pressed.connect(_on_hotspot.bind(id))
		hotspots.add_child(b)


## Cyan outline + glow drawn over a painted button on hover / press.
func _glow_box(fill: float, edge: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.75, 1.0, fill)
	sb.border_color = Color(0.55, 0.9, 1.0, edge)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0.3, 0.75, 1.0, 0.55 * edge)
	sb.shadow_size = 12
	return sb


func _on_hotspot(id: StringName) -> void:
	if _leaving or customize_layer.visible or settings_layer.visible or level_layer.visible:
		return
	match id:
		&"new_game":
			GameState.carry_over = false
			GameState.delete_save()
			_start_game()
		&"continue":
			if _has_save and GameState.load_progress():
				_start_game()
			else:
				_show_toast("No saved game yet - start a New Game!")
		&"customize":
			_open(customize_layer)
		&"settings":
			_open(settings_layer)
		&"level_select":
			_open(level_layer)
		&"exit":
			if OS.has_feature("web"):
				_show_toast("Close this browser tab to exit.")
			else:
				get_tree().quit()


func _refresh_continue() -> void:
	_has_save = GameState.has_save()
	continue_dim.visible = not _has_save
	continue_info.text = ""
	if _has_save:
		var f := FileAccess.open(GameState.save_path, FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f else null
		if data is Dictionary and data.has("stage"):
			var stage := clampi(int(data.stage), 1, GameState.FINAL_STAGE)
			continue_info.text = "Level %d · %s · Pilot LV %d" % [stage, GameState.STAGES[stage].title, int(data.get("level", 1))]


func _show_toast(text: String) -> void:
	toast.text = text
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func _start_game() -> void:
	_leaving = true
	Sfx.play(&"dash", -4.0, 0.0)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MAIN))


func _open(layer: Control) -> void:
	Sfx.play(&"select", -6.0, 0.0)
	layer.visible = true
	layer.modulate.a = 0.0
	create_tween().tween_property(layer, "modulate:a", 1.0, 0.2)
	hotspots.visible = false


func _close_overlays() -> void:
	Sfx.play(&"select", -6.0, 0.0)
	customize_layer.visible = false
	settings_layer.visible = false
	level_layer.visible = false
	hotspots.visible = true


# --- settings ------------------------------------------------------------------------------------

func _on_volume_changed(value: float) -> void:
	GameState.volume = value / 100.0
	GameState.apply_volume()
	GameState.save_settings()
	_update_volume_label()


func _update_volume_label() -> void:
	volume_value.text = "%d%%" % roundi(GameState.volume * 100.0)


func _on_shake_toggled(on: bool) -> void:
	GameState.screen_shake = on
	GameState.save_settings()
	Sfx.play(&"select", -6.0, 0.0)


# --- customization -------------------------------------------------------------------------------

func _build_swatches() -> void:
	for id in GameState.PAINTS:
		paint_row.add_child(_swatch(GameState.PAINTS[id].swatch, id, true))
	for id in GameState.ENERGIES:
		energy_row.add_child(_swatch(GameState.ENERGIES[id].mid, id, false))
	_refresh_swatches()


func _swatch(color: Color, id: StringName, is_paint: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(88, 88)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("id", id)
	b.set_meta("color", color)
	b.set_meta("paint", is_paint)
	b.pressed.connect(func() -> void:
		if is_paint:
			GameState.paint = id
		else:
			GameState.energy = id
		GameState.save_settings()
		Sfx.play(&"select", -6.0, 0.0)
		_refresh_swatches()
		_apply_customization())
	return b


func _refresh_swatches() -> void:
	for row in [paint_row, energy_row]:
		for b: Button in row.get_children():
			var selected: bool = b.get_meta("id") == (GameState.paint if b.get_meta("paint") else GameState.energy)
			var color: Color = b.get_meta("color")
			for state in ["normal", "hover", "pressed"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = color if state != "hover" else color.lightened(0.15)
				sb.set_corner_radius_all(44)
				sb.set_border_width_all(6 if selected else 2)
				sb.border_color = Color(1, 1, 1) if selected else Color(0.3, 0.45, 0.7, 0.8)
				sb.shadow_color = Color(color, 0.6) if selected else Color(0, 0, 0, 0)
				sb.shadow_size = 10 if selected else 0
				b.add_theme_stylebox_override(state, sb)
	paint_name.text = GameState.PAINTS[GameState.paint].name
	energy_name.text = GameState.ENERGIES[GameState.energy].name


## Paint the preview Gundam and tint its engines with the current choices.
func _apply_customization() -> void:
	GameState.apply_paint(hero_sprite.material as ShaderMaterial)
	var e := GameState.energy_colors()
	engine_glow.modulate = Color(e.mid, 0.9)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([e.core, Color(e.mid, 0.85), Color(e.mid.darkened(0.3), 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	(plume.process_material as ParticleProcessMaterial).color_ramp = tex


# --- level select --------------------------------------------------------------------------------

## Adds the LEVEL SELECT button (drawn to match the painted menu buttons) and its overlay panel.
func _build_level_select() -> void:
	var b := Button.new()
	b.name = "level_select"
	b.position = LEVEL_SELECT_RECT.position
	b.size = LEVEL_SELECT_RECT.size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.text = "Level Select"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var font := SystemFont.new()  # lighter weight, like the painted labels
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial", "sans-serif"])
	font.font_weight = 500
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.8, 0.87, 0.97))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.02, 0.05, 0.12, 0.72)
	base.border_color = Color(0.35, 0.65, 1.0, 0.75)
	base.set_border_width_all(2)
	_chamfer(base)
	base.content_margin_left = 40
	b.add_theme_stylebox_override("normal", base)
	for state in ["hover", "pressed"]:
		var glow := _glow_box(0.12 if state == "hover" else 0.28, 1.0)
		_chamfer(glow)
		glow.content_margin_left = 40
		b.add_theme_stylebox_override(state, glow)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 24)
	chevron.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	chevron.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	chevron.offset_left = -34
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(chevron)
	b.pressed.connect(_on_hotspot.bind(&"level_select"))
	hotspots.add_child(b)

	# Overlay panel: one card per level.
	level_layer = Control.new()
	level_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_layer.visible = false
	add_child(level_layer)
	move_child(level_layer, fade.get_index())  # under the fade
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.07, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 170)
	panel.size = Vector2(640, 0)
	level_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var header := Label.new()
	header.text = "LEVEL SELECT"
	header.add_theme_font_size_override("font_size", 44)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	var note := Label.new()
	note.text = "Jump into any level with the pilot level and upgrades you'd normally have by then."
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	for stage in range(1, GameState.FINAL_STAGE + 1):
		box.add_child(_level_card(stage))
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(0, 70)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_overlays)
	box.add_child(back)


func _level_card(stage: int) -> Button:
	var info: Dictionary = GameState.STAGES[stage]
	var accent: Color = LEVEL_COLORS.get(stage, Color(0.5, 0.8, 1.0))
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 108)
	card.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.06, 0.13, 0.95) if state == "normal" else Color(accent.darkened(0.7), 0.95)
		sb.border_color = Color(accent, 0.9 if state != "normal" else 0.6)
		sb.set_border_width_all(2)
		sb.border_width_left = 10
		sb.set_corner_radius_all(10)
		sb.shadow_color = Color(accent, 0.45) if state != "normal" else Color(0, 0, 0, 0)
		sb.shadow_size = 10
		card.add_theme_stylebox_override(state, sb)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_top = 10
	col.offset_right = -16
	col.offset_bottom = -10
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var title := Label.new()
	title.text = "LEVEL %d  ·  %s" % [stage, info.title]
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", accent.lightened(0.35))
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Boss: %s\nStarts at Pilot LV %d" % [info.boss.capitalize(), GameState.LEVEL_SELECT_PILOT.get(stage, 1)]
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.78, 0.84, 0.95))
	col.add_child(sub)
	for l in [title, sub]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pressed.connect(func() -> void:
		if _leaving:
			return
		GameState.start_level_select(stage)
		_start_game())
	return card


## Cut (chamfered) top-left and bottom-right corners, like the painted menu buttons.
func _chamfer(sb: StyleBoxFlat) -> void:
	sb.corner_detail = 1
	sb.corner_radius_top_left = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
