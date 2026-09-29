extends "res://scripts/art/soft_draw.gd"
## Screen-space atmosphere that rides with the camera: petals outside, dust motes in the hallway,
## fireflies on the rooftop.

@export_enum("courtyard", "hallway", "rooftop") var style: String = "courtyard"

var _t: float = 0.0
var _bits: Array = []

func _ready() -> void:
	z_index = -15
	var count: int = {"courtyard": 34, "hallway": 22, "rooftop": 26}[style]
	for i in range(count):
		_bits.append({"p": Vector2(randf_range(0, 960), randf_range(-40, 540)), "v": randf_range(22, 48), "a": randf() * TAU, "s": randf_range(2.6, 4.6), "w": randf_range(0.8, 2.2)})

func _process(delta: float) -> void:
	_t += delta
	global_position = get_viewport().get_canvas_transform().affine_inverse() * Vector2.ZERO
	for b: Dictionary in _bits:
		match style:
			"courtyard":
				b["p"] += Vector2(sin(_t * b["w"] + b["a"]) * 18.0 + 14.0, b["v"]) * delta
				if b["p"].y > 550 or b["p"].x > 980:
					b["p"] = Vector2(randf_range(-60, 900), -20)
			"hallway":
				b["p"] += Vector2(sin(_t * 0.4 + b["a"]) * 6.0, -4.0 - b["w"] * 2.0) * delta
				if b["p"].y < 40:
					b["p"] = Vector2(randf_range(0, 960), randf_range(300, 520))
			"rooftop":
				b["p"] += Vector2(cos(_t * b["w"] + b["a"]), sin(_t * b["w"] * 1.3 + b["a"])) * 16.0 * delta
				b["p"].x = fposmod(b["p"].x, 960.0)
				b["p"].y = clampf(b["p"].y, 150.0, 520.0)
		b["a"] += delta * b["w"]
	queue_redraw()

func _draw() -> void:
	for b: Dictionary in _bits:
		var s: float = b["s"]
		match style:
			"courtyard":
				draw_set_transform(b["p"], b["a"], Vector2(1.0, 0.55 + 0.45 * sin(b["a"] * 2.0)))
				draw_colored_polygon(ellipse_pts(Vector2.ZERO, Vector2(s, s * 0.62), 12), Color(1.0, 0.78, 0.86, 0.9))
				draw_set_transform(Vector2.ZERO)
			"hallway":
				var tw := 0.35 + 0.35 * sin(_t * 2.0 + b["a"] * 3.0)
				draw_circle(b["p"], s * 0.5, Color(1.0, 0.95, 0.8, tw), true, -1.0, true)
			"rooftop":
				var glow := 0.5 + 0.5 * sin(_t * 3.0 + b["a"] * 5.0)
				draw_circle(b["p"], 7.0, Color(1.0, 0.9, 0.5, 0.15 * glow), true, -1.0, true)
				draw_circle(b["p"], 2.0, Color(1.0, 0.95, 0.7, 0.5 + 0.5 * glow), true, -1.0, true)
