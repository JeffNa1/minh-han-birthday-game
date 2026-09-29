extends "res://scripts/art/soft_draw.gd"
## A tiny companion that trots (or hovers) beside Minh Hân and cheers when a boy falls for her.
## Lives as a top-level child of its owner so it travels through staircases with her.

const FLYERS := ["unicorn", "dragon", "star_spirit"]

var kind: String = "kitten"
var owner_body: Node2D = null
var _t: float = 0.0
var _hop: float = 0.0
var _facing: float = 1.0
var _cheer: float = 0.0

func _ready() -> void:
	if owner_body:
		top_level = true
		global_position = owner_body.global_position + Vector2(-40, 50)

func cheer() -> void:
	_cheer = 1.0

func _process(delta: float) -> void:
	_t += delta
	_cheer = maxf(0.0, _cheer - delta * 1.5)
	if is_instance_valid(owner_body):
		var side: float = -owner_body.rig.facing
		var goal := owner_body.global_position + Vector2(side * 40.0, 52.0)
		var before := global_position
		global_position = global_position.lerp(goal, 1.0 - exp(-4.0 * delta))
		var moved := global_position - before
		if absf(moved.x) > 0.2:
			_facing = signf(moved.x)
		_hop = moved.length() / maxf(delta, 0.001)
	queue_redraw()

func _draw() -> void:
	var flying := kind in FLYERS
	var hop := 0.0
	if flying:
		hop = -26.0 + sin(_t * 3.0) * 4.0
	elif _hop > 15.0:
		hop = -absf(sin(_t * 12.0)) * 6.0
	hop -= sin(minf(_cheer, 1.0) * PI) * 16.0
	draw_colored_polygon(ellipse_pts(Vector2(0, 0), Vector2(11, 3), 20), Color(0.3, 0.1, 0.25, 0.16 if flying else 0.22))
	draw_set_transform(Vector2(0, hop), 0.0, Vector2(_facing, 1.0))
	draw_pet(self, kind, _t, _hop > 15.0 and not flying)
	draw_set_transform(Vector2.ZERO)
	if _cheer > 0.0:
		heart(Vector2(8, -52 + hop - (1.0 - _cheer) * 16.0), 5.0, Color(1.0, 0.4, 0.6, _cheer))

## Draws a pet with its feet at the origin, facing +x, about 34px tall.
static func draw_pet(c: CanvasItem, id: String, t: float, moving: bool = false) -> void:
	var blink := fmod(t, 3.2) < 0.12
	match id:
		"kitten": _cat(c, t, blink, moving)
		"puppy": _dog(c, t, blink, moving)
		"bunny": _animal(c, t, blink, Color("fbf8fb"), Color("ffe3ec"), "bunny")
		"hamster": _animal(c, t, blink, Color("f2c078"), Color("fffaf0"), "hamster")
		"panda": _animal(c, t, blink, Color("fbfbfb"), Color("fbfbfb"), "panda")
		"chick": _chick(c, t, blink)
		"unicorn": _unicorn(c, t, blink)
		"dragon": _dragon(c, t, blink)
		"star_spirit": _star_spirit(c, t, blink)

static func _o(c: CanvasItem, p: PackedVector2Array, fill: Color, w: float = 1.6) -> void:
	c.draw_colored_polygon(p, fill)
	var e := p.duplicate()
	e.append(p[0])
	c.draw_polyline(e, ink(fill), w, true)

## Four little legs that step when the pet is moving.
static func _legs(c: CanvasItem, t: float, moving: bool, fur: Color, xs: Array) -> void:
	for i in range(xs.size()):
		var lift := maxf(0.0, sin(t * 14.0 + i * PI)) * 3.0 if moving else 0.0
		var x: float = xs[i]
		c.draw_colored_polygon(ellipse_pts(Vector2(x, -3.0 - lift), Vector2(2.8, 3.6), 12), ink(fur))
		c.draw_colored_polygon(ellipse_pts(Vector2(x, -3.2 - lift), Vector2(2.1, 2.9), 12), fur)

