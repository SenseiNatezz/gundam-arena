extends Node2D
## Volcanic Forge floor hazard: a deck tile glows with a pulsing outline for WARN_TIME seconds,
## then erupts in a column of fire, damaging the player if they're still standing on it.

const WARN_TIME := 1.0
const ERUPT_TIME := 0.45
const DAMAGE := 16.0

var tile := Rect2()
var _t := 0.0
var _hit := false


func _ready() -> void:
	z_index = -4  # on the floor, under enemies and the player


func _process(delta: float) -> void:
	_t += delta
	if _t >= WARN_TIME and not _hit:
		_hit = true
		_erupt()
	if _t >= WARN_TIME + ERUPT_TIME:
		queue_free()
		return
	queue_redraw()


func _erupt() -> void:
	var p := GameState.player as Player
	if p and not p.dead and tile.grow(10.0).has_point(p.global_position):
		p.take_damage(DAMAGE, tile.get_center(), true)
	GameState.world.spawn_explosion(tile.get_center(), 1.0)
	GameState.world.shake(0.18)
	Sfx.play(&"slam", -10.0, 0.25)


func _draw() -> void:
	var inner := tile.grow(-4.0)
	if _t < WARN_TIME:
		var k := _t / WARN_TIME
		var blink := 0.5 + 0.5 * absf(sin(_t * (8.0 + k * 22.0)))
		draw_rect(inner, Color(1, 0.3, 0.05, 0.08 + 0.22 * k))
		draw_rect(inner, Color(1, 0.55, 0.1, 0.55 + 0.45 * blink), false, 4.0)
		draw_rect(inner.grow(-10.0), Color(1, 0.8, 0.35, 0.35 * blink * k), false, 2.0)
	else:
		var k := (_t - WARN_TIME) / ERUPT_TIME
		var fade := 1.0 - k
		draw_rect(inner, Color(1, 0.35, 0.05, 0.75 * fade))
		draw_rect(inner.grow(-12.0 - 20.0 * k), Color(1, 0.85, 0.45, 0.85 * fade))
		# Flame tongues licking out of the tile.
		for i in 5:
			var x := inner.position.x + inner.size.x * (0.15 + i * 0.175)
			var h := (30.0 + 25.0 * sin(i * 2.1 + _t * 30.0)) * fade
			draw_colored_polygon(PackedVector2Array([Vector2(x - 10, inner.position.y + 6), Vector2(x, inner.position.y - h), Vector2(x + 10, inner.position.y + 6)]), Color(1, 0.55, 0.1, 0.85 * fade))
