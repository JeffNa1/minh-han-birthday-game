extends "res://scripts/art/soft_draw.gd"
## Near scenery of a zone, drawn once across the zone's full width. The far layer shows through
## wherever this layer leaves gaps (the sky above the courtyard, the hallway windows).

const HORIZON := 318.0
const UI_FONT := preload("res://assets/fonts/ui_font.tres")

@export_enum("courtyard", "hallway", "rooftop") var style: String = "courtyard"
@export var width: float = 2000.0

func _ready() -> void:
	z_index = -20

func _draw() -> void:
	match style:
		"courtyard": _courtyard()
		"hallway": _hallway()
		"rooftop": _rooftop()

# ---------------------------------------------------------------- shared pieces

func _gradient(rect: Rect2, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var y0: float = rect.position.y + rect.size.y * stops[i][0]
		var y1: float = rect.position.y + rect.size.y * stops[i + 1][0]
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		draw_polygon(PackedVector2Array([Vector2(rect.position.x, y0), Vector2(rect.end.x, y0), Vector2(rect.end.x, y1), Vector2(rect.position.x, y1)]), PackedColorArray([c0, c0, c1, c1]))

func _font() -> Font:
	return UI_FONT

func _label(center: Vector2, text: String, size: int, col: Color) -> void:
	var w := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font(), center + Vector2(-w / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _lights(y: float, span: float, sag: float, colors: Array) -> void:
	var x := 0.0
	while x < width:
		var a := Vector2(x, y)
		var b := Vector2(minf(x + span, width), y)
		var cable := PackedVector2Array()
		for i in range(21):
			var t := float(i) / 20.0
			cable.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
		draw_polyline(cable, Color("7b5470"), 1.4, true)
		for i in range(2, 20, 2):
			var p: Vector2 = cable[i] + Vector2(0, 5)
			var col: Color = colors[(i / 2 + int(x / span)) % colors.size()]
			draw_circle(p, 9.0, Color(col, 0.18), true, -1.0, true)
			draw_circle(p, 4.5, Color(col, 0.4), true, -1.0, true)
			draw_circle(p, 2.6, col.lightened(0.4), true, -1.0, true)
		x += span

func _tree(base: Vector2, s: float, flip: float) -> void:
	draw_set_transform(base, 0.0, Vector2(s * flip, s))
	blob([-12, 0, -9, -60, -22, -110, -12, -114, 0, -75, 14, -124, 24, -120, 10, -60, 14, 0], Color("9a6474"), 2.0, Color("6e4054"))
	var pinks := [Color("f6a9c0"), Color("f9bfd0"), Color("f18fad"), Color("ffd6e2")]
	var blobs := [[-60, -150, 58, 46], [10, -175, 70, 52], [70, -135, 55, 42], [-20, -120, 60, 40], [40, -110, 50, 34], [-80, -115, 40, 32], [-30, -190, 45, 36]]
	for i in range(blobs.size()):
		var b: Array = blobs[i]
		ellipse(Vector2(b[0], b[1]), Vector2(b[2], b[3]), pinks[2] if i % 3 == 0 else pinks[0], 2.0, Color("d77595"))
	for i in range(blobs.size()):
		var b: Array = blobs[i]
		ellipse(Vector2(b[0] - b[2] * 0.15, b[1] - b[3] * 0.25), Vector2(b[2] * 0.62, b[3] * 0.5), pinks[1])
	for i in range(26):
		draw_circle(Vector2(sin(i * 2.7) * 90.0, -150.0 + cos(i * 1.9) * 55.0), 3.0, pinks[3], true, -1.0, true)
	draw_set_transform(Vector2.ZERO)

func _lamp(x: float, ground: float) -> void:
	for i in range(4):
		draw_circle(Vector2(x, ground - 78), 30.0 - i * 6.0, Color(1.0, 0.9, 0.7, 0.08 + i * 0.05), true, -1.0, true)
	chain([Vector2(x, ground), Vector2(x, ground - 72)], [3.0, 2.4], Color("6d4a62"), 1.2)
	blob([x - 9, ground - 70, x - 7, ground - 86, x + 7, ground - 86, x + 9, ground - 70], Color("fff1cf"), 1.6, Color("6d4a62"))
	blob([x - 11, ground - 86, x, ground - 96, x + 11, ground - 86], Color("6d4a62"), 0.0)

func _plant(at: Vector2, s: float) -> void:
	draw_set_transform(at, 0.0, Vector2.ONE * s)
	for i in range(7):
		var a := -PI / 2 + (i - 3) * 0.32
		chain([Vector2(0, -20), Vector2(0, -20) + Vector2.from_angle(a) * 34.0], [4.0, 1.0], Color("7fbf98"), 1.2)
	poly(pts([-16, -22, 16, -22, 12, 6, -12, 6]), Color("f2a78f"), 1.8)
	draw_rect(Rect2(-17, -25, 34, 5), Color("e48f78"))
	draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- courtyard

func _courtyard() -> void:
	_tree(Vector2(90, 336), 1.0, 1.0)
	_academy(Vector2(300, 0))
	_tree(Vector2(1150, 336), 0.95, -1.0)
	_stall(Vector2(1250, 348), Color("ff8fab"), "TRÀ SỮA")
	_stall(Vector2(1480, 348), Color("8fcfe0"), "BÁNH KEM")
	_tree(Vector2(1770, 336), 1.05, 1.0)
	_stair_building()
	_fence(150, 1900)
	_ground(Color("f9dfd6"), Color("eab9bf"))
	for x: float in [240.0, 1040.0, 1700.0]:
		_lamp(x, 342)
	_lights(150, 480, 46, [Color("ffe08a"), Color("ffb3c8"), Color("bfe3ff")])
	for x: float in [30.0, 1990.0]:
		ellipse(Vector2(x, 540), Vector2(70, 34), Color("93c8aa"), 2.0, Color("5f937a"))

func _academy(o: Vector2) -> void:
	var wall := Color("fcefe8")
	var roof := Color("e4879f")
	var trim := Color("f7d9dc")
	var glass := Color("b9cdee")
	var edge := Color("b98aa0")
	var roof_edge := Color("a95a76")
	for x0: float in [248.0 + o.x, 562.0 + o.x]:
		poly(rrect_pts(Rect2(x0, 214, 150, 106), 3.0), wall, 2.0, edge)
		blob([x0 - 10, 216, x0 + 20, 190, x0 + 130, 190, x0 + 160, 216], roof, 2.0, roof_edge)
		for row in range(2):
			for col in range(4):
				var r := Rect2(x0 + 16 + col * 33, 228 + row * 40, 20, 28)
				poly(rrect_pts(r, 8.0), glass, 1.6, Color("9a7c98"))
				draw_rect(Rect2(r.position.x + 3, r.position.y + 5, 5, 12), Color(1, 1, 1, 0.45))
				draw_rect(Rect2(r.position.x - 2, r.end.y, r.size.x + 4, 3), trim)
	var cx := 480.0 + o.x
	poly(rrect_pts(Rect2(cx - 82, 190, 164, 130), 3.0), wall, 2.0, edge)
	blob([cx - 92, 194, cx - 60, 166, cx + 60, 166, cx + 92, 194], roof, 2.0, roof_edge)
	poly(rrect_pts(Rect2(cx - 34, 110, 68, 70), 4.0), wall, 2.0, edge)
	blob([cx - 44, 114, cx, 62, cx + 44, 114], roof, 2.0, roof_edge)
	draw_circle(Vector2(cx, 142), 21.0, edge, true, -1.0, true)
	draw_circle(Vector2(cx, 142), 19.0, Color("fffaf3"), true, -1.0, true)
	for i in range(12):
		draw_circle(Vector2(cx, 142) + Vector2.from_angle(TAU * i / 12.0) * 15.0, 1.3, Color("c79aac"), true, -1.0, true)
	draw_line(Vector2(cx, 142), Vector2(cx, 130), Color("7b4a64"), 2.2, true)
	draw_line(Vector2(cx, 142), Vector2(cx + 9, 146), Color("7b4a64"), 2.2, true)
	heart(Vector2(cx, 86), 5.0, Color("fff3f6"))
	blob([cx - 30, 320, cx - 30, 262, cx - 14, 244, cx + 14, 244, cx + 30, 262, cx + 30, 320], Color("c77a92"), 2.0, Color("8c4f68"))
	draw_line(Vector2(cx, 250), Vector2(cx, 320), Color("a55e7a"), 2.0, true)
	for x: float in [cx - 68, cx + 50]:
		poly(rrect_pts(Rect2(x, 238, 18, 34), 8.0), glass, 1.6, Color("9a7c98"))
	line([cx - 180, 206, cx - 80, 222, cx, 226, cx + 80, 222, cx + 180, 206], Color("b06080"), 1.6)
	for i in range(15):
		var t := float(i) / 14.0
		var x := lerpf(cx - 174, cx + 174, t)
		var y := 207.0 + sin(t * PI) * 18.0
		var c: Color = [Color("ff8fab"), Color("fff1c7"), Color("a8d8ea"), Color("c9b6ff")][i % 4]
		poly(PackedVector2Array([Vector2(x - 8, y), Vector2(x + 8, y), Vector2(x, y + 15)]), c, 1.2, Color("b06080"))
	var banner := Rect2(cx - 78, 196, 156, 26)
	poly(rrect_pts(banner, 12.0), Color("ff7fa2"), 2.0, Color("b04a70"))
	_label(banner.get_center(), "HAPPY BIRTHDAY", 13, Color("fffaf2"))

func _stall(base: Vector2, color: Color, title: String) -> void:
	var x := base.x
	var y := base.y
	poly(rrect_pts(Rect2(x, y - 70, 180, 70), 4.0), Color("fff4ec"), 2.0, Color("b98aa0"))
	for i in range(6):
		var sx := x - 6 + i * 32.0
		blob([sx, y - 96, sx + 32, y - 96, sx + 32, y - 84, sx + 16, y - 74, sx, y - 84], color if i % 2 == 0 else Color("fffaf4"), 1.6, color.darkened(0.3))
	draw_rect(Rect2(x - 8, y - 104, 196, 10), color.darkened(0.1))
	poly(rrect_pts(Rect2(x + 30, y - 128, 120, 26), 10.0), Color("fffaf4"), 1.8, color.darkened(0.3))
	_label(Vector2(x + 90, y - 115), title, 12, color.darkened(0.35))
	draw_rect(Rect2(x + 8, y - 44, 164, 8), Color("f6d9cf"))
	for i in range(5):
		var p := Vector2(x + 26 + i * 32, y - 50)
		if title == "TRÀ SỮA":
			poly(pts([p.x - 7, p.y - 16, p.x + 7, p.y - 16, p.x + 5, p.y, p.x - 5, p.y]), Color("f3d6b8"), 1.4, Color("b98a70"))
			draw_line(p + Vector2(2, -16), p + Vector2(5, -25), Color("ff8fab"), 2.0, true)
			for k in range(3):
				draw_circle(p + Vector2(-2 + k * 2, -3), 1.4, Color("5c3b35"), true, -1.0, true)
		else:
			ellipse(p + Vector2(0, -6), Vector2(11, 7), Color("fff0e6"), 1.4, Color("d99aa8"))
			ellipse(p + Vector2(0, -10), Vector2(11, 4), Color("ffc2d4"))
			draw_circle(p + Vector2(0, -15), 2.4, Color("e8475f"), true, -1.0, true)

func _stair_building() -> void:
	var x0 := 1880.0
	var wall := Color("fbe7e2")
	poly(rrect_pts(Rect2(x0, 120, width - x0 + 20, 220), 3.0), wall, 2.0, Color("b98aa0"))
	blob([x0 - 12, 124, x0 + 20, 96, width + 30, 96, width + 30, 124], Color("e4879f"), 2.0, Color("a95a76"))
	for i in range(3):
		poly(rrect_pts(Rect2(x0 + 30 + i * 90, 150, 44, 50), 10.0), Color("b9cdee"), 1.6, Color("9a7c98"))
	# Second-floor door the staircase climbs to.
	poly(rrect_pts(Rect2(width - 110, 140, 56, 74), 8.0), Color("c77a92"), 2.0, Color("8c4f68"))
	draw_circle(Vector2(width - 64, 180), 2.6, Color("ffe6a8"), true, -1.0, true)
	# The staircase: steps rising from the plaza toward that door.
	var steps := 9
	for i in range(steps):
		var t := float(i) / steps
		var sx := lerpf(1960.0, width - 120.0, t)
		var sy := lerpf(336.0, 214.0, t)
		poly(pts([sx, sy, sx + 34, sy, sx + 34, sy + 14, sx, sy + 14]), Color("efd3d6"), 1.4, Color("b98aa0"))
	line([1960, 300, width - 90, 180], Color("8c6078"), 2.2)
	for i in range(8):
		var t := float(i) / 7.0
		var p := Vector2(1960, 300).lerp(Vector2(width - 90, 180), t)
		draw_line(p, p + Vector2(0, 30), Color("8c6078"), 1.6, true)

func _fence(from_x: float, to_x: float) -> void:
	var x := from_x
	while x < to_x:
		if absf(x - 780.0) > 40.0:
			poly(PackedVector2Array([Vector2(x, 330), Vector2(x, 302), Vector2(x + 4, 296), Vector2(x + 8, 302), Vector2(x + 8, 330)]), Color("fffaf6"), 1.4, Color("c9a7b5"))
		x += 16.0
	var green := Color("a6d3b8")
	x = from_x - 20.0
	var i := 0
	while x < to_x:
		if absf(x - 780.0) > 60.0:
			ellipse(Vector2(x, 330), Vector2(34, 18), green, 2.0, Color("6e9e86"))
			ellipse(Vector2(x - 6, 325), Vector2(20, 9), green.lightened(0.18))
			for k in range(3):
				draw_circle(Vector2(x - 16 + k * 14, 322 + (k % 2) * 6), 2.6, [Color("fff6f8"), Color("ffc2d4"), Color("ffe7a8")][(k + i) % 3], true, -1.0, true)
		x += 52.0
		i += 1

func _ground(top: Color, bottom: Color) -> void:
	_gradient(Rect2(0, HORIZON + 10, width, 540 - HORIZON - 10), [[0.0, top], [1.0, bottom]])
	var y := HORIZON + 26.0
	var gap := 12.0
	while y < 540:
		draw_line(Vector2(0, y), Vector2(width, y), Color(0.85, 0.62, 0.66, 0.2), 1.2, true)
		y += gap
		gap *= 1.28
	var x := 60.0
	while x < width:
		draw_line(Vector2(x, HORIZON + 26), Vector2(x - 40, 540), Color(0.85, 0.62, 0.66, 0.14), 1.2, true)
		x += 140.0
	for k in range(int(width / 700.0) + 1):
		ellipse(Vector2(350 + k * 700, 440), Vector2(300, 60), Color(1, 0.97, 0.92, 0.2))
	for k in range(int(width / 32.0)):
		var p := Vector2(fmod(k * 173.0 + 40.0, width), 350.0 + fmod(k * 67.0, 180.0))
		heart(p, 3.0, Color(1.0, 0.72, 0.8, 0.5), 0.0, k * 0.7)

# ---------------------------------------------------------------- hallway

func _hallway() -> void:
	var wall := Color("fdf0ea")
	var wains := Color("f4c7d0")
	var ceiling := Color("f6e2e6")
	_gradient(Rect2(0, 0, width, 64), [[0.0, ceiling.darkened(0.05)], [1.0, ceiling]])
	# Wall with window openings every 300px.
	var win_w := 150.0
	var cursor := 0.0
	var windows: Array = []
	var x := 170.0
	while x + win_w < width - 150.0:
		windows.append(x)
		x += 300.0
	for wx: float in windows:
		draw_rect(Rect2(cursor, 64, wx - cursor, 230), wall)
		cursor = wx + win_w
	draw_rect(Rect2(cursor, 64, width - cursor, 230), wall)
	for wx: float in windows:
		draw_rect(Rect2(wx, 64, win_w, 26), wall)
		draw_rect(Rect2(wx, 250, win_w, 44), wall)
		draw_rect(Rect2(wx - 6, 84, win_w + 12, 6), Color("ffffff"))
		draw_rect(Rect2(wx - 6, 250, win_w + 12, 8), Color("ffffff"))
		draw_rect(Rect2(wx - 6, 84, 6, 172), Color("ffffff"))
		draw_rect(Rect2(wx + win_w, 84, 6, 172), Color("ffffff"))
		draw_rect(Rect2(wx + win_w / 2 - 2, 90, 4, 160), Color("ffffff"))
		draw_rect(Rect2(wx, 164, win_w, 4), Color("ffffff"))
		# Curtains.
		blob([wx - 14, 78, wx + 22, 78, wx + 14, 170, wx + 24, 262, wx - 16, 262], Color("ffb3c6"), 1.6, Color("d7839a"))
		blob([wx + win_w + 14, 78, wx + win_w - 22, 78, wx + win_w - 14, 170, wx + win_w - 24, 262, wx + win_w + 16, 262], Color("ffb3c6"), 1.6, Color("d7839a"))
		draw_rect(Rect2(wx - 20, 74, win_w + 40, 6), Color("c98ca0"))
	# Doors, notice boards and lockers between the windows.
	for i in range(windows.size() - 1):
		var mid: float = (windows[i] + win_w + windows[i + 1]) / 2.0
		match i % 3:
			0: _door(mid, "12A%d" % (i / 3 + 1))
			1: _board(mid)
			2: _lockers(mid)
	# Wainscot and floor.
	draw_rect(Rect2(0, 294, width, 42), wains)
	draw_rect(Rect2(0, 292, width, 5), Color("fffaf8"))
	draw_rect(Rect2(0, 334, width, 6), Color("d99aa8"))
	_gradient(Rect2(0, 340, width, 200), [[0.0, Color("f0cdb2")], [1.0, Color("dea88f")]])
	var y := 352.0
	var gap := 14.0
	while y < 540:
		draw_line(Vector2(0, y), Vector2(width, y), Color(0.72, 0.48, 0.4, 0.25), 1.2, true)
		y += gap
		gap *= 1.25
	for wx: float in windows:
		poly(pts([wx - 10, 342, wx + win_w + 10, 342, wx + win_w + 60, 540, wx + 30, 540]), Color(1, 0.95, 0.85, 0.2), 0.0)
	# Ceiling lamps.
	var lx := 100.0
	while lx < width:
		draw_line(Vector2(lx, 0), Vector2(lx, 30), Color("b99aa8"), 1.5, true)
		blob([lx - 22, 30, lx + 22, 30, lx + 14, 44, lx - 14, 44], Color("fffaf0"), 1.6, Color("c9a7b5"))
		draw_circle(Vector2(lx, 50), 24.0, Color(1, 0.95, 0.8, 0.18), true, -1.0, true)
		lx += 300.0
	_lights(70, 500, 30, [Color("ffb3c8"), Color("fff1b8"), Color("c9b6ff")])
	# Stairwells at both ends.
	_stairwell(0.0, true)
	_stairwell(width - 130.0, false)
	for p: float in [140.0, width - 170.0]:
		_plant(Vector2(p, 350), 1.0)

func _door(cx: float, plate: String) -> void:
	poly(rrect_pts(Rect2(cx - 38, 150, 76, 146), 4.0), Color("d9a88c"), 2.0, Color("8c5a4a"))
	poly(rrect_pts(Rect2(cx - 28, 162, 56, 40), 4.0), Color("cfe0f5"), 1.6, Color("8c5a4a"))
	draw_circle(Vector2(cx + 26, 230), 3.0, Color("f2d28c"), true, -1.0, true)
	poly(rrect_pts(Rect2(cx - 30, 120, 60, 20), 6.0), Color("fffaf4"), 1.6, Color("b98aa0"))
	_label(Vector2(cx, 130), plate, 12, Color("a0506e"))

func _board(cx: float) -> void:
	poly(rrect_pts(Rect2(cx - 70, 130, 140, 100), 6.0), Color("e6c49c"), 2.0, Color("a57b58"))
	var notes := [[-52, 142, Color("fff6b8")], [-8, 138, Color("ffd0dc")], [30, 146, Color("cde8ff")], [-44, 186, Color("d6f5dc")], [8, 182, Color("fff0f4")]]
	for n: Array in notes:
		poly(rrect_pts(Rect2(cx + n[0], n[1], 34, 36), 2.0), n[2], 1.2, Color("c9a7b5"))
		draw_circle(Vector2(cx + n[0] + 17, n[1] + 3), 2.2, Color("e8475f"), true, -1.0, true)
	heart(Vector2(cx - 35, 164), 7.0, Color("ff7fa2"))
	heart(Vector2(cx + 25, 202), 6.0, Color("ff7fa2"))
	_label(Vector2(cx + 9, 158), "HBD", 10, Color("c9446c"))

func _lockers(cx: float) -> void:
	for i in range(3):
		var r := Rect2(cx - 60 + i * 40, 150, 38, 144)
		poly(rrect_pts(r, 3.0), [Color("a9d6e5"), Color("c3b6f0"), Color("ffc2cf")][i], 1.8, Color("7a7a9a"))
		for k in range(3):
			draw_line(Vector2(r.position.x + 8, 162 + k * 5), Vector2(r.end.x - 8, 162 + k * 5), Color(0, 0, 0, 0.15), 1.4, true)
		draw_rect(Rect2(r.end.x - 9, 214, 3, 14), Color("fbfbfb"))

func _stairwell(x0: float, up: bool) -> void:
	draw_rect(Rect2(x0, 64, 130, 276), Color("f3dde2"))
	draw_rect(Rect2(x0 + (128.0 if up else 0.0), 64, 2, 276), Color("d6b3c0"))
	for i in range(8):
		var t := float(i) / 8.0
		var sy := lerpf(330.0, 120.0, t) if up else lerpf(210.0, 336.0, t)
		var sx := x0 + (lerpf(110.0, 10.0, t) if up else lerpf(10.0, 110.0, t))
		poly(pts([sx - 16, sy, sx + 16, sy, sx + 16, sy + 12, sx - 16, sy + 12]), Color("fbf1f3"), 1.2, Color("c9a7b5"))
	line([x0 + 120, 300, x0 + 10, 100] if up else [x0 + 10, 180, x0 + 120, 306], Color("a47a90"), 2.2)

# ---------------------------------------------------------------- rooftop

func _rooftop() -> void:
	# Parapet, railing and fairy lights; the city sky shows above.
	draw_rect(Rect2(0, 292, width, 48), Color("e9d6e8"))
	draw_rect(Rect2(0, 288, width, 6), Color("fff6fb"))
	for x in range(0, int(width), 24):
		draw_line(Vector2(x, 230), Vector2(x, 290), Color("8d7aa8"), 2.0, true)
	draw_line(Vector2(0, 230), Vector2(width, 230), Color("8d7aa8"), 3.0, true)
	var x := 0.0
	while x < width:
		var cable := PackedVector2Array()
		for i in range(13):
			var t := float(i) / 12.0
			cable.append(Vector2(x + t * 200.0, 232.0 + sin(t * PI) * 22.0))
		draw_polyline(cable, Color("5c4a7a"), 1.2, true)
		for i in range(1, 12, 2):
			draw_circle(cable[i] + Vector2(0, 4), 7.0, Color(1.0, 0.88, 0.6, 0.25), true, -1.0, true)
			draw_circle(cable[i] + Vector2(0, 4), 2.6, Color("fff1b8"), true, -1.0, true)
		x += 200.0
	_gradient(Rect2(0, 340, width, 200), [[0.0, Color("e8d8ee")], [1.0, Color("cdb6d8")]])
	var y := 354.0
	var gap := 14.0
	while y < 540:
		draw_line(Vector2(0, y), Vector2(width, y), Color(0.55, 0.42, 0.62, 0.2), 1.2, true)
		y += gap
		gap *= 1.25
	x = 40.0
	while x < width:
		draw_line(Vector2(x, 340), Vector2(x - 50, 540), Color(0.55, 0.42, 0.62, 0.14), 1.2, true)
		x += 120.0
	# Stairwell hut on the left.
	poly(rrect_pts(Rect2(-10, 150, 180, 190), 4.0), Color("f3e4f0"), 2.0, Color("9a7cae"))
	blob([-20, 156, 10, 130, 170, 130, 190, 156], Color("b68ccf"), 2.0, Color("7d5aa0"))
	poly(rrect_pts(Rect2(50, 214, 66, 126), 6.0), Color("9d86c4"), 2.0, Color("6a5290"))
	draw_circle(Vector2(104, 280), 3.0, Color("ffe6a8"), true, -1.0, true)
	# Balloon arch with the birthday banner.
	var cx := width * 0.55
	for i in range(19):
		var a := PI + PI * i / 18.0
		var p := Vector2(cx, 330) + Vector2(cos(a) * 170.0, sin(a) * 150.0)
		dot(p, 13.0, [Color("ff8fab"), Color("fff1c7"), Color("c9b6ff"), Color("a8e0f0")][i % 4], 1.4)
		draw_circle(p + Vector2(-4, -4), 3.0, Color(1, 1, 1, 0.6), true, -1.0, true)
	var banner := Rect2(cx - 130, 200, 260, 34)
	poly(rrect_pts(banner, 16.0), Color("ff7fa2"), 2.0, Color("b04a70"))
	_label(banner.get_center(), "HAPPY BIRTHDAY MINH HÂN", 14, Color("fffaf2"))
	# Picnic corner, benches, plants, water tank.
	poly(pts([cx - 110, 360, cx + 110, 360, cx + 150, 400, cx - 150, 400]), Color("ffc2d4"), 1.6, Color("d7839a"))
	for k in range(5):
		draw_line(Vector2(cx - 110 + k * 55, 360), Vector2(cx - 150 + k * 75, 400), Color(1, 1, 1, 0.6), 2.0, true)
	poly(rrect_pts(Rect2(cx - 20, 346, 40, 24), 6.0), Color("fff4ec"), 1.6, Color("b98aa0"))
	heart(Vector2(cx, 350), 6.0, Color("ff5f8f"))
	for bx: float in [360.0, width - 380.0]:
		poly(rrect_pts(Rect2(bx - 55, 318, 110, 10), 3.0), Color("c89a78"), 1.6, Color("8c5a4a"))
		poly(rrect_pts(Rect2(bx - 55, 296, 110, 10), 3.0), Color("c89a78"), 1.6, Color("8c5a4a"))
		draw_line(Vector2(bx - 45, 328), Vector2(bx - 45, 350), Color("8c5a4a"), 3.0, true)
		draw_line(Vector2(bx + 45, 328), Vector2(bx + 45, 350), Color("8c5a4a"), 3.0, true)
	for p: float in [230.0, 520.0, width - 250.0, width - 90.0]:
		_plant(Vector2(p, 352), 1.1)
	poly(rrect_pts(Rect2(width - 200, 120, 90, 110), 30.0), Color("c7d3e6"), 2.0, Color("7b87a6"))
	for lx: float in [width - 195, width - 125]:
		draw_line(Vector2(lx, 220), Vector2(lx, 290), Color("7b87a6"), 3.0, true)