## Orange tabby: slim body, tall pointed ears, forehead stripes, whiskers, long S tail and a bell.
static func _cat(c: CanvasItem, t: float, blink: bool, moving: bool) -> void:
	var fur := Color("f5b56e")
	var cream := Color("fff1de")
	var stripe := Color("d98a3e")
	var sway := sin(t * 2.6) * 4.0
	var tail := PackedVector2Array()
	for i in range(12):
		var k := i / 11.0
		tail.append(Vector2(-8.0 - k * 9.0 + sin(k * PI) * -3.0, -8.0 - k * 22.0) + Vector2(sway * k * k, 0))
	c.draw_polyline(tail, ink(fur), 6.4, true)
	c.draw_polyline(tail, fur, 4.4, true)
	for i in [4, 7, 10]:
		c.draw_circle(tail[i], 2.0, stripe, true, -1.0, true)
	_legs(c, t, moving, fur, [-6.0, -2.5, 4.0, 7.5])
	_o(c, ellipse_pts(Vector2(0, -10), Vector2(10.5, 7), 24), fur)
	c.draw_colored_polygon(ellipse_pts(Vector2(4, -8), Vector2(5, 4.5), 16), cream)
	for x: float in [-5.0, -1.0, 3.0]:
		c.draw_arc(Vector2(x, -12), 3.0, PI * 1.2, PI * 1.8, 6, stripe, 1.6, true)
	var head := Vector2(3, -23)
	for m: float in [-1.0, 1.0]:
		var twitch := maxf(0.0, sin(t * 1.7 + m) - 0.92) * 3.0
		_o(c, PackedVector2Array([head + Vector2(5 * m, -6), head + Vector2(10 * m + twitch * m, -19), head + Vector2(12 * m, -3)]), fur)
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(6.8 * m, -6), head + Vector2(10 * m + twitch * m, -15), head + Vector2(10.6 * m, -5)]), Color("ffb3c4"))
	_o(c, ellipse_pts(head, Vector2(11.5, 9.5), 24), fur)
	c.draw_colored_polygon(ellipse_pts(head + Vector2(1, 4), Vector2(6.5, 4), 16), cream)
	for x: float in [-3.0, 0.0, 3.0]:
		c.draw_line(head + Vector2(x, -9), head + Vector2(x * 0.8, -6), stripe, 1.4, true)
	_face(c, head + Vector2(0, -1), blink, Color("6fbf6a"))
	c.draw_colored_polygon(PackedVector2Array([head + Vector2(-1.2, 1.6), head + Vector2(1.2, 1.6), head + Vector2(0, 3)]), Color("ff8fa8"))
	for m: float in [-1.0, 1.0]:
		for k in range(3):
			c.draw_line(head + Vector2(6.5 * m, 2.5 + k * 1.5), head + Vector2(14 * m, 1.0 + k * 2.2), Color(0.35, 0.2, 0.2, 0.55), 0.8, true)
	c.draw_line(head + Vector2(-7, 8), head + Vector2(7, 8), Color("ff7fb0"), 2.2, true)
	var bell := head + Vector2(0, 10) + Vector2(sin(t * 5.0) * 0.6, 0)
	c.draw_circle(bell, 2.2, Color("b8862a"), true, -1.0, true)
	c.draw_circle(bell, 1.7, Color("ffd65c"), true, -1.0, true)

## Shiba: chunky body, white muzzle with a black nose, tongue out, curled tail and a red collar.
static func _dog(c: CanvasItem, t: float, blink: bool, moving: bool) -> void:
	var fur := Color("e39a55")
	var cream := Color("fff4e4")
	var wag := sin(t * 12.0) * 0.25
	var tail_c := Vector2(-9, -16)
	c.draw_arc(tail_c, 5.0, -PI * 0.4 + wag, PI * 1.5 + wag, 18, ink(fur), 6.4, true)
	c.draw_arc(tail_c, 5.0, -PI * 0.4 + wag, PI * 1.5 + wag, 18, fur, 4.4, true)
	c.draw_arc(tail_c, 5.0, PI * 0.6 + wag, PI * 1.3 + wag, 8, cream, 2.2, true)
	_legs(c, t, moving, fur, [-6.5, -3.0, 4.0, 7.5])
	_o(c, ellipse_pts(Vector2(0, -10), Vector2(11.5, 8.5), 24), fur)
	c.draw_colored_polygon(ellipse_pts(Vector2(5, -8), Vector2(5.5, 5.5), 16), cream)
	var head := Vector2(3, -23)
	for m: float in [-1.0, 1.0]:
		_o(c, PackedVector2Array([head + Vector2(6 * m, -6), head + Vector2(11 * m, -14), head + Vector2(13 * m, -3)]), fur)
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(7.5 * m, -5.5), head + Vector2(10.5 * m, -11), head + Vector2(11.5 * m, -4)]), Color("f7c9a0"))
	_o(c, ellipse_pts(head, Vector2(12, 10), 24), fur)
	# White cheeks and a muzzle that pokes forward.
	c.draw_colored_polygon(ellipse_pts(head + Vector2(-4, 4), Vector2(5, 4), 16), cream)
	_o(c, ellipse_pts(head + Vector2(7, 4), Vector2(6.5, 4.8), 18), cream, 1.2)
	c.draw_colored_polygon(ellipse_pts(head + Vector2(12, 2.2), Vector2(2.2, 1.7), 10), Color("2a1f22"))
	var pant := 0.5 + 0.5 * sin(t * 9.0)
	c.draw_colored_polygon(ellipse_pts(head + Vector2(8, 8.5 + pant), Vector2(2, 2.6 + pant), 12), Color("ff7f9a"))
	c.draw_arc(head + Vector2(8, 6), 2.2, 0.2, PI - 0.2, 8, Color("8a3a4a"), 1.1, true)
	for x: float in [-4.0, 4.0]:
		c.draw_circle(head + Vector2(x - 1.0, -5.5), 1.2, cream, true, -1.0, true)
	# The dog's mouth lives on its muzzle, so the generic face skips its own.
	_face(c, head + Vector2(-3, -2), blink, Color("3a2622"), false)
	c.draw_line(head + Vector2(-8, 8), head + Vector2(6, 9), Color("e0304f"), 2.6, true)
	c.draw_circle(head + Vector2(-1, 11), 1.8, Color("ffd65c"), true, -1.0, true)

