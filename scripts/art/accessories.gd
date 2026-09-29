extends RefCounted
## Drawing for wearable extras: wings, auras and hats, all animated from the rig's clock `t`.
## Every function draws onto a character rig (a soft_draw canvas) whose transform is already set:
## wings in torso space (upper back near (0, -30)), auras in body space (feet at the origin, the
## body spans roughly y 0..-150), hats in head space (head centre at the origin, crown near y -34).
## Things that wrap around the body (aura motes, halo rings) are split into a back pass drawn
## behind the character and a front pass drawn over it, so they read as 3D.

const Kit := preload("res://scripts/art/soft_draw.gd")

# ---------------------------------------------------------------- helpers

static func _mapped(xf: Transform2D, p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in p:
		out.append(xf * v)
	return out

static func _poly(c: CanvasItem, p: PackedVector2Array, fill: Color, edge: Color = Color.TRANSPARENT, w: float = 1.4) -> void:
	c.draw_colored_polygon(p, fill)
	if edge.a > 0.0:
		var closed := p.duplicate()
		closed.append(p[0])
		c.draw_polyline(closed, edge, w, true)

## Polygon whose colour runs from `a` at `from` to `b` at `to` (a linear gradient).
static func _grad(c: CanvasItem, p: PackedVector2Array, from: Vector2, to: Vector2, a: Color, b: Color, edge: Color = Color.TRANSPARENT, w: float = 1.4) -> void:
	var cols := PackedColorArray()
	var axis := to - from
	var len2 := maxf(axis.length_squared(), 0.001)
	for v: Vector2 in p:
		cols.append(a.lerp(b, clampf((v - from).dot(axis) / len2, 0.0, 1.0)))
	c.draw_polygon(p, cols)
	if edge.a > 0.0:
		var closed := p.duplicate()
		closed.append(p[0])
		c.draw_polyline(closed, edge, w, true)

static func _ellipse(center: Vector2, r: Vector2, from: float = 0.0, to: float = TAU, n: int = 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	# A full loop leaves out the repeated end point so it triangulates cleanly as a polygon.
	var last := n if to - from >= TAU - 0.001 else n + 1
	for i in range(last):
		var a := lerpf(from, to, float(i) / n)
		out.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out

## A rotated ellipse built point by point, so drawing never has to touch the canvas transform
## (the rig relies on the transform it set for the body space).
static func _oval(center: Vector2, r: Vector2, rot: float, n: int = 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / n
		out.append(center + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return out

static func _star(center: Vector2, r: float, rot: float, inner: float = 0.45) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(10):
		out.append(center + Vector2.from_angle(rot - PI / 2 + TAU * i / 10.0) * (r if i % 2 == 0 else r * inner))
	return out

static func _twinkle(c: CanvasItem, at: Vector2, size: float, t: float, col: Color = Color.WHITE) -> void:
	var s := size * (0.55 + 0.45 * sin(t))
	if s > 0.4:
		c.draw_colored_polygon(Kit.sparkle_pts(at, s, t * 0.3), col)

static func _hash(i: int) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)

# ---------------------------------------------------------------- wings

## Both wings: the far one first (smaller, shaded), then the near one.
static func wings(c: CanvasItem, id: String, t: float) -> void:
	for side: float in [1.0, -1.0]:
		var far := side > 0.0
		var root := Vector2(side * 5.0, -30.0)
		var scale := (0.96 if far else 1.0) * 1.55
		# A flap beat: the whole wing hinges at the root, tips follow a moment later.
		var beat := sin(t * 4.0 + (0.25 if far else 0.0))
		# Rotate in the wing's own space first, then mirror, so both wings lift and beat symmetrically.
		var xf := Transform2D(0.0, Vector2(side * scale, scale), 0.0, root) * Transform2D(-0.1 + beat * 0.12, Vector2.ZERO)
		_wing(c, id, xf, t, beat, far)

static func _wing(c: CanvasItem, id: String, xf: Transform2D, t: float, beat: float, far: bool) -> void:
	var dim := 0.06 if far else 0.0
	match id:
		"angel", "galaxy":
			_feathered(c, xf, t, beat, dim, id == "galaxy")
		"fairy":
			_fairy(c, xf, t, dim)
		"butterfly":
			_butterfly(c, xf, t, dim)
		"bat":
			_bat(c, xf, t, beat, dim)
		"heart":
			_heart_wing(c, xf, t, dim)
		"crystal":
			_crystal(c, xf, t, dim)
		"phoenix":
			_phoenix(c, xf, t, beat, dim)

## Feathers hang from an arm line that runs up and out; they point down near the body and out at the tip.
static func _feathered(c: CanvasItem, xf: Transform2D, t: float, beat: float, dim: float, galaxy: bool) -> void:
	var arm := [Vector2(0, 0), Vector2(14, -20), Vector2(30, -34), Vector2(48, -38)]
	var rows := [[9, 30.0, 6.0], [7, 20.0, 5.2], [6, 11.0, 4.6]]
	var base_a := Color("f4f1ff") if not galaxy else Color("2a1c63")
	var tip_a := Color("dfe6ff") if not galaxy else Color("c27bff")
	# Soft glow behind the whole wing.
	var glow := PackedVector2Array()
	for p: Vector2 in [Vector2(-4, 4), Vector2(16, -30), Vector2(46, -48), Vector2(80, -40), Vector2(64, 0), Vector2(28, 26), Vector2(2, 20)]:
		glow.append(xf * p)
	c.draw_colored_polygon(Kit.smooth(glow), Color(1.0, 0.95, 0.85, 0.16) if not galaxy else Color(0.7, 0.45, 1.0, 0.22))
	for r in range(rows.size()):
		var count: int = rows[r][0]
		var max_len: float = rows[r][1]
		var width: float = rows[r][2]
		for i in range(count):
			var k := float(i) / (count - 1)
			var base := _along(arm, k * (1.0 - r * 0.25))
			var lag := sin(t * 4.0 - k * 1.6) * 0.1 * (1.0 + k)
			var ang := lerpf(1.35, -0.1, k) + lag - beat * 0.05
			var length := lerpf(max_len * 0.7, max_len * 1.35, k) if r == 0 else max_len * lerpf(0.9, 1.1, k)
			var d := Vector2.from_angle(ang)
			var n := d.orthogonal()
			var f := PackedVector2Array([base - n * width * 0.6, base + d * length * 0.55 - n * width, base + d * length, base + d * length * 0.55 + n * width, base + n * width * 0.6])
			var mapped := _mapped(xf, Kit.smooth(f, 4))
			var ca := base_a.darkened(dim)
			var cb := tip_a.darkened(dim).lerp(Color.WHITE, 0.2 * r)
			_grad(c, mapped, xf * base, xf * (base + d * length), ca, cb, Color("b9c3e8").darkened(dim) if not galaxy else Color(0.85, 0.7, 1.0, 0.9), 1.1)
			if galaxy and (i + r) % 2 == 0:
				_twinkle(c, xf * (base + d * length * 0.6), 2.4, t * 5.0 + i + r * 3.0)
	if not galaxy:
		# A loose feather drifts off every few seconds.
		var k := fmod(t * 0.35, 1.0)
		var drift := xf * (Vector2(40, 10) + Vector2(k * 20.0, k * 60.0))
		c.draw_colored_polygon(_oval(drift, Vector2(5, 2.2), k * 4.0), Color(1, 1, 1, 0.9 * (1.0 - k)))

static func _along(line: Array, k: float) -> Vector2:
	var seg := clampf(k, 0.0, 0.999) * (line.size() - 1)
	var i := int(seg)
	return (line[i] as Vector2).lerp(line[i + 1], seg - i)

static func _fairy(c: CanvasItem, xf: Transform2D, t: float, dim: float) -> void:
	var upper := Kit.smooth(Kit.pts([0, -2, 10, -30, 34, -52, 56, -50, 50, -26, 22, -6]))
	var lower := Kit.smooth(Kit.pts([0, 2, 20, 6, 38, 22, 34, 38, 16, 30, 4, 12]))
	for shape: PackedVector2Array in [upper, lower]:
		var m := _mapped(xf, shape)
		var cols := PackedColorArray()
		for v: Vector2 in shape:
			var hue := fmod(0.82 + v.length() / 120.0 + t * 0.08, 1.0)
			cols.append(Color.from_hsv(hue, 0.3, 1.0, 0.55 - dim))
		c.draw_polygon(m, cols)
		var edge := m.duplicate()
		edge.append(m[0])
		c.draw_polyline(edge, Color(1, 1, 1, 0.95 - dim), 1.6, true)
	for v: Array in [[Vector2(2, -2), Vector2(44, -44)], [Vector2(4, -3), Vector2(50, -30)], [Vector2(3, 2), Vector2(32, 30)]]:
		c.draw_line(xf * v[0], xf * v[1], Color(1, 1, 1, 0.55), 1.0, true)
	# Shimmer sweep and pixie dust.
	var sweep := fmod(t * 0.6, 1.0)
	c.draw_line(xf * Vector2(10 + sweep * 40.0, -10 - sweep * 40.0), xf * Vector2(24 + sweep * 30.0, -4 - sweep * 30.0), Color(1, 1, 1, 0.6 * sin(sweep * PI)), 3.0, true)
	for i in range(4):
		var k := fmod(t * 0.5 + i * 0.25, 1.0)
		_twinkle(c, xf * Vector2(46 - k * 10.0, -40 + k * 70.0), 3.0 * (1.0 - k), t * 6.0 + i, Color(1.0, 0.95, 0.8))

static func _butterfly(c: CanvasItem, xf: Transform2D, t: float, dim: float) -> void:
	var upper := Kit.smooth(Kit.pts([0, -2, 8, -32, 30, -54, 58, -48, 54, -22, 20, -4]))
	var lower := Kit.smooth(Kit.pts([0, 2, 22, 4, 40, 20, 34, 42, 12, 34, 2, 12]))
	for pair: Array in [[upper, Color("ffb86b"), Color("ff7fae")], [lower, Color("ff9ec7"), Color("c9a0ff")]]:
		var shape: PackedVector2Array = pair[0]
		var m := _mapped(xf, shape)
		_grad(c, m, xf * Vector2(0, 0), xf * Vector2(50, -40), (pair[1] as Color).darkened(dim), (pair[2] as Color).darkened(dim), Color("5a2a3a"), 3.2)
		var edge := m.duplicate()
		edge.append(m[0])
		for i in range(0, edge.size() - 1, 3):
			c.draw_circle(edge[i], 1.3, Color(1, 1, 1, 0.9), true, -1.0, true)
	for v: Vector2 in [Vector2(8, -6), Vector2(8, 4)]:
		c.draw_line(xf * v, xf * (v + Vector2(28, -26 if v.y < 0 else 20)), Color("5a2a3a"), 1.2, true)
	for spot: Vector2 in [Vector2(38, -40), Vector2(26, -24), Vector2(24, 20)]:
		c.draw_circle(xf * spot, 3.4, Color(1, 1, 1, 0.85), true, -1.0, true)

static func _bat(c: CanvasItem, xf: Transform2D, t: float, beat: float, dim: float) -> void:
	var fingers := [Vector2(34, -44), Vector2(60, -34), Vector2(62, -8), Vector2(44, 12)]
	var membrane := PackedVector2Array([Vector2(0, -4), Vector2(18, -34)])
	membrane.append(fingers[0])
	for i in range(fingers.size() - 1):
		var a: Vector2 = fingers[i]
		var b: Vector2 = fingers[i + 1]
		var mid := a.lerp(b, 0.5) + (Vector2(0, 0) - a.lerp(b, 0.5)).normalized() * 9.0
		membrane.append(mid)
		membrane.append(b)
	membrane.append(Vector2(20, 14))
	membrane.append(Vector2(2, 6))
	var m := _mapped(xf, membrane)
	_grad(c, m, xf * Vector2(0, 0), xf * Vector2(60, -30), Color("2c1a38").darkened(dim), Color("6a2a5e").darkened(dim), Color("12081a"), 1.6)
	for f: Vector2 in fingers:
		c.draw_line(xf * Vector2(18, -30), xf * f, Color("8a5aa0").darkened(dim), 1.4, true)
	c.draw_line(xf * Vector2(0, -4), xf * Vector2(18, -30), Color("8a5aa0").darkened(dim), 2.0, true)

static func _heart_wing(c: CanvasItem, xf: Transform2D, t: float, dim: float) -> void:
	var pulse := 1.0 + sin(t * 3.0) * 0.04
	for layer: Array in [[Vector2(26, -18), 24.0, Color("ff7fae"), Color("ffc4dc")], [Vector2(18, 6), 15.0, Color("ff9ec7"), Color("ffe0ec")]]:
		var hp := Kit.heart_pts(layer[0], (layer[1] as float) * pulse, 0.85)
		var m := _mapped(xf, hp)
		_grad(c, m, xf * ((layer[0] as Vector2) + Vector2(-10, -10)), xf * ((layer[0] as Vector2) + Vector2(10, 16)), (layer[3] as Color).darkened(dim), (layer[2] as Color).darkened(dim), Color("d9467a"), 1.6)
		c.draw_circle(xf * ((layer[0] as Vector2) + Vector2(-6, -8)), 3.2, Color(1, 1, 1, 0.75), true, -1.0, true)
	for i in range(3):
		var k := fmod(t * 0.5 + i / 3.0, 1.0)
		c.draw_colored_polygon(Kit.heart_pts(xf * Vector2(46 + k * 10.0, -30 - k * 30.0), 3.0 * (1.0 - k)), Color(1.0, 0.5, 0.7, 1.0 - k))

static func _crystal(c: CanvasItem, xf: Transform2D, t: float, dim: float) -> void:
	for i in range(6):
		var ang := lerpf(-1.25, 0.55, i / 5.0) + sin(t * 3.0 - i * 0.5) * 0.03
		var length := 58.0 - absf(i - 2.5) * 7.0
		var d := Vector2.from_angle(ang)
		var n := d.orthogonal()
		var shard := PackedVector2Array([-n * 3.0, d * length * 0.5 - n * 7.5, d * length, d * length * 0.5 + n * 7.5, n * 3.0])
		var m := _mapped(xf, shard)
		c.draw_colored_polygon(_mapped(xf, PackedVector2Array([-n * 6.0, d * length * 0.5 - n * 11.0, d * (length + 6.0), d * length * 0.5 + n * 11.0, n * 6.0])), Color(0.7, 0.9, 1.0, 0.15))
		_grad(c, m, xf * Vector2.ZERO, xf * (d * length), Color(0.72, 0.9, 1.0, 0.85 - dim), Color(0.95, 1.0, 1.0, 0.95 - dim), Color(1, 1, 1, 1), 1.2)
		c.draw_line(xf * (d * 3.0), xf * (d * length * 0.95), Color(0.55, 0.8, 1.0, 0.8), 1.0, true)
		# A glint travels up each shard.
		var g := fmod(t * 0.8 + i * 0.17, 1.0)
		_twinkle(c, xf * (d * length * g), 3.0, t * 7.0 + i)

static func _phoenix(c: CanvasItem, xf: Transform2D, t: float, beat: float, dim: float) -> void:
	c.draw_colored_polygon(Kit.smooth(_mapped(xf, PackedVector2Array([Vector2(-4, 8), Vector2(20, -40), Vector2(64, -54), Vector2(80, -20), Vector2(50, 24), Vector2(10, 30)]))), Color(1.0, 0.55, 0.2, 0.09))
	for i in range(8):
		var k := i / 7.0
		var ang := lerpf(1.6, -0.35, k) + sin(t * 9.0 + i * 1.7) * 0.05
		var length := lerpf(30.0, 64.0, sin(k * PI * 0.8)) * (1.0 + sin(t * 11.0 + i * 2.3) * 0.05)
		var base := Vector2(k * 14.0, -k * 18.0)
		var d := Vector2.from_angle(ang)
		var n := d.orthogonal()
		var flame := Kit.smooth(PackedVector2Array([base - n * 4.5, base + d * length * 0.45 - n * 6.5, base + d * length + n * sin(t * 8.0 + i) * 3.0, base + d * length * 0.45 + n * 6.5, base + n * 4.5]), 4)
		_grad(c, _mapped(xf, flame), xf * base, xf * (base + d * length), Color("d8261e").darkened(dim), Color("ffe066").darkened(dim), Color(1.0, 0.45, 0.2, 0.8), 1.0)
	for i in range(7):
		var k := fmod(t * 0.7 + _hash(i), 1.0)
		var p := Vector2(20 + _hash(i + 3) * 44.0, 10 - k * 70.0)
		c.draw_circle(xf * p, 2.2 * (1.0 - k), Color(1.0, 0.75 + 0.25 * k, 0.3, 1.0 - k), true, -1.0, true)

# ---------------------------------------------------------------- auras

## Ground glow and everything orbiting behind the character.
static func aura_back(c: CanvasItem, id: String, t: float) -> void:
	var col := aura_color(id)
	if id == "halo_light":
		# Soft pillars of light rising from the ground.
		for i in range(4):
			var x := (i - 1.5) * 18.0 + sin(t * 0.8 + i) * 4.0
			var w := 10.0 + 4.0 * sin(t * 1.3 + i * 2.0)
			var shaft := PackedVector2Array([Vector2(x - w, 4), Vector2(x + w, 4), Vector2(x + w * 0.4, -190), Vector2(x - w * 0.4, -190)])
			c.draw_polygon(shaft, PackedColorArray([Color(1.0, 0.92, 0.6, 0.28), Color(1.0, 0.92, 0.6, 0.28), Color(1.0, 0.95, 0.8, 0.0), Color(1.0, 0.95, 0.8, 0.0)]))
	if id == "starfall":
		c.draw_polygon(PackedVector2Array([Vector2(-60, 6), Vector2(60, 6), Vector2(45, -170), Vector2(-45, -170)]), PackedColorArray([Color(0.4, 0.3, 0.9, 0.18), Color(0.4, 0.3, 0.9, 0.18), Color(0.4, 0.3, 0.9, 0.0), Color(0.4, 0.3, 0.9, 0.0)]))
	_ground_ring(c, col, t, false)
	_orbit(c, id, t, false)

## Everything orbiting in front of the character.
static func aura_front(c: CanvasItem, id: String, t: float) -> void:
	_ground_ring(c, aura_color(id), t, true)
	_orbit(c, id, t, true)

static func aura_color(id: String) -> Color:
	return {"sparkle": Color("ffd65c"), "hearts": Color("ff6f9f"), "petals": Color("ff9ec0"), "bubbles": Color("7fd4ff"),
		"music": Color("4fd6a8"), "rainbow": Color("ff8fd0"), "starfall": Color("9d8aff"), "halo_light": Color("ffd65c")}.get(id, Color.WHITE)

## A magic circle on the floor, seen in perspective; the back half glows behind the feet.
static func _ground_ring(c: CanvasItem, col: Color, t: float, front: bool) -> void:
	var from := 0.0 if front else PI
	var to := PI if front else TAU
	var pulse := 1.0 + sin(t * 2.5) * 0.05
	if not front:
		c.draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(40, 10) * pulse), Color(col, 0.18))
	c.draw_polyline(_ellipse(Vector2.ZERO, Vector2(38, 9.5) * pulse, from, to, 24), Color(col, 0.85), 2.0, true)
	c.draw_polyline(_ellipse(Vector2.ZERO, Vector2(28, 7) * pulse, from, to, 20), Color(col.lightened(0.4), 0.7), 1.2, true)
	for i in range(8):
		var a := t * 0.8 + TAU * i / 8.0
		if (sin(a) >= 0.0) == front:
			c.draw_circle(Vector2(cos(a) * 33.0, sin(a) * 8.2) * pulse, 1.6, Color(1, 1, 1, 0.9), true, -1.0, true)

## Motes spiral up around the body; depth decides whether each one is behind or in front.
static func _orbit(c: CanvasItem, id: String, t: float, front: bool) -> void:
	if id == "rainbow":
		_rainbow_ribbon(c, t, front)
	var count := 9
	for i in range(count):
		var rise := fmod(t * 0.18 + float(i) / count, 1.0)
		var a := t * 1.4 + TAU * i / count
		var depth := sin(a)
		if (depth >= 0.0) != front:
			continue
		var r := 34.0 + 10.0 * sin(rise * PI)
		var p := Vector2(cos(a) * r, -8.0 - rise * 150.0)
		var s := 0.75 + 0.3 * depth
		var alpha := sin(rise * PI) * (0.7 + 0.3 * depth)
		_mote(c, id, p, s, alpha, t + i, i)

static func _mote(c: CanvasItem, id: String, p: Vector2, s: float, alpha: float, t: float, i: int) -> void:
	match id:
		"sparkle", "halo_light":
			c.draw_circle(p, 6.0 * s, Color(1.0, 0.9, 0.5, 0.2 * alpha), true, -1.0, true)
			c.draw_colored_polygon(Kit.sparkle_pts(p, 5.5 * s, t * 2.0), Color(1.0, 0.95, 0.7, alpha))
		"hearts":
			c.draw_colored_polygon(Kit.heart_pts(p, 6.0 * s, sin(t * 2.0) * 0.3), Color(1.0, 0.45, 0.65, alpha))
			c.draw_circle(p + Vector2(-2, -2) * s, 1.3 * s, Color(1, 1, 1, alpha * 0.8), true, -1.0, true)
		"petals":
			var flutter := 0.45 + 0.4 * absf(sin(t * 3.0))
			c.draw_colored_polygon(_oval(p, Vector2(6, 4 * flutter) * s, t * 2.2), Color(1.0, 0.76, 0.85, alpha))
			c.draw_colored_polygon(_oval(p + Vector2(-1.5, -1).rotated(t * 2.2) * s, Vector2(2.6, 1.6 * flutter) * s, t * 2.2), Color(1, 1, 1, alpha * 0.6))
		"bubbles":
			var r := (3.5 + (i % 3) * 2.0) * s
			c.draw_circle(p, r, Color(0.6, 0.88, 1.0, 0.18 * alpha), true, -1.0, true)
			c.draw_arc(p, r, 0.0, TAU, 16, Color(0.8, 0.95, 1.0, alpha), 1.3, true)
			c.draw_arc(p, r * 0.6, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, alpha), 1.2, true)
		"music":
			var col := Color(0.2, 0.75, 0.6, alpha)
			c.draw_colored_polygon(Kit.ellipse_pts(p, Vector2(3.4, 2.6) * s, 12), col)
			c.draw_line(p + Vector2(3.0, 0) * s, p + Vector2(3.0, -11.0) * s, col, 1.6, true)
			c.draw_line(p + Vector2(3.0, -11.0) * s, p + Vector2(8.0, -8.0) * s, col, 1.6, true)
		"rainbow":
			c.draw_colored_polygon(Kit.sparkle_pts(p, 5.0 * s, t), Color.from_hsv(fmod(i / 9.0 + t * 0.1, 1.0), 0.35, 1.0, alpha))
		"starfall":
			var fall := Vector2(-6, 14).normalized()
			c.draw_line(p - fall * 16.0 * s, p, Color(0.8, 0.8, 1.0, alpha * 0.5), 2.0 * s, true)
			c.draw_colored_polygon(_star(p, 5.0 * s, t), Color(1.0, 0.95, 0.75, alpha))

