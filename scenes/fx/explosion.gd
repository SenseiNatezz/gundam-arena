extends Node2D
## One-shot explosion: flash + shockwave ring + fire, spark and smoke particles. Frees itself.

@export var size := 1.0


func _ready() -> void:
	scale = Vector2.ONE * size
	rotation = randf() * TAU
	for p: GPUParticles2D in [$Fire, $Sparks, $Smoke]:
		p.restart()
		p.emitting = true
	var flash: Sprite2D = $Flash
	var shock: Sprite2D = $Shock
	var tw := create_tween().set_parallel()
	tw.tween_property(flash, "scale", flash.scale * 3.2, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.tween_property(shock, "scale", shock.scale * 4.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(shock, "modulate:a", 0.0, 0.35)
	get_tree().create_timer(1.4, false).timeout.connect(queue_free)
