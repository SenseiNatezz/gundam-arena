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
	if _leaving or customize_layer.visible or settings_layer.visible:
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