## A rainbow ribbon spiralling up the body, split into front and back halves.
static func _rainbow_ribbon(c: CanvasItem, t: float, front: bool) -> void:
	var steps := 48
	for band in range(3):
		var prev := Vector2.ZERO
		var prev_front := false
		for i in range(steps + 1):
			var k := float(i) / steps
			var a := k * TAU * 1.15 + t * 1.2 + band * 0.12
			var p := Vector2(cos(a) * (44.0 - k * 4.0), -6.0 - k * 150.0 + band * 4.0)
			var is_front := sin(a) >= 0.0
			if i > 0 and is_front == front and prev_front == front:
				var hue := fmod(k + band * 0.08 + t * 0.05, 1.0)
				var fade := sin(k * PI)
				c.draw_line(prev, p, Color.from_hsv(hue, 0.5, 1.0, (0.7 if front else 0.85) * fade), 2.6, true)
			prev = p
			prev_front = is_front

# ---------------------------------------------------------------- hats

## Pieces that sit behind the head: veils and the far half of a halo.
static func hat_back(c: CanvasItem, id: String, t: float) -> void:
	match id:
		"veil":
			var sway := sin(t * 1.4) * 4.0
			var veil := Kit.smooth(Kit.pts([-24, -34, 24, -34, 38 + sway * 0.5, 10, 36 + sway, 64, 10 + sway, 76, -18 + sway, 74, -40 + sway, 62, -40 + sway * 0.5, 10]))
			c.draw_polygon(veil, _vertical(veil, Color(1, 1, 1, 0.75), Color(0.97, 0.95, 1.0, 0.35), -34.0, 76.0))
			var edge := veil.duplicate()
			edge.append(veil[0])
			c.draw_polyline(edge, Color(0.9, 0.88, 0.98, 0.9), 1.2, true)
			for i in range(10):
				var x := lerpf(-38.0, 34.0, i / 9.0) + sway
				c.draw_arc(Vector2(x, 70 + sin(i * 1.3) * 3.0), 3.6, 0.0, PI, 8, Color(1, 1, 1, 0.85), 1.2, true)
		"halo":
			_halo(c, t, false)

