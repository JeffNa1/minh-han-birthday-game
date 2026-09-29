extends Node2D
## Shared drawing kit: smooth closed shapes, tapered limb chains, hearts and sparkles.
## Every picture in the game is authored with these helpers; there are no raster sprites.

const OUTLINE := 2.0

static func ink(c: Color) -> Color:
	return c.darkened(0.52).lerp(Color("4d2342"), 0.38)

static func pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out

static func dir(angle: float) -> Vector2:
	return Vector2(sin(angle), cos(angle))

## Closed Catmull-Rom spline through the control points.
static func smooth(points: PackedVector2Array, steps: int = 5) -> PackedVector2Array:
	var n := points.size()
	var out := PackedVector2Array()
	for i in range(n):
		var p0: Vector2 = points[(i - 1 + n) % n]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % n]
		var p3: Vector2 = points[(i + 2) % n]
		for s in range(steps):
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	return out

static func open_smooth(points: PackedVector2Array, steps: int = 6) -> PackedVector2Array:
	var n := points.size()
	var out := PackedVector2Array()
	for i in range(n - 1):
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, n - 1)]
		for s in range(steps):
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out

static func ellipse_pts(c: Vector2, r: Vector2, count: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(count):
		var a := TAU * i / count
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out

static func rrect_pts(rect: Rect2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var corners := [rect.position + Vector2(rect.size.x - r, r), rect.position + rect.size - Vector2(r, r), rect.position + Vector2(r, rect.size.y - r), rect.position + Vector2(r, r)]
	for i in range(4):
		for s in range(7):
			var a := -PI / 2 + PI / 2 * i + PI / 2 * s / 6.0
			out.append(corners[i] + Vector2(cos(a), sin(a)) * r)
	return out

static func heart_pts(c: Vector2, size: float, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(36):
		var t := TAU * i / 36
		var p := Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)))
		out.append(c + (p / 16.0 * size).rotated(rot))
	return out

static func sparkle_pts(c: Vector2, size: float, rot: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(8):
		var r := size if i % 2 == 0 else size * 0.26
		out.append(c + Vector2.from_angle(rot + TAU * i / 8.0 - PI / 2) * r)
	return out

static func capsule_pts(a: Vector2, b: Vector2, ra: float, rb: float) -> PackedVector2Array:
	var d := b - a
	var ang := d.angle() if d.length() > 0.01 else PI / 2
	var out := PackedVector2Array()
	for i in range(9):
		out.append(b + Vector2.from_angle(ang - PI / 2 + PI * i / 8.0) * rb)
	for i in range(9):
		out.append(a + Vector2.from_angle(ang + PI / 2 + PI * i / 8.0) * ra)
	return out

## Hook for subclasses that bend authored geometry (the rig turns torsos three-quarter).
func map_pts(points: PackedVector2Array) -> PackedVector2Array:
	return points

func map_pt(p: Vector2) -> Vector2:
	return p

func poly(points: PackedVector2Array, fill: Color, w: float = OUTLINE, edge: Color = Color.TRANSPARENT) -> void:
	points = map_pts(points)
	draw_colored_polygon(points, fill)
	if w > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, edge if edge.a > 0.0 else ink(fill), w, true)

func blob(flat: Array, fill: Color, w: float = OUTLINE, edge: Color = Color.TRANSPARENT) -> void:
	poly(smooth(pts(flat)), fill, w, edge)

func line(flat: Array, color: Color, w: float = 1.6) -> void:
	draw_polyline(map_pts(open_smooth(pts(flat))), color, w, true)

func seg(a: Vector2, b: Vector2, color: Color, w: float = 1.6) -> void:
	draw_line(map_pt(a), map_pt(b), color, w, true)

func ellipse(c: Vector2, r: Vector2, fill: Color, w: float = 0.0, edge: Color = Color.TRANSPARENT) -> void:
	poly(ellipse_pts(c, r), fill, w, edge)

func dot(c: Vector2, r: float, fill: Color, w: float = OUTLINE) -> void:
	c = map_pt(c)
	if w > 0.0:
		draw_circle(c, r + w, ink(fill), true, -1.0, true)
	draw_circle(c, r, fill, true, -1.0, true)

## Tapered limb through several joints; outlines go under every fill so joints stay seamless.
func chain(joints: Array, radii: Array, fill: Color, w: float = OUTLINE) -> void:
	joints = joints.map(map_pt)
	if w > 0.0:
		var edge := ink(fill)
		for i in range(joints.size() - 1):
			draw_colored_polygon(capsule_pts(joints[i], joints[i + 1], radii[i] + w, radii[i + 1] + w), edge)
	for i in range(joints.size() - 1):
		draw_colored_polygon(capsule_pts(joints[i], joints[i + 1], radii[i], radii[i + 1]), fill)

func heart(c: Vector2, size: float, fill: Color, w: float = 0.0, rot: float = 0.0) -> void:
	if size < 0.4:
		return
	poly(heart_pts(c, size, rot), fill, w)

func sparkle(c: Vector2, size: float, fill: Color, rot: float = 0.0) -> void:
	if size < 0.4:
		return
	draw_colored_polygon(sparkle_pts(c, size, rot), fill)