static func _face(c: CanvasItem, at: Vector2, blink: bool, iris: Color = Color("2f1a29"), mouth: bool = true) -> void:
	for x: float in [-4.0, 4.0]:
		if blink:
			c.draw_line(at + Vector2(x - 1.8, 0), at + Vector2(x + 1.8, 0), Color("2f1a29"), 1.4, true)
		else:
			c.draw_circle(at + Vector2(x, 0), 2.3, Color("2f1a29"), true, -1.0, true)
			if iris != Color("2f1a29"):
				c.draw_circle(at + Vector2(x, 0.3), 1.5, iris, true, -1.0, true)
				c.draw_circle(at + Vector2(x, 0.3), 0.7, Color("2f1a29"), true, -1.0, true)
			c.draw_circle(at + Vector2(x - 0.7, -0.9), 0.8, Color.WHITE, true, -1.0, true)
	c.draw_circle(at + Vector2(-7, 3), 2.0, Color(1, 0.55, 0.65, 0.55), true, -1.0, true)
	if mouth:
		c.draw_circle(at + Vector2(7, 3), 2.0, Color(1, 0.55, 0.65, 0.55), true, -1.0, true)
		c.draw_arc(at + Vector2(-1, 3), 1.3, 0.2, PI - 0.2, 6, Color("8a3a4a"), 1.0, true)
		c.draw_arc(at + Vector2(1.4, 3), 1.3, 0.2, PI - 0.2, 6, Color("8a3a4a"), 1.0, true)

static func _animal(c: CanvasItem, t: float, blink: bool, fur: Color, belly: Color, species: String) -> void:
	var wag := sin(t * 8.0) * 0.4
	# Tail
	match species:
		"cat":
			c.draw_polyline(PackedVector2Array([Vector2(-9, -8), Vector2(-15, -14), Vector2(-14 + wag * 4.0, -22)]), ink(fur), 5.0, true)
			c.draw_polyline(PackedVector2Array([Vector2(-9, -8), Vector2(-15, -14), Vector2(-14 + wag * 4.0, -22)]), fur, 3.2, true)
		"dog":
			_o(c, ellipse_pts(Vector2(-11, -14 + wag), Vector2(4, 5)), fur)
		"bunny":
			_o(c, ellipse_pts(Vector2(-11, -8), Vector2(3.5, 3.5)), Color.WHITE)
	# Feet and body
	for x: float in [-5.0, 5.0]:
		_o(c, ellipse_pts(Vector2(x, -2), Vector2(3.2, 2.4)), fur)
	_o(c, ellipse_pts(Vector2(0, -9), Vector2(10, 8)), fur)
	c.draw_colored_polygon(ellipse_pts(Vector2(1, -8), Vector2(5.5, 5)), belly)
	# Ears
	match species:
		"cat", "dog":
			for m: float in [-1.0, 1.0]:
				_o(c, PackedVector2Array([Vector2(6 * m, -28), Vector2(10 * m, -38), Vector2(13 * m, -26)]), fur)
		"bunny":
			for m: float in [-1.0, 1.0]:
				_o(c, ellipse_pts(Vector2(5 * m, -38), Vector2(3, 9)), fur)
				c.draw_colored_polygon(ellipse_pts(Vector2(5 * m, -37), Vector2(1.4, 6)), Color("ffb3c8"))
		"hamster":
			for m: float in [-1.0, 1.0]:
				_o(c, ellipse_pts(Vector2(8 * m, -30), Vector2(3.2, 3.2)), fur)
		"panda":
			for m: float in [-1.0, 1.0]:
				_o(c, ellipse_pts(Vector2(8 * m, -30), Vector2(3.8, 3.8)), Color("2a2530"))
	# Head
	_o(c, ellipse_pts(Vector2(0, -22), Vector2(11, 9.5)), fur)
	if species == "panda":
		for x: float in [-4.0, 4.0]:
			c.draw_colored_polygon(ellipse_pts(Vector2(x, -22), Vector2(3.2, 3.8)), Color("2a2530"))
		for x: float in [-4.0, 4.0]:
			c.draw_circle(Vector2(x, -22), 1.2 if not blink else 0.4, Color.WHITE, true, -1.0, true)
		c.draw_circle(Vector2(0, -18), 1.2, Color("2a2530"), true, -1.0, true)
		return
	if species == "cat":
		for i in range(3):
			c.draw_line(Vector2(-2 + i * 2, -31), Vector2(-2 + i * 2, -28), fur.darkened(0.25), 1.2, true)
	if species == "dog":
		c.draw_colored_polygon(ellipse_pts(Vector2(0, -18), Vector2(6, 3.5)), belly)
	_face(c, Vector2(0, -22), blink)