static func _vertical(p: PackedVector2Array, top: Color, bottom: Color, y0: float, y1: float) -> PackedColorArray:
	var cols := PackedColorArray()
	for v: Vector2 in p:
		cols.append(top.lerp(bottom, clampf((v.y - y0) / (y1 - y0), 0.0, 1.0)))
	return cols

## A tilted golden ring floating above the head; the far half is drawn behind the hair.
static func _halo(c: CanvasItem, t: float, front: bool) -> void:
	var center := Vector2(sin(t * 1.3) * 1.5, -54.0 + sin(t * 2.0) * 3.0)
	var r := Vector2(21, 6.5)
	var from := 0.0 if front else PI
	var to := PI if front else TAU
	if not front:
		c.draw_colored_polygon(_ellipse(center, r * 1.5, 0.0, TAU, 32), Color(1.0, 0.9, 0.5, 0.18 + 0.06 * sin(t * 3.0)))
	c.draw_polyline(_ellipse(center, r, from, to, 20), Color(1.0, 0.85, 0.4, 0.45), 8.0, true)
	c.draw_polyline(_ellipse(center, r, from, to, 20), Color("f6c64a"), 4.0, true)
	c.draw_polyline(_ellipse(center + Vector2(0, -1), r, from, to, 20), Color("fff3c4"), 1.4, true)
	if front:
		for i in range(3):
			var a := t * 1.5 + TAU * i / 3.0
			if sin(a) > 0.0:
				_twinkle(c, center + Vector2(cos(a) * r.x, sin(a) * r.y), 4.0, t * 6.0 + i)

