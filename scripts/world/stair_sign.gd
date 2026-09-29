extends "res://scripts/art/soft_draw.gd"
## Signboard at a zone exit: a bobbing arrow pointing up or down the stairs, glowing as Minh Hân nears.

var heading: String = "up"
var side: float = 1.0
var label: String = ""
var near: float = 0.0
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var font: Font = preload("res://assets/fonts/ui_font.tres")
	var glow := near
	var base := Vector2(0, 350)
	chain([base, base + Vector2(0, -64)], [2.6, 2.2], Color("8c6078"), 1.2)
	var board := Rect2(-44, -130 + 350, 88, 58)
	if glow > 0.01:
		draw_colored_polygon(rrect_pts(board.grow(8.0 + 3.0 * sin(_t * 6.0)), 18.0), Color(1.0, 0.85, 0.5, 0.35 * glow))
	poly(rrect_pts(board, 12.0), Color("fffaf4"), 2.2, Color("b06080"))
	var bob := sin(_t * 5.0) * 3.0
	var ang := -PI / 4 if heading == "up" else PI / 4
	if side < 0:
		ang = PI - ang
	var c := board.get_center() + Vector2.from_angle(ang) * bob
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	var arrow := PackedVector2Array([c + d * 16, c + n * 12, c + n * 5, c - d * 14 + n * 5, c - d * 14 - n * 5, c - n * 5, c - n * 12])
	poly(arrow, Color("ff6f97"), 1.8, Color("b04a70"))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var pill := Rect2(-w / 2 - 10, board.end.y + 6, w + 20, 20)
	poly(rrect_pts(pill, 10.0), Color("ff7fa2"), 0.0)
	draw_string(font, Vector2(-w / 2, pill.position.y + 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