static func _chick(c: CanvasItem, t: float, blink: bool) -> void:
	var y := Color("ffe066")
	for x: float in [-3.0, 3.0]:
		c.draw_line(Vector2(x, -4), Vector2(x, 0), Color("f39a3a"), 1.6, true)
	_o(c, ellipse_pts(Vector2(0, -13), Vector2(11, 11)), y)
	_o(c, ellipse_pts(Vector2(-7, -12), Vector2(4, 6)), y.darkened(0.05))
	c.draw_polyline(PackedVector2Array([Vector2(-1, -24), Vector2(0, -28), Vector2(2, -24)]), Color("e0b020"), 1.6, true)
	c.draw_colored_polygon(PackedVector2Array([Vector2(8, -14), Vector2(13, -12.5), Vector2(8, -11)]), Color("f39a3a"))
	_face(c, Vector2(1, -15), blink)

static func _unicorn(c: CanvasItem, t: float, blink: bool) -> void:
	for i in range(5):
		var col := Color.from_hsv(i / 5.0, 0.45, 1.0)
		c.draw_polyline(PackedVector2Array([Vector2(-6, -30 + i * 3), Vector2(-12, -24 + i * 3), Vector2(-10 + sin(t * 4.0 + i) * 2.0, -14 + i * 3)]), col, 3.0, true)
	_animal(c, t, blink, Color("fdf8ff"), Color("f3ecff"), "dog")
	_o(c, PackedVector2Array([Vector2(-2, -31), Vector2(1, -44), Vector2(3, -31)]), Color("f6cf5a"), 1.2)
	c.draw_colored_polygon(sparkle_pts(Vector2(12, -38), 3.0 + sin(t * 5.0), t), Color("fff6c9"))

static func _dragon(c: CanvasItem, t: float, blink: bool) -> void:
	var flap := sin(t * 10.0) * 5.0
	var wing := Color("c9a8ff")
	_o(c, PackedVector2Array([Vector2(-4, -14), Vector2(-16, -26 - flap), Vector2(-20, -12 - flap * 0.5), Vector2(-10, -10)]), wing)
	c.draw_polyline(PackedVector2Array([Vector2(-8, -6), Vector2(-16, -4), Vector2(-20, -8)]), Color("b38ae8"), 3.0, true)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-20, -8), Vector2(-25, -11), Vector2(-23, -5)]), Color("b38ae8"))
	_animal(c, t, blink, Color("b89aff"), Color("fff0d6"), "hamster")
	for m: float in [-1.0, 1.0]:
		_o(c, PackedVector2Array([Vector2(4 * m, -30), Vector2(6 * m, -37), Vector2(8 * m, -29)]), Color("fff0d6"), 1.2)

static func _star_spirit(c: CanvasItem, t: float, blink: bool) -> void:
	for i in range(4):
		var k := fmod(t * 0.8 + i / 4.0, 1.0)
		c.draw_circle(Vector2(-10 - k * 20.0, -14 + sin(k * 8.0) * 4.0), 2.0 * (1.0 - k), Color(1.0, 0.9, 0.5, 1.0 - k), true, -1.0, true)
	c.draw_circle(Vector2(0, -16), 18.0, Color(1.0, 0.92, 0.55, 0.25 + 0.1 * sin(t * 4.0)), true, -1.0, true)
	var star := PackedVector2Array()
	for i in range(10):
		star.append(Vector2(0, -16) + Vector2.from_angle(sin(t * 2.0) * 0.1 - PI / 2 + TAU * i / 10.0) * (14.0 if i % 2 == 0 else 7.0))
	_o(c, star, Color("ffe36e"))
	_face(c, Vector2(0, -15), blink)