static func hat(c: CanvasItem, id: String, t: float) -> void:
	match id:
		"halo":
			_halo(c, t, true)
		"cat_ears", "cat_ears_black":
			_cat_ears(c, t, Color("2a2530") if id == "cat_ears_black" else Color("fbe3ec"))
		"bunny_ears":
			for m: float in [-1.0, 1.0]:
				var bend := sin(t * 2.2 + m) * 4.0 + (6.0 if m > 0 else 0.0) * absf(sin(t * 0.7))
				var outer := Kit.smooth(Kit.pts([7 * m, -30, 5 * m + bend * 0.3, -54, 11 * m + bend, -76, 19 * m + bend, -70, 18 * m + bend * 0.3, -50, 17 * m, -30]))
				_poly(c, outer, Color("ffffff"), Color("c9b6c8"), 1.5)
				var inner := Kit.smooth(Kit.pts([10 * m, -34, 9 * m + bend * 0.3, -52, 13 * m + bend, -68, 16 * m + bend * 0.3, -50, 14 * m, -34]))
				_grad(c, inner, Vector2(0, -34), Vector2(0, -68), Color("ffb3c8"), Color("ffe3ec"))
			_poly(c, Kit.smooth(Kit.pts([-30, -26, -14, -36, 14, -36, 30, -26, 14, -32, -14, -32]), 3), Color("ff9ec7"))
		"flower_crown":
			_flower_crown(c, t)
		"tiara_silver", "star_tiara":
			_tiara(c, t, id == "star_tiara")
		"crown_royal":
			_crown(c, t)
		"witch_hat":
			var tip := sin(t * 1.8) * 6.0
			_poly(c, _ellipse(Vector2(0, -31), Vector2(42, 10)), Color("4b2f7a"), Color("25173e"), 1.6)
			var cone := Kit.smooth(Kit.pts([-22, -33, -12, -56, 2 + tip * 0.5, -72, 18 + tip, -80, 10 + tip * 0.6, -62, 22, -33]), 4)
			_grad(c, cone, Vector2(-20, -40), Vector2(20, -60), Color("7a52b8"), Color("4b2f7a"), Color("25173e"), 1.6)
			_poly(c, Kit.pts([-21.5, -38, 21.5, -38, 22, -33, -22, -33]), Color("ff7fb0"))
			_poly(c, Kit.rrect_pts(Rect2(-5, -39, 10, 7), 1.5), Color("ffd65c"), Color("b8862a"), 1.0)
			_twinkle(c, Vector2(18 + tip, -80), 5.0, t * 4.0, Color("fff3a0"))
		"bow_big":
			var sway := sin(t * 2.0) * 0.08
			for m: float in [-1.0, 1.0]:
				var loop := PackedVector2Array()
				for p: Vector2 in Kit.smooth(Kit.pts([0, -38, -24 * m, -58, -30 * m, -40, -22 * m, -30, -4 * m, -34])):
					loop.append(p.rotated(sway * m))
				_grad(c, loop, Vector2(0, -38), Vector2(-26 * m, -48), Color("ff4f82"), Color("ff9ec0"), Color("b8285a"), 1.6)
				c.draw_line(Vector2(-6 * m, -38), Vector2(-20 * m, -46), Color(1, 1, 1, 0.5), 2.0, true)
			for m: float in [-1.0, 1.0]:
				_poly(c, Kit.pts([2 * m, -34, 10 * m, -18 + sin(t * 2.5 + m) * 2.0, 16 * m, -20, 6 * m, -35]), Color("ff5f8f"), Color("b8285a"), 1.2)
			_poly(c, _ellipse(Vector2(0, -37), Vector2(6, 5)), Color("ff7fa2"), Color("b8285a"), 1.4)
		"headphones":
			c.draw_arc(Vector2(0, -6), 35.0, PI * 1.05, PI * 1.95, 28, Color("c9467a"), 7.0, true)
			c.draw_arc(Vector2(0, -6), 35.0, PI * 1.05, PI * 1.95, 28, Color("ffb3c8"), 5.0, true)
			for m: float in [-1.0, 1.0]:
				_poly(c, Kit.pts([27 * m, -24, 33 * m, -38, 39 * m, -22]), Color("ff8fb8"), Color("c9467a"), 1.3)
				_grad(c, _ellipse(Vector2(33 * m, 2), Vector2(8.5, 12)), Vector2(33 * m, -10), Vector2(33 * m, 14), Color("ffb3d0"), Color("ff6f9f"), Color("c9467a"), 1.6)
				c.draw_circle(Vector2(33 * m, 2), 3.0, Color(1.0, 1.0, 1.0, 0.5 + 0.5 * sin(t * 4.0)), true, -1.0, true)
			var k := fmod(t * 0.6, 1.0)
			var note := Vector2(44, -10 - k * 30.0)
			c.draw_circle(note, 2.6, Color(1.0, 0.5, 0.7, 1.0 - k), true, -1.0, true)
			c.draw_line(note + Vector2(2.4, 0), note + Vector2(2.4, -8), Color(1.0, 0.5, 0.7, 1.0 - k), 1.4, true)
		"top_hat":
			var tilt := Transform2D(0.22 + sin(t * 1.5) * 0.03, Vector2(14, -34))
			_poly(c, _mapped(tilt, _ellipse(Vector2.ZERO, Vector2(19, 5))), Color("2a2530"), Color("110c14"))
			_grad(c, _mapped(tilt, Kit.rrect_pts(Rect2(-11, -26, 22, 26), 3.0)), tilt * Vector2(-11, 0), tilt * Vector2(11, 0), Color("4a4054"), Color("1e1a22"), Color("110c14"))
			_poly(c, _mapped(tilt, Kit.pts([-11, -8, 11, -8, 11, -3, -11, -3])), Color("ff5f8f"))
			for i in range(5):
				c.draw_circle(tilt * (Vector2(7, -6) + Vector2.from_angle(TAU * i / 5.0) * 2.4), 2.2, Color("fff4f8"), true, -1.0, true)
			c.draw_circle(tilt * Vector2(7, -6), 1.4, Color("ffcf4a"), true, -1.0, true)
		"veil":
			c.draw_arc(Vector2(0, -8), 31.0, PI * 1.1, PI * 1.9, 24, Color("f6f0ff"), 4.0, true)
			for i in range(9):
				var a := PI * 1.13 + PI * 0.74 * i / 8.0
				c.draw_circle(Vector2(cos(a) * 31.0, sin(a) * 31.0 - 8.0), 2.0, Color("fffaf2"), true, -1.0, true)
				c.draw_circle(Vector2(cos(a) * 31.0 - 0.6, sin(a) * 31.0 - 8.6), 0.7, Color.WHITE, true, -1.0, true)
			for m: float in [-1.0, 1.0]:
				_flower(c, Vector2(22 * m, -30), 4.0, Color("fff6f9"))

