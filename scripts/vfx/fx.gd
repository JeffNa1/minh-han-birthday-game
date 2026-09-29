extends "res://scripts/art/soft_draw.gd"
## One node draws every short-lived effect: heart bursts, sparkles, dust puffs, rings and pop-up text.
## Gameplay calls the static helpers; they find the active layer through the "fx" group.

const FONT := preload("res://assets/fonts/title_font.tres")

var _parts: Array = []
var _texts: Array = []
var _rings: Array = []

func _ready() -> void:
	add_to_group("fx")
	z_index = 40

static func layer() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("fx") if tree else null

static func hearts(at: Vector2, count: int = 14, color: Color = Color("ff5f8f"), power: float = 1.0) -> void:
	var fx := layer()
	if fx == null:
		return
	for i in range(count):
		var a := randf_range(-PI, 0.0)
		var sp := randf_range(90.0, 230.0) * power
		fx._parts.append({"kind": "heart", "p": at, "v": Vector2.from_angle(a) * sp, "life": randf_range(0.6, 1.1), "age": 0.0, "size": randf_range(4.0, 8.5), "rot": randf_range(-0.5, 0.5), "spin": randf_range(-3.0, 3.0), "color": color.lightened(randf_range(0.0, 0.35)), "g": 260.0})
	fx._rings.append({"p": at, "age": 0.0, "life": 0.45, "color": color, "r": 70.0 * power})

static func sparkles(at: Vector2, count: int = 8, color: Color = Color("fff1b8"), radius: float = 30.0) -> void:
	var fx := layer()
	if fx == null:
		return
	for i in range(count):
		var off := Vector2.from_angle(randf() * TAU) * randf_range(4.0, radius)
		fx._parts.append({"kind": "sparkle", "p": at + off, "v": off * 1.2 + Vector2(0, -20), "life": randf_range(0.35, 0.7), "age": 0.0, "size": randf_range(3.0, 7.0), "rot": randf() * TAU, "spin": randf_range(-5.0, 5.0), "color": color, "g": 0.0})

static func dust(at: Vector2, direction: float) -> void:
	var fx := layer()
	if fx == null:
		return
	for i in range(3):
		fx._parts.append({"kind": "dust", "p": at + Vector2(randf_range(-6, 6), 0), "v": Vector2(-direction * randf_range(20, 45), randf_range(-22, -8)), "life": randf_range(0.35, 0.55), "age": 0.0, "size": randf_range(3.5, 6.0), "rot": 0.0, "spin": 0.0, "color": Color(1.0, 0.93, 0.93, 0.8), "g": 0.0})

static func text(at: Vector2, message: String, color: Color = Color("ff4f82"), size: int = 22) -> void:
	var fx := layer()
	if fx == null:
		return
	fx._texts.append({"p": at, "msg": message, "age": 0.0, "life": 1.1, "color": color, "size": size})

static func ring(at: Vector2, color: Color, radius: float = 60.0) -> void:
	var fx := layer()
	if fx != null:
		fx._rings.append({"p": at, "age": 0.0, "life": 0.4, "color": color, "r": radius})

func _process(delta: float) -> void:
	for list: Array in [_parts, _texts, _rings]:
		for i in range(list.size() - 1, -1, -1):
			var it: Dictionary = list[i]
			it["age"] += delta
			if it["age"] >= it["life"]:
				list.remove_at(i)
				continue
			if it.has("v"):
				it["v"] = it["v"] * pow(0.08, delta) + Vector2(0, it["g"] * delta)
				it["p"] += it["v"] * delta
				it["rot"] += it["spin"] * delta
	queue_redraw()

func _draw() -> void:
	for r: Dictionary in _rings:
		var k: float = r["age"] / r["life"]
		var e := 1.0 - pow(1.0 - k, 3.0)
		draw_arc(r["p"], r["r"] * e, 0.0, TAU, 48, Color(r["color"], 0.7 * (1.0 - k)), 5.0 * (1.0 - k) + 1.0, true)
	for p: Dictionary in _parts:
		var k: float = p["age"] / p["life"]
		var fade := 1.0 - k * k
		var col: Color = p["color"]
		match p["kind"]:
			"heart":
				var pop := minf(1.0, k * 8.0)
				heart(p["p"], p["size"] * pop * (1.0 - k * 0.3), Color(col, fade), 0.0, p["rot"])
			"sparkle":
				sparkle(p["p"], p["size"] * sin(k * PI), Color(col, fade), p["rot"])
			"dust":
				draw_circle(p["p"], p["size"] * (0.6 + k), Color(col, col.a * (1.0 - k)), true, -1.0, true)
	for t: Dictionary in _texts:
		var k: float = t["age"] / t["life"]
		var sc := 1.0 + 0.6 * exp(-k * 14.0) * cos(k * 30.0) if k < 0.3 else 1.0
		var at: Vector2 = t["p"] + Vector2(0, -46.0 * (1.0 - pow(1.0 - k, 2.0)))
		var alpha := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
		var w := FONT.get_string_size(t["msg"], HORIZONTAL_ALIGNMENT_LEFT, -1, t["size"]).x
		draw_set_transform(at, 0.0, Vector2.ONE * sc)
		draw_string_outline(FONT, Vector2(-w / 2, 0), t["msg"], HORIZONTAL_ALIGNMENT_LEFT, -1, t["size"], 7, Color(1, 1, 1, alpha))
		draw_string(FONT, Vector2(-w / 2, 0), t["msg"], HORIZONTAL_ALIGNMENT_LEFT, -1, t["size"], Color(t["color"], alpha))
		draw_set_transform(Vector2.ZERO)
