extends Node2D
## Mortar shell lobbed by a crawler: arcs from `from` to `to` over FLIGHT seconds while a red
## target circle warns where it will land, then blasts that area.

const FLIGHT := 1.3
const RADIUS := 72.0
const DAMAGE := 18.0

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	z_index = 2
	to = to.clamp(Vector2(70, 200), Vector2(650, 1220))


func _process(delta: float) -> void:
	_t += delta
	if _t >= FLIGHT:
		GameState.world.area_blast(to, RADIUS, DAMAGE, 0.0, 1.1)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / FLIGHT
	# Target circle: fills up as the shell comes down.
	var blink := 0.55 + 0.45 * absf(sin(_t * 16.0))
	draw_circle(to, RADIUS, Color(1, 0.1, 0.05, 0.12))
	draw_circle(to, RADIUS * k, Color(1, 0.2, 0.05, 0.22))
	draw_arc(to, RADIUS, 0.0, TAU, 40, Color(1, 0.3, 0.15, 0.85 * blink), 3.0, true)
	# Shell on a parabolic arc (height shown by size and a ground shadow).
	var pos := from.lerp(to, k)
	var height := sin(k * PI) * 220.0
	draw_circle(pos, 9.0 * (1.0 - k * 0.3), Color(0, 0, 0, 0.35))
	var shell := pos - Vector2(0, height)
	var size := 9.0 + sin(k * PI) * 7.0
	draw_circle(shell, size + 3.0, Color(0.1, 0.1, 0.1))
	draw_circle(shell, size, Color(1, 0.55, 0.15))
	draw_circle(shell - Vector2(size * 0.3, size * 0.3), size * 0.35, Color(1, 0.9, 0.6))
