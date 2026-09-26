extends Node2D
## World-space drawing for the Cryo Titan: spike-line warnings and the ice spikes that erupt along
## them, plus falling icicles with growing shadows. The Titan drives the state; this only draws.

var spike_origin := Vector2.ZERO
var spike_reach := 0.0
var icicles: Array[Dictionary] = []

var _spike_dirs: Array[Vector2] = []
var _spike_length := 0.0
var _spike_spacing := 48.0
var _hail_fall := 1.0
var _hail_radius := 58.0
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 1


func start_spikes(origin: Vector2, dirs: Array[Vector2], length: float, spacing: float) -> void:
	spike_origin = origin
	_spike_dirs = dirs
	_spike_length = length
	_spike_spacing = spacing
	spike_reach = 0.0


func stop_spikes() -> void:
	_spike_dirs.clear()
	spike_reach = 0.0


## Positions of the spikes that have erupted so far (up to `reach` from the origin).
func spike_points(reach: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for dir in _spike_dirs:
		var d := 70.0
		while d <= minf(reach, _spike_length):
			out.append(spike_origin + dir * d)
			d += _spike_spacing
	return out


func spike_tips() -> Array[Vector2]:
	return spike_points(spike_reach)


func start_hail(spots: Array[Vector2], fall: float, radius: float) -> void:
	_hail_fall = fall
	_hail_radius = radius
	icicles.clear()
	for i in spots.size():
		# Stagger the drops a little so they land in a quick sequence.
		icicles.append({"pos": spots[i], "t": -i * 0.05, "landed": false})


func _process(delta: float) -> void:
	_t += delta
	for icicle in icicles:
		icicle.t += delta
	queue_redraw()


func _draw() -> void:
	# Spike lines: blinking warning lines, then crystal spikes erupting outward.
	for dir in _spike_dirs:
		var end := spike_origin + dir * _spike_length
		if spike_reach <= 0.0:
			var blink := 0.35 + 0.5 * absf(sin(_t * 16.0))
			draw_line(spike_origin, end, Color(0.55, 0.85, 1.0, 0.2), 30.0)
			draw_line(spike_origin, end, Color(0.8, 0.95, 1.0, blink), 3.0)
	for tip in spike_points(spike_reach):
		_draw_spike(tip)
	# Icicles: growing shadow + target ring, then the icicle dropping in just before impact.
	for icicle in icicles:
		if icicle.landed or icicle.t < 0.0:
			continue
		var k: float = clampf(icicle.t / _hail_fall, 0.0, 1.0)
		var pos: Vector2 = icicle.pos
		var blink := 0.6 + 0.4 * absf(sin(_t * 14.0))
		draw_circle(pos, _hail_radius, Color(0.1, 0.3, 0.6, 0.18))
		draw_circle(pos, _hail_radius * k, Color(0.03, 0.1, 0.25, 0.45))
		draw_arc(pos, _hail_radius, 0.0, TAU, 40, Color(0.05, 0.2, 0.45, 0.9), 6.0, true)
		draw_arc(pos, _hail_radius, 0.0, TAU, 40, Color(0.75, 0.95, 1.0, blink), 2.5, true)
		if k > 0.6:
			var drop := (1.0 - (k - 0.6) / 0.4) * 260.0
			_draw_icicle(pos - Vector2(0, drop))


func _draw_spike(at: Vector2) -> void:
	for i in 3:
		var a := -PI / 2 + (i - 1) * 0.55
		var base := at + Vector2.from_angle(a + PI / 2) * 6.0 * (i - 1)
		var tip := at + Vector2.from_angle(a) * (26.0 - absf(i - 1) * 7.0)
		var side := Vector2.from_angle(a).orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([base - side * 1.2, tip, base + side * 1.2]), Color(0.15, 0.35, 0.6))
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(0.65, 0.9, 1.0))
		draw_colored_polygon(PackedVector2Array([base - side, tip, base]), Color(0.92, 0.98, 1.0))


func _draw_icicle(at: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-9, -34), at + Vector2(9, -34), at + Vector2(0, 6)]), Color(0.15, 0.35, 0.6))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -32), at + Vector2(7, -32), at + Vector2(0, 3)]), Color(0.7, 0.92, 1.0))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -32), at + Vector2(0, -32), at + Vector2(0, 3)]), Color(0.95, 0.99, 1.0))
