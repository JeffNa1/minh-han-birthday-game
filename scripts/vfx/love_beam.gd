extends "res://scripts/art/soft_draw.gd"
## Glowing eye-to-eye ribbon with travelling tokens (hearts, petals, stars, bubbles or notes).
## Drawn in world space above the characters; Minh Hân's style comes from Catalog.BEAMS.

const Catalog := preload("res://scripts/data/catalog.gd")

var start_point: Vector2 = Vector2.ZERO
var target_point: Vector2 = Vector2.ZERO
var is_active: bool = false
var rival: bool = false
var rival_color: Color = Color("a96bff")
## Optional live anchors so the ribbon sticks to moving eyes between physics ticks.
var from_marker: Node2D = null
var to_marker: Node2D = null
var style: Dictionary = Catalog.BEAMS["heart"]
var _t: float = 0.0
var _grow: float = 0.0

func _ready() -> void:
	top_level = true
	z_index = 30
	visible = false

func set_style(beam_id: String) -> void:
	style = Catalog.BEAMS.get(beam_id, Catalog.BEAMS["heart"])

func activate(from_pos: Vector2, to_pos: Vector2) -> void:
	if not is_active:
		_grow = 0.0
	start_point = from_pos
	target_point = to_pos
	is_active = true
	visible = true

func deactivate() -> void:
	is_active = false
	visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
	_t += delta
	_grow = minf(1.0, _grow + delta * 7.0)
	if is_instance_valid(from_marker):
		start_point = from_marker.global_position
	if is_instance_valid(to_marker):
		target_point = to_marker.global_position
	queue_redraw()

func _main(k: float) -> Color:
	if rival:
		return rival_color
	if style.get("rainbow", false):
		return Color.from_hsv(fmod(_t * 0.4 + k, 1.0), 0.55, 1.0)
	return style["main"]

func _path() -> PackedVector2Array:
	var out := PackedVector2Array()
	var dist := start_point.distance_to(target_point)
	var normal := (target_point - start_point).orthogonal().normalized()
	var lift := Vector2(0, -minf(40.0, dist * 0.12))
	var count := 28
	var reach := 1.0 - pow(1.0 - _grow, 3.0)
	for i in range(count + 1):
		var t := float(i) / count * reach
		var base := start_point.lerp(target_point, t) + lift * sin(t * PI)
		var wob := sin(_t * 14.0 - t * 12.0) * 4.0 * sin(t * PI)
		out.append(base + normal * wob)
	return out

func _token(at: Vector2, size: float, col: Color, spin: float) -> void:
	match ("heart" if rival else style["shape"]):
		"heart":
			heart(at, size, Color("fff6f9"), 0.0, spin)
			heart(at, size * 0.7, col, 0.0, spin)
		"star":
			sparkle(at, size * 1.3, Color("fffbe8"), spin * 3.0)
			sparkle(at, size * 0.9, col, spin * 3.0 + 0.4)
		"petal":
			draw_set_transform(at, spin * 3.0, Vector2(1.0, 0.6))
			draw_colored_polygon(ellipse_pts(Vector2.ZERO, Vector2(size, size * 0.7), 14), col)
			draw_colored_polygon(ellipse_pts(Vector2(-size * 0.2, -size * 0.15), Vector2(size * 0.45, size * 0.3), 10), Color(1, 1, 1, 0.7))
			draw_set_transform(Vector2.ZERO)
		"bubble":
			draw_circle(at, size, Color(col, 0.25), true, -1.0, true)
			draw_arc(at, size, 0.0, TAU, 20, Color(col, 0.9), 1.6, true)
			draw_circle(at + Vector2(-size * 0.35, -size * 0.35), size * 0.25, Color(1, 1, 1, 0.9), true, -1.0, true)
		"note":
			draw_circle(at, size * 0.55, col, true, -1.0, true)
			draw_line(at + Vector2(size * 0.5, 0), at + Vector2(size * 0.5, -size * 1.6), col, 2.0, true)
			draw_line(at + Vector2(size * 0.5, -size * 1.6), at + Vector2(size * 1.2, -size * 1.1), col, 2.0, true)

func _draw() -> void:
	if not is_active or start_point.distance_to(target_point) < 2.0:
		return
	var main := _main(0.0)
	var soft: Color = rival_color.lightened(0.6) if rival else style["soft"]
	var path := _path()
	var pulse := 1.0 + sin(_t * 22.0) * 0.12
	var glow := PackedColorArray()
	var core := PackedColorArray()
	for i in range(path.size()):
		var c := _main(float(i) / path.size())
		glow.append(Color(c, 0.22))
		core.append(Color(c, 0.8))
	draw_polyline(path, Color(main, 0.10), 26.0 * pulse, true)
	draw_polyline_colors(path, glow, 15.0 * pulse, true)
	draw_polyline_colors(path, core, 7.0, true)
	draw_polyline(path, Color(soft, 1.0), 3.0, true)
	var end: Vector2 = path[path.size() - 1]
	if _grow < 1.0:
		return
	# Tokens ride the ribbon toward the target.
	for i in range(6):
		var k := fmod(float(i) / 6.0 + _t * 1.3, 1.0)
		var idx := int(k * (path.size() - 1))
		_token(path[idx], 4.5 + sin(k * PI) * 4.0, _main(k), sin(_t * 6.0 + i) * 0.4)
	for i in range(3):
		var k := fmod(float(i) / 3.0 + _t * 0.9, 1.0)
		sparkle(path[int(k * (path.size() - 1))] + Vector2(0, -10 - 6 * sin(_t * 5.0 + i)), 4.0 * sin(k * PI), soft, _t * 4.0)
	# Impact bloom.
	for i in range(3):
		var k := fmod(_t * 2.0 + i / 3.0, 1.0)
		draw_arc(end, 6.0 + k * 22.0, 0.0, TAU, 32, Color(_main(k), 0.5 * (1.0 - k)), 2.0, true)
	draw_circle(end, 7.0 * pulse, Color(soft, 0.9), true, -1.0, true)
	sparkle(start_point, 7.0 * pulse, Color(1, 1, 1, 0.95), _t * 3.0)
