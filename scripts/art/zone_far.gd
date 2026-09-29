extends "res://scripts/art/soft_draw.gd"
## Distant layer of a zone (sky, sun or moon, far skyline). Lives under a Parallax2D so it drifts slower.

@export_enum("courtyard", "hallway", "rooftop") var style: String = "courtyard"
const W := 1700.0
const H := 340.0

func _draw() -> void:
	match style:
		"courtyard":
			_sky([[0.0, Color("8e8ad8")], [0.42, Color("e9b0d6")], [0.78, Color("ffc9c4")], [1.0, Color("ffe2c4")]])
			_sun(Vector2(760, 236), Color("fff3dc"))
			_clouds(Color(1.0, 0.95, 0.97, 0.8))
			_hills(Color("d7a7cf"), Color("c99ac4"))
		"hallway":
			_sky([[0.0, Color("b7a6e6")], [0.5, Color("f5bcd3")], [1.0, Color("ffdcc2")]])
			_sun(Vector2(900, 250), Color("fff3dc"))
			_clouds(Color(1.0, 0.96, 0.98, 0.85))
			# Treetops and roofs seen from the second floor.
			for i in range(18):
				var x := i * 100.0 + 20.0
				ellipse(Vector2(x, 300 + sin(i * 1.7) * 8.0), Vector2(70, 40), Color("f3a9c3") if i % 2 == 0 else Color("e893b2"))
			draw_rect(Rect2(0, 300, W, 60), Color("e893b2"))
		"rooftop":
			_sky([[0.0, Color("2f2c66")], [0.45, Color("7a5aa6")], [0.8, Color("e98fb0")], [1.0, Color("ffc4a8")]])
			for i in range(60):
				var p := Vector2(fmod(i * 197.0, W), fmod(i * 83.0, 190.0) + 10.0)
				draw_circle(p, 1.0 + (i % 3) * 0.5, Color(1, 1, 1, 0.5 + (i % 4) * 0.12), true, -1.0, true)
			draw_circle(Vector2(1180, 80), 30.0, Color("fff6e0"), true, -1.0, true)
			draw_circle(Vector2(1192, 72), 26.0, Color("403a78"), true, -1.0, true)
			_skyline()

func _sky(stops: Array) -> void:
	for i in range(stops.size() - 1):
		var y0: float = H * stops[i][0]
		var y1: float = H * stops[i + 1][0]
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(W, y0), Vector2(W, y1), Vector2(0, y1)]), PackedColorArray([c0, c0, c1, c1]))

func _sun(at: Vector2, col: Color) -> void:
	for i in range(6):
		draw_circle(at, 150.0 - i * 20.0, Color(1.0, 0.93, 0.8, 0.06 + i * 0.02), true, -1.0, true)
	draw_circle(at, 46.0, col, true, -1.0, true)
	for p: Vector2 in [Vector2(90, 40), Vector2(210, 88), Vector2(380, 30), Vector2(560, 64), Vector2(860, 44), Vector2(1130, 120), Vector2(1400, 50), Vector2(1600, 90)]:
		sparkle(p, 3.0, Color(1, 1, 1, 0.75))

func _clouds(col: Color) -> void:
	for c: Array in [[120.0, 70.0, 1.0], [520.0, 40.0, 0.8], [880.0, 96.0, 1.15], [1250.0, 60.0, 0.9], [1560.0, 110.0, 0.75]]:
		var at := Vector2(c[0], c[1])
		var s: float = c[2]
		for b: Array in [[-38, 6, 26, 14], [-12, -6, 30, 20], [20, 0, 28, 17], [44, 8, 20, 11]]:
			draw_colored_polygon(ellipse_pts(at + Vector2(b[0], b[1]) * s, Vector2(b[2], b[3]) * s, 24), col)
		draw_colored_polygon(ellipse_pts(at + Vector2(0, 10) * s, Vector2(64, 9) * s, 24), col)

func _hills(hill: Color, haze: Color) -> void:
	blob([-40, 340, -20, 262, 160, 244, 330, 270, 480, 250, 660, 262, 820, 242, 1000, 258, 1200, 236, 1400, 262, 1600, 244, 1760, 250, 1760, 340], hill, 0.0)
	for i in range(14):
		var x := i * 125.0 + 10.0
		var h := 50.0 + fmod(i * 37.0, 40.0)
		poly(rrect_pts(Rect2(x, 318 - h, 44 + fmod(i * 13.0, 30.0), h + 20), 4.0), haze, 0.0)
		for wy in range(int(318 - h) + 10, 318, 14):
			draw_rect(Rect2(x + 8, wy, 5, 6), Color(1.0, 0.9, 0.75, 0.35))
			draw_rect(Rect2(x + 22, wy, 5, 6), Color(1.0, 0.9, 0.75, 0.3))

func _skyline() -> void:
	var dark := Color("4a3a78")
	var mid := Color("6a4c8e")
	for layer in range(2):
		var col := mid if layer == 0 else dark
		for i in range(22):
			var x := i * 80.0 + layer * 37.0
			var h := 60.0 + fmod(i * 53.0 + layer * 31.0, 110.0) - layer * 20.0
			var r := Rect2(x, 330 - h, 56 + fmod(i * 17.0, 20.0), h + 20)
			draw_rect(r, col)
			for wy in range(int(r.position.y) + 10, 320, 13):
				for wx in range(int(r.position.x) + 7, int(r.end.x) - 6, 11):
					if int(wx * 7 + wy * 3) % 5 < 2:
						draw_rect(Rect2(wx, wy, 4, 5), Color(1.0, 0.85, 0.55, 0.75))
