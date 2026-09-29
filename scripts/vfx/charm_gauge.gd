extends "res://scripts/art/soft_draw.gd"
## Heart above a boy's head that fills as the love beam works on him.

var value: float = 0.0
var tier: int = 1
var _shown: float = 0.0
var _alpha: float = 0.0
var _kick: float = 0.0
var _t: float = 0.0

func set_value(v: float) -> void:
	if v > value + 0.01:
		_kick = minf(_kick + 0.05, 0.25)
	value = v

func _process(delta: float) -> void:
	_t += delta
	var goal := 1.0 if value > 0.5 else 0.0
	_alpha = move_toward(_alpha, goal, delta * 5.0)
	_shown = lerpf(_shown, value, 1.0 - exp(-14.0 * delta))
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-10.0 * delta))
	visible = _alpha > 0.0
	queue_redraw()

func _draw() -> void:
	var fill: Color = [Color("ff5f8f"), Color("b77dff"), Color("ffb938")][clampi(tier - 1, 0, 2)]
	var s := (0.6 + 0.4 * _alpha) * (1.0 + _kick + sin(_t * 8.0) * 0.03 * _shown / 100.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * s)
	var shape := heart_pts(Vector2(0, -1), 13.0)
	draw_colored_polygon(heart_pts(Vector2(0, 0), 15.5), Color(1, 1, 1, 0.92 * _alpha))
	draw_colored_polygon(shape, Color(fill.lightened(0.7), _alpha))
	var level := lerpf(15.0, -12.0, _shown / 100.0)
	var rect := pts([-20, level, 20, level, 20, 20, -20, 20])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, rect):
		draw_colored_polygon(piece, Color(fill, _alpha))
	var closed := shape.duplicate()
	closed.append(shape[0])
	draw_polyline(closed, Color(ink(fill), _alpha), 1.6, true)
	draw_circle(Vector2(-5, -5), 2.2, Color(1, 1, 1, 0.8 * _alpha), true, -1.0, true)
	if tier == 3:
		sparkle(Vector2(12, -12), 5.0, Color(1.0, 0.93, 0.5, _alpha), _t * 3.0)