static func _flower(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	for i in range(5):
		c.draw_circle(at + Vector2.from_angle(TAU * i / 5.0 - PI / 2) * r * 0.75, r * 0.62, col, true, -1.0, true)
	c.draw_circle(at, r * 0.45, Color("ffd66e"), true, -1.0, true)

static func _cat_ears(c: CanvasItem, t: float, fur: Color) -> void:
	c.draw_arc(Vector2(0, -8), 33.0, PI * 1.12, PI * 1.88, 24, Color("ff8fb8"), 3.0, true)
	for m: float in [-1.0, 1.0]:
		# Ears twitch every few seconds.
		var twitch := maxf(0.0, sin(t * 2.3 + m * 1.7) - 0.9) * 2.5
		var ear := PackedVector2Array()
		for p: Vector2 in Kit.smooth(Kit.pts([12 * m, -30, 20 * m, -46, 27 * m, -54, 31 * m, -40, 30 * m, -24]), 3):
			ear.append(Vector2(p.x, p.y).rotated(twitch * m * 0.3))
		_poly(c, ear, fur, Kit.ink(fur), 1.6)
		var inner := PackedVector2Array()
		for p: Vector2 in Kit.smooth(Kit.pts([16 * m, -31, 22 * m, -43, 27 * m, -48, 28 * m, -32]), 3):
			inner.append(p.rotated(twitch * m * 0.3))
		_grad(c, inner, Vector2(0, -32), Vector2(0, -48), Color("ffa3c0"), Color("ffd1e0"))

static func _flower_crown(c: CanvasItem, t: float) -> void:
	var cols := [Color("ffb3c8"), Color("fff4f8"), Color("ffd66e"), Color("c9b6ff"), Color("ff8fab")]
	for i in range(10):
		var a := PI * 1.1 + PI * 0.8 * i / 9.0
		var p := Vector2(cos(a) * 32.0, sin(a) * 30.0 - 6.0)
		c.draw_colored_polygon(Kit.ellipse_pts(p + Vector2(4, 2).rotated(a), Vector2(4.5, 2.2), 10), Color("8fcf9a"))
	for i in range(9):
		var a := PI * 1.13 + PI * 0.74 * i / 8.0
		var p := Vector2(cos(a) * 32.0, sin(a) * 30.0 - 6.0 + sin(t * 2.0 + i) * 0.8)
		var r := 3.6 + (i % 3) * 0.8
		var col: Color = cols[i % cols.size()]
		for k in range(5):
			c.draw_circle(p + Vector2.from_angle(TAU * k / 5.0 + t * 0.2) * r * 0.8, r * 0.7, col, true, -1.0, true)
		c.draw_circle(p, r * 0.45, Color("ffcf4a") if col != Color("ffd66e") else Color("ff9a4a"), true, -1.0, true)
	_twinkle(c, Vector2(-20, -42), 3.5, t * 4.0)
	_twinkle(c, Vector2(16, -44), 3.0, t * 5.0 + 2.0)

static func _tiara(c: CanvasItem, t: float, star: bool) -> void:
	var metal := Color("e9eef7")
	var dark := Color("8a96ad")
	# Band follows the curve of the head.
	c.draw_polyline(_ellipse(Vector2(0, -12), Vector2(24, 22), PI * 1.2, PI * 1.8, 16), dark, 4.2, true)
	c.draw_polyline(_ellipse(Vector2(0, -12), Vector2(24, 22), PI * 1.2, PI * 1.8, 16), metal, 2.6, true)
	# Filigree peaks.
	for m: float in [-1.0, 1.0]:
		c.draw_polyline(Kit.open_smooth(Kit.pts([2 * m, -34, 7 * m, -44, 12 * m, -40, 14 * m, -36])), dark, 2.6, true)
		c.draw_polyline(Kit.open_smooth(Kit.pts([2 * m, -34, 7 * m, -44, 12 * m, -40, 14 * m, -36])), metal, 1.4, true)
		c.draw_polyline(Kit.open_smooth(Kit.pts([10 * m, -35, 14 * m, -41, 18 * m, -38, 19 * m, -33])), metal, 1.4, true)
		c.draw_circle(Vector2(12 * m, -41.5), 1.5, Color("fffaf2"), true, -1.0, true)
		c.draw_circle(Vector2(18 * m, -38.5), 1.2, Color("fffaf2"), true, -1.0, true)
	if star:
		c.draw_colored_polygon(_star(Vector2(0, -46), 7.0, sin(t * 1.5) * 0.15), Color("ffcf4a"))
		c.draw_colored_polygon(_star(Vector2(0, -46), 4.0, sin(t * 1.5) * 0.15), Color("fff3a0"))
	else:
		var gem := Kit.smooth(Kit.pts([0, -52, 4, -45, 0, -39, -4, -45]), 3)
		_grad(c, gem, Vector2(-4, -50), Vector2(4, -40), Color("bff0ff"), Color("3aa6e0"), Color("2a6fa0"), 1.0)
		c.draw_circle(Vector2(-1.2, -47), 1.0, Color.WHITE, true, -1.0, true)
	_twinkle(c, Vector2(6, -52), 4.0, t * 5.0)
	_twinkle(c, Vector2(-15, -42), 2.6, t * 4.0 + 2.0)

static func _crown(c: CanvasItem, t: float) -> void:
	var gold_light := Color("ffe38a")
	var gold := Color("f2b632")
	var gold_dark := Color("a8741e")
	# Velvet cap seen through the points.
	_grad(c, Kit.smooth(Kit.pts([-20, -38, -12, -54, 0, -58, 12, -54, 20, -38])), Vector2(0, -58), Vector2(0, -38), Color("e0405a"), Color("9a1f35"))
	# Five points, the middle tallest, each topped with a pearl.
	var tips := [Vector2(-22, -58), Vector2(-11, -62), Vector2(0, -70), Vector2(11, -62), Vector2(22, -58)]
	var outline := PackedVector2Array([Vector2(-24, -36)])
	for i in range(tips.size()):
		outline.append(tips[i])
		if i < tips.size() - 1:
			outline.append((tips[i] as Vector2).lerp(tips[i + 1], 0.5) + Vector2(0, 14))
	outline.append(Vector2(24, -36))
	_grad(c, outline, Vector2(-24, -60), Vector2(24, -40), gold_light, gold, gold_dark, 1.6)
	for p: Vector2 in tips:
		c.draw_circle(p, 3.0, gold_dark, true, -1.0, true)
		c.draw_circle(p, 2.4, Color("fffaf0"), true, -1.0, true)
		c.draw_circle(p + Vector2(-0.8, -0.8), 0.8, Color.WHITE, true, -1.0, true)
	# Curved band with jewels.
	var band := PackedVector2Array()
	for p: Vector2 in _ellipse(Vector2(0, -20), Vector2(25, 18), PI * 1.15, PI * 1.85, 16):
		band.append(p)
	for p: Vector2 in _ellipse(Vector2(0, -12), Vector2(25, 22), PI * 1.85, PI * 1.15, 16):
		band.append(p)
	_grad(c, band, Vector2(-25, -34), Vector2(25, -30), gold_light, gold, gold_dark, 1.4)
	var jewels := [[Vector2(-14, -34), Color("3aa6e0")], [Vector2(0, -35.5), Color("e0304f")], [Vector2(14, -34), Color("3fbf7a")]]
	for j: Array in jewels:
		var p: Vector2 = j[0]
		var size := 3.6 if p.x == 0.0 else 2.8
		_grad(c, _ellipse(p, Vector2(size, size * 1.15), 0.0, TAU, 16), p + Vector2(-2, -2), p + Vector2(2, 3), (j[1] as Color).lightened(0.45), (j[1] as Color).darkened(0.2), gold_dark, 1.0)
		c.draw_circle(p + Vector2(-1, -1.2), 0.9, Color.WHITE, true, -1.0, true)
	# Sparkles hop from point to point.
	var k := int(t * 2.0) % tips.size()
	_twinkle(c, tips[k] + Vector2(3, -4), 5.0, fmod(t * 2.0, 1.0) * PI * 2.0 - PI / 2.0 + PI)
	_twinkle(c, Vector2(-6, -44), 3.0, t * 3.0)
