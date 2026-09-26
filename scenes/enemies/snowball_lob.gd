extends Node2D
## Big snowball lobbed by a snow walker: arcs from `from` to `to` over FLIGHT seconds while a blue
## landing circle warns where it will hit, then bursts in a chilling splash.

const FLIGHT := 1.25
const RADIUS := 78.0
const DAMAGE := 14.0
const CHILL := 2.0

var from := Vector2.ZERO
var to := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	z_index = 2
	to = to.clamp(Vector2(140, 215), Vector2(580, 1055))


func _process(delta: float) -> void:
	_t += delta
	if _t >= FLIGHT:
		GameState.world.frost_blast(to, RADIUS, DAMAGE, CHILL, 0.0, 1.2)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / FLIGHT
	var blink := 0.55 + 0.45 * absf(sin(_t * 14.0))
	draw_circle(to, RADIUS, Color(0.4, 0.75, 1.0, 0.12))
	draw_circle(to, RADIUS * k, Color(0.55, 0.85, 1.0, 0.22))
	draw_arc(to, RADIUS, 0.0, TAU, 40, Color(0.7, 0.92, 1.0, 0.9 * blink), 3.0, true)
	var pos := from.lerp(to, k)
	var height := sin(k * PI) * 230.0
	draw_circle(pos, 12.0 * (1.0 - k * 0.3), Color(0.05, 0.1, 0.2, 0.3))
	var ball := pos - Vector2(0, height)
	var size := 12.0 + sin(k * PI) * 8.0
	draw_circle(ball, size + 2.5, Color(0.55, 0.7, 0.85))
	draw_circle(ball, size, Color(0.96, 0.98, 1.0))
	draw_circle(ball - Vector2(size * 0.3, size * 0.3), size * 0.35, Color(1, 1, 1))
