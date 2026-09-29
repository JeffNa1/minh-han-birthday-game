extends Control
## Picture of a prize or shop item: a live mini Minh Hân for outfits and hairstyles,
## a ribbon sample for beams, a coin stack or a diamond for currency.

const Kit := preload("res://scripts/art/soft_draw.gd")
const Catalog := preload("res://scripts/data/catalog.gd")
const RIG := preload("res://scripts/entities/character_rig.gd")
const PET := preload("res://scripts/entities/pet.gd")

var kind: String = ""
var id: String = ""
var amount: int = 0
var glow: float = 0.0
var _rig: Node2D
var _t: float = 0.0

func show_item(item_kind: String, item_id: String = "", item_amount: int = 0) -> void:
	kind = item_kind
	id = item_id
	amount = item_amount
	if is_instance_valid(_rig):
		_rig.queue_free()
		_rig = null
	if kind in ["outfit", "hair", "hat", "wings", "aura"]:
		_rig = RIG.new()
		_rig.character = "minh_han"
		add_child(_rig)
		if _rig.is_node_ready():
			_configure_rig()
		else:
			_rig.ready.connect(_configure_rig, CONNECT_ONE_SHOT)
	queue_redraw()

func _ready() -> void:
	resized.connect(_layout)

## Dresses the preview once it exists, then poses it and leaves it still: a grid of these costs
## nothing per frame.
func _configure_rig() -> void:
	_rig.apply_look(Profile.look())
	match kind:
		"outfit":
			_rig.set_outfit(id)
		"hair":
			_rig.apply_look({"hair": id})
		_:
			_rig.set_outfit(Profile.equipped["outfit"])
			_rig.set_gear(kind, id)
	_rig.advance_pose(0.5)
	_rig.set_process(false)
	_layout()

func _layout() -> void:
	if is_instance_valid(_rig):
		var s := size.y / 175.0
		_rig.scale = Vector2.ONE * s
		_rig.position = Vector2(size.x / 2.0, size.y - 4.0)

func _process(delta: float) -> void:
	# Only beams, pets and glowing prizes move; everything else stays a still picture.
	if kind not in ["beam", "pet"] and glow <= 0.0:
		return
	_t += delta
	queue_redraw()

static func draw_coin(canvas: CanvasItem, c: Vector2, r: float) -> void:
	canvas.draw_circle(c + Vector2(0, r * 0.12), r, Color("c98a1e"), true, -1.0, true)
	canvas.draw_circle(c, r, Color("ffd24a"), true, -1.0, true)
	canvas.draw_circle(c, r * 0.72, Color("ffe487"), true, -1.0, true)
	canvas.draw_colored_polygon(Kit.heart_pts(c + Vector2(0, -r * 0.05), r * 0.5), Color("f0a92a"))
	canvas.draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.16, Color(1, 1, 1, 0.8), true, -1.0, true)

static func draw_gem(canvas: CanvasItem, c: Vector2, r: float) -> void:
	var top := [c + Vector2(-r, -r * 0.3), c + Vector2(-r * 0.55, -r * 0.8), c + Vector2(r * 0.55, -r * 0.8), c + Vector2(r, -r * 0.3)]
	var body := PackedVector2Array([top[0], top[1], top[2], top[3], c + Vector2(0, r)])
	canvas.draw_colored_polygon(body, Color("5ad1f5"))
	canvas.draw_colored_polygon(PackedVector2Array([top[0], top[3], c + Vector2(0, r)]), Color("32a8e0"))
	canvas.draw_colored_polygon(PackedVector2Array([top[1], top[2], c + Vector2(r * 0.3, -r * 0.3), c + Vector2(-r * 0.3, -r * 0.3)]), Color("b8f0ff"))
	var edge := body.duplicate()
	edge.append(body[0])
	canvas.draw_polyline(edge, Color("1b7fb3"), 1.4, true)

func _draw() -> void:
	var c := size / 2.0
	if glow > 0.0:
		for i in range(8):
			var a := _t * 0.6 + TAU * i / 8.0
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.12) * size.x * 0.7, c + Vector2.from_angle(a + 0.12) * size.x * 0.7]), Color(1.0, 0.9, 0.5, 0.25 * glow))
		draw_circle(c, size.x * 0.38, Color(1.0, 0.95, 0.75, 0.35 * glow), true, -1.0, true)
	match kind:
		"pet":
			if id != "none":
				draw_set_transform(Vector2(size.x / 2.0, size.y * 0.78), 0.0, Vector2.ONE * size.y / 60.0)
				PET.draw_pet(self, id, _t)
				draw_set_transform(Vector2.ZERO)
		"coins":
			for i in range(3):
				draw_coin(self, c + Vector2(-12 + i * 12, 8 - i * 7), size.x * 0.2)
		"gems":
			draw_gem(self, c + Vector2(-10, 6), size.x * 0.17)
			draw_gem(self, c + Vector2(10, -4), size.x * 0.22)
		"beam":
			var b: Dictionary = Catalog.BEAMS[id]
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in range(16):
				var k := float(i) / 15.0
				pts.append(Vector2(lerpf(8.0, size.x - 8.0, k), c.y + sin(k * TAU + _t * 4.0) * 8.0))
				cols.append(Color.from_hsv(fmod(k + _t * 0.3, 1.0), 0.55, 1.0) if b.get("rainbow", false) else b["main"])
			draw_polyline_colors(pts, cols, 10.0, true)
			draw_polyline(pts, b["soft"], 3.0, true)
			for i in range(3):
				var p: Vector2 = pts[4 + i * 4]
				match b["shape"]:
					"star": draw_colored_polygon(Kit.sparkle_pts(p, 7.0, _t * 2.0), Color("fffbe8"))
					"bubble": draw_arc(p, 6.0, 0.0, TAU, 16, Color.WHITE, 1.6, true)
					"petal": draw_colored_polygon(Kit.ellipse_pts(p, Vector2(6, 4), 12), Color("fff0f6"))
					"note": draw_circle(p, 4.0, Color.WHITE, true, -1.0, true)
					_: draw_colored_polygon(Kit.heart_pts(p, 6.0), Color("fff6f9"))
