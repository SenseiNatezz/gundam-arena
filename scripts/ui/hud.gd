extends CanvasLayer
## Heads-up display: HP/XP (top-left), wave + enemy count (top-center), pause (top-right),
## boss HP bar, wave banners, and the touch joystick / dash button.

signal pause_pressed

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_text: Label = %HPText
@onready var xp_bar: ProgressBar = %XPBar
@onready var level_text: Label = %LevelText
@onready var wave_text: Label = %WaveText
@onready var enemy_text: Label = %EnemyText
@onready var boss_bar_box: Control = %BossBar
@onready var boss_bar: ProgressBar = %BossHP
@onready var banner: Label = %Banner
@onready var banner_sub: Label = %BannerSub

var _banner_tween: Tween
var _cutin_tween: Tween
var _hits_tween: Tween

@onready var cutin: Control = %Cutin
@onready var hit_counter: Label = %HitCounter


func _ready() -> void:
	%PauseButton.pressed.connect(pause_pressed.emit)
	_style_bar(xp_bar, Color(0.3, 0.75, 1.0))
	_style_bar(boss_bar, Color(1.0, 0.2, 0.15))
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.wave_changed.connect(_on_wave_changed)
	GameState.enemies_changed.connect(_on_enemies_changed)
	GameState.boss_changed.connect(_on_boss_changed)
	_on_xp_changed(GameState.xp, GameState.xp_needed, GameState.level)
	_on_wave_changed(maxi(GameState.wave, 1), GameState.TOTAL_WAVES)
	_on_enemies_changed(GameState.enemies_remaining)
	boss_bar_box.visible = false
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	hit_counter.modulate.a = 0.0


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := (bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)


func _on_hp_changed(hp: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	create_tween().tween_property(hp_bar, "value", hp, 0.15)
	hp_text.text = "%d / %d" % [ceili(hp), roundi(max_hp)]
	var frac := hp / max_hp
	var color := Color(0.3, 0.9, 0.35) if frac > 0.5 else (Color(1.0, 0.75, 0.2) if frac > 0.25 else Color(1.0, 0.25, 0.2))
	_style_bar(hp_bar, color)


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = xp
	level_text.text = "LV %d" % level


func _on_wave_changed(wave: int, total: int) -> void:
	wave_text.text = "%s · WAVE %d/%d" % [GameState.stage_info().sector, wave, total]


func _on_enemies_changed(remaining: int) -> void:
	enemy_text.text = "Enemies %d" % maxi(remaining, 0)


func _on_boss_changed(hp: float, max_hp: float) -> void:
	(boss_bar_box.get_node("BossName") as Label).text = GameState.stage_info().boss
	boss_bar_box.visible = hp > 0.0
	boss_bar.max_value = max_hp
	boss_bar.value = hp


## Special-move cut-in: a slanted band whips in from the right, holds, and leaves to the left.
## Runs on real time so it plays at full speed during the cannon's slow-motion charge.
func show_cutin(title: String) -> void:
	cutin.get_node("Text").text = title
	cutin.visible = true
	cutin.rotation = deg_to_rad(-6.0)
	cutin.pivot_offset = cutin.size / 2
	var text: Label = cutin.get_node("Text")
	cutin.position.x = cutin.size.x
	text.position.x = 120.0
	if _cutin_tween:
		_cutin_tween.kill()
	_cutin_tween = create_tween().set_ignore_time_scale()
	_cutin_tween.tween_property(cutin, "position:x", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cutin_tween.parallel().tween_property(text, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_cutin_tween.tween_interval(0.35)
	_cutin_tween.tween_property(cutin, "position:x", -cutin.size.x, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_cutin_tween.tween_callback(func() -> void: cutin.visible = false)


## Fighting-game style "37 HIT" counter; pops on every update and fades out after the combo ends.
func show_hit_counter(hits: int) -> void:
	hit_counter.text = "%d HIT" % hits
	hit_counter.modulate.a = 1.0
	hit_counter.pivot_offset = Vector2(0, hit_counter.size.y / 2)
	hit_counter.scale = Vector2.ONE * 1.25
	if _hits_tween:
		_hits_tween.kill()
	_hits_tween = create_tween()
	_hits_tween.tween_property(hit_counter, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hits_tween.tween_interval(1.0)
	_hits_tween.tween_property(hit_counter, "modulate:a", 0.0, 0.4)


func show_banner(title: String, subtitle := "", color := Color.WHITE, hold := 1.4) -> void:
	banner.text = title
	banner_sub.text = subtitle
	banner.modulate = Color(color, 0.0)
	banner_sub.modulate = Color(1, 1, 1, 0.0)
	banner.scale = Vector2(1.4, 1.4)
	banner.pivot_offset = banner.size / 2
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.3).set_delay(0.15)
	_banner_tween.chain().tween_interval(hold)
	_banner_tween.chain().set_parallel()
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.35)
	_banner_tween.tween_property(banner_sub, "modulate:a", 0.0, 0.35)
