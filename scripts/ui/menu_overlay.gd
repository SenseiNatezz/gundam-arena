extends CanvasLayer
## Generic modal used for the pause menu and the victory / game-over screens.

signal primary_pressed
signal secondary_pressed
signal tertiary_pressed

@onready var title: Label = %Title
@onready var body: Label = %Body
@onready var primary: Button = %Primary
@onready var secondary: Button = %Secondary
@onready var tertiary: Button = %Tertiary
@onready var panel: Control = %Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	primary.pressed.connect(func() -> void:
		Sfx.play(&"select", -6.0, 0.0)
		primary_pressed.emit())
	secondary.pressed.connect(func() -> void:
		Sfx.play(&"select", -6.0, 0.0)
		secondary_pressed.emit())
	tertiary.pressed.connect(func() -> void:
		Sfx.play(&"select", -6.0, 0.0)
		tertiary_pressed.emit())


func open(title_text: String, body_text: String, title_color: Color, primary_text: String, secondary_text := "", tertiary_text := "") -> void:
	title.text = title_text
	title.add_theme_color_override("font_color", title_color)
	body.text = body_text
	body.visible = body_text != ""
	primary.text = primary_text
	secondary.text = secondary_text
	secondary.visible = secondary_text != ""
	tertiary.text = tertiary_text
	tertiary.visible = tertiary_text != ""
	visible = true
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)


func close() -> void:
	visible = false
