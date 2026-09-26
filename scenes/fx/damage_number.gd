extends Label
## Floating "-52" style damage number. Main.spawn_damage_number() sets it up.

func setup(amount: float, crit: bool, player_hit: bool, big := false) -> void:
	text = "-%d" % roundi(amount)
	var settings: LabelSettings = label_settings.duplicate()
	if big:
		# Beam Rifle hits: large white numbers with a heavy blue outline.
		settings.font_color = Color(1, 1, 1)
		settings.outline_color = Color(0.05, 0.2, 0.55)
		settings.outline_size = 10
		settings.font_size = 52
		crit = true  # bigger pop-in
	elif player_hit:
		settings.font_color = Color(1, 0.25, 0.2)
		settings.font_size = 34
	elif crit:
		settings.font_color = Color(1, 0.85, 0.2)
		settings.font_size = 38
		text += "!"
	label_settings = settings
	pivot_offset = size / 2
	scale = Vector2.ONE * (1.5 if crit else 1.15)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - 46.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "position:x", position.x + randf_range(-16.0, 16.0), 0.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(queue_free)
