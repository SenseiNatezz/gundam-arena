extends CanvasLayer
## "CHOOSE UPGRADE" overlay. Shown while the tree is paused; emits `chosen` with the picked Upgrade.
## Cards can be tapped/clicked or picked with the 1/2/3 keys.

signal chosen(upgrade: Upgrade)

const UpgradeIcon := preload("res://scripts/ui/upgrade_icon.gd")
const INPUT_DELAY := 0.35

@onready var cards_box: HBoxContainer = %Cards
@onready var subtitle: Label = %Subtitle
@onready var panel: Control = %Panel

var _choices: Array[Upgrade] = []
var _opened_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(choices: Array[Upgrade]) -> void:
	_choices = choices
	_opened_at = Time.get_ticks_msec() / 1000.0
	subtitle.text = "LEVEL %d" % GameState.level
	for child in cards_box.get_children():
		child.queue_free()
	for i in choices.size():
		cards_box.add_child(_make_card(choices[i], i))
	visible = true
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size / 2
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"levelup", -4.0, 0.0)


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	var index: int = [KEY_1, KEY_2, KEY_3].find(event.physical_keycode)
	if index >= 0 and index < _choices.size():
		_pick(index)
		get_viewport().set_input_as_handled()


func _pick(index: int) -> void:
	if Time.get_ticks_msec() / 1000.0 - _opened_at < INPUT_DELAY or not visible:
		return
	Sfx.play(&"select", -6.0, 0.0)
	chosen.emit(_choices[index])


func _make_card(u: Upgrade, index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(196, 290)
	card.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var sb := (card.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.border_color = u.color if state != "normal" else Color(u.color, 0.75)
		sb.bg_color = Color(0.05, 0.08, 0.14, 0.95) if state == "normal" else Color(u.color.darkened(0.7), 0.95)
		sb.set_border_width_all(3)
		card.add_theme_stylebox_override(state, sb)
	card.pressed.connect(_pick.bind(index))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 12
	box.offset_bottom = -10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var icon := UpgradeIcon.new()
	icon.kind = u.icon
	icon.color = u.color
	icon.custom_minimum_size = Vector2(0, 104)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var title := Label.new()
	title.text = u.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", u.color.lightened(0.35))
	box.add_child(title)

	var desc := Label.new()
	desc.text = u.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	box.add_child(desc)

	var pips := Label.new()
	var owned: int = GameState.stacks.get(u.id, 0)
	pips.text = "■ ".repeat(owned + 1) + "□ ".repeat(u.max_stacks - owned - 1)
	pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pips.add_theme_font_size_override("font_size", 14)
	pips.add_theme_color_override("font_color", u.color)
	box.add_child(pips)

	var key := Label.new()
	key.text = "[%d]" % (index + 1)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 14)
	key.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	box.add_child(key)
	for label in [title, desc, pips, key]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
