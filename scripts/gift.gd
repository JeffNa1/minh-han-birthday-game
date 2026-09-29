extends Control
## Between levels: pick one of five gift boxes. The gift is drawn from the marble bag before any box
## is chosen, so every box holds the same real prize. After opening, the other boxes show "what could
## have been": when the real gift is not an outfit, a box beside the chosen one shows a rare outfit.

const Fx := preload("res://scripts/vfx/fx.gd")
const Catalog := preload("res://scripts/data/catalog.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")
const Kit := preload("res://scripts/art/soft_draw.gd")
const BOX_COLORS := [Color("ff8fab"), Color("a8d8ea"), Color("c9b6ff"), Color("ffd27a"), Color("a6e3b8")]

@onready var boxes_layer: Control = $Boxes
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var prize_label: Label = $PrizeLabel
@onready var continue_btn: Button = $ContinueBtn
@onready var wear_btn: Button = $WearBtn
@onready var mine_tag: Label = $MineTag

var prize: Dictionary = {}
var decoys: Array = []
var chosen: int = -1
var _boxes: Array = []
var _t: float = 0.0

func _ready() -> void:
	# The outcome is fixed before the player sees the boxes.
	prize = Profile.roll_gift()
	subtitle.text = "Qua màn %d · +%d xu" % [GameManager.level, GameManager.last_reward]
	prize_label.modulate.a = 0.0
	continue_btn.visible = false
	mine_tag.visible = false
	wear_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	wear_btn.pressed.connect(_on_wear)
	for i in range(5):
		var box := Control.new()
		box.size = Vector2(130, 150)
		box.position = Vector2(55 + i * 175, 190)
		box.pivot_offset = Vector2(65, 140)
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.set_meta("open", 0.0)
		box.set_meta("hover", 0.0)
		box.draw.connect(_draw_box.bind(box, i))
		box.gui_input.connect(_on_box_input.bind(i))
		box.mouse_entered.connect(_on_box_hover)
		boxes_layer.add_child(box)
		var icon: Control = ItemIcon.new()
		icon.size = Vector2(110, 120)
		icon.position = Vector2(10, -10)
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		_boxes.append(box)
	decoys = _make_decoys()

## Teasers for the unopened boxes. A miss always shows a rare outfit right next to the chosen box,
## preferably one of the full-set gowns, and another box flashes a special wing, aura or pet.
func _make_decoys() -> Array:
	var not_won := func(kind: String, id: String) -> bool: return prize.get("id", "") != id and id != "none"
	var outfits: Array = Catalog.ids("outfit").filter(func(id: String) -> bool: return not_won.call("outfit", id) and not Profile.owns("outfit", id))
	var gowns: Array = outfits.filter(func(id: String) -> bool: return Catalog.is_special("outfit", id))
	var showpieces: Array = []
	for kind: String in ["wings", "aura", "pet", "hat"]:
		for id: String in Catalog.ids(kind):
			if Catalog.is_special(kind, id) and not_won.call(kind, id):
				showpieces.append({"kind": kind, "id": id})
	var pool := [{"kind": "gems", "amount": 25}, {"kind": "coins", "amount": 300}, {"kind": "gems", "amount": 12},
		{"kind": "hair", "id": Catalog.ids("hair").pick_random()}]
	pool.shuffle()
	var out: Array = pool.slice(0, 4)
	if not showpieces.is_empty():
		out[1] = showpieces.pick_random()
	if prize["kind"] != "outfit":
		var tease: Array = gowns if not gowns.is_empty() else (outfits if not outfits.is_empty() else Catalog.ids("outfit"))
		out[0] = {"kind": "outfit", "id": tease.pick_random()}
	return out

func _on_box_input(event: InputEvent, index: int) -> void:
	if chosen >= 0 or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	chosen = index
	_open_sequence()

func _open_sequence() -> void:
	var box: Control = _boxes[chosen]
	AudioManager.play_sfx("click")
	title.text = "Đang mở…"
	# Build-up: the chosen box shakes harder and harder.
	var shake := create_tween()
	for i in range(8):
		var a := 0.06 + i * 0.012
		shake.tween_property(box, "rotation", a if i % 2 == 0 else -a, 0.07)
	shake.tween_property(box, "rotation", 0.0, 0.05)
	await shake.finished
	_reveal(chosen, prize, true)
	await get_tree().create_timer(1.1).timeout
	# Then the others open, one after another, nearest first.
	var order: Array = range(5).filter(func(i: int) -> bool: return i != chosen)
	order.sort_custom(func(a: int, b: int) -> bool: return absi(a - chosen) < absi(b - chosen))
	var d := 0
	for i: int in order:
		_reveal(i, decoys[d], false)
		d += 1
		await get_tree().create_timer(0.22).timeout
	continue_btn.visible = true
	continue_btn.text = "Tiếp tục · Màn %d" % (GameManager.level + 1)
	wear_btn.visible = prize["kind"] not in ["coins", "gems"]

func _reveal(i: int, item: Dictionary, real: bool) -> void:
	var box: Control = _boxes[i]
	var icon: Control = box.get_child(0)
	icon.visible = true
	icon.show_item(item["kind"], item.get("id", ""), item.get("amount", 0))
	var rare: bool = item["kind"] not in ["coins", "gems"]
	icon.glow = 1.0 if rare else 0.0
	create_tween().tween_method(_set_open.bind(box), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	icon.scale = Vector2.ONE * 0.2
	icon.pivot_offset = icon.size / 2.0
	create_tween().tween_property(icon, "scale", Vector2.ONE * (1.15 if real else 0.8), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if real:
		Profile.claim(prize)
		var center := box.global_position + Vector2(65, 60)
		mine_tag.visible = true
		mine_tag.position = box.position + Vector2(0, 160)
		Fx.hearts(center, 26 if rare else 14, Color("ff5f8f"), 1.3)
		Fx.sparkles(center, 16, Color("fff4c2"), 70.0)
		AudioManager.play_sfx("beauty" if rare else "pop")
		title.text = "Tuyệt vời!" if rare else "Bạn nhận được"
		prize_label.text = _describe(item)
		prize_label.modulate.a = 1.0
		prize_label.scale = Vector2.ONE * 0.5
		prize_label.pivot_offset = prize_label.size / 2.0
		create_tween().tween_property(prize_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		box.modulate = Color(1, 1, 1, 0.6)
		if rare:
			Fx.sparkles(box.global_position + Vector2(65, 60), 6, Color("fff4c2"), 40.0)

func _set_open(v: float, box: Control) -> void:
	box.set_meta("open", v)
	box.queue_redraw()

func _on_box_hover() -> void:
	if chosen < 0:
		AudioManager.play_sfx("click")

func _describe(item: Dictionary) -> String:
	match item["kind"]:
		"coins": return "+%d xu" % item["amount"]
		"gems": return "+%d kim cương" % item["amount"]
		_: return "%s: %s" % [Catalog.kind_label(item["kind"]), Catalog.item_name(item["kind"], item["id"])]

func _process(delta: float) -> void:
	_t += delta
	for i in range(_boxes.size()):
		var box: Control = _boxes[i]
		var hovered: bool = chosen < 0 and box.get_global_rect().has_point(get_global_mouse_position())
		box.set_meta("hover", lerpf(box.get_meta("hover"), 1.0 if hovered else 0.0, 1.0 - exp(-12.0 * delta)))
		box.queue_redraw()

func _draw_box(box: Control, i: int) -> void:
	var open: float = box.get_meta("open")
	var hover: float = box.get_meta("hover")
	var col: Color = BOX_COLORS[i]
	var body_col := col
	var bob := sin(_t * 2.5 + i) * 3.0 * (1.0 - open) - hover * 10.0
	var body := Rect2(15, 60 + bob, 100, 80)
	box.draw_colored_polygon(Kit.ellipse_pts(Vector2(65, 146), Vector2(52, 8)), Color(0.3, 0.1, 0.25, 0.15))
	box.draw_colored_polygon(Kit.rrect_pts(body, 10), body_col)
	box.draw_colored_polygon(Kit.rrect_pts(Rect2(body.position.x + 42, body.position.y, 16, body.size.y), 2), Color("fffaf4"))
	box.draw_colored_polygon(Kit.rrect_pts(Rect2(body.position.x, body.position.y + body.size.y - 14, body.size.x, 14), 6), body_col.darkened(0.1))
	# The lid pops up, spins away and fades out when opened.
	var lid_off := Vector2(open * 60.0, -open * 130.0)
	box.draw_set_transform(Vector2(65, 60 + bob) + lid_off, open * 1.6, Vector2.ONE * (1.0 - open * 0.4))
	col = Color(col, 1.0 - open)
	var fade := 1.0 - open
	box.draw_colored_polygon(Kit.rrect_pts(Rect2(-56, -18, 112, 22), 8), col.lightened(0.12))
	box.draw_colored_polygon(Kit.rrect_pts(Rect2(-9, -18, 18, 22), 2), Color("fffaf4", fade))
	for m: float in [-1.0, 1.0]:
		box.draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(m * 26, -40), Vector2(m * 30, -16)]), Color("ff5f8f", fade))
	box.draw_circle(Vector2(0, -20), 6.0, Color("ff7fa2", fade), true, -1.0, true)
	box.draw_set_transform(Vector2.ZERO)
	if hover > 0.05:
		box.draw_string(get_theme_default_font(), Vector2(0, 30 + bob), "?", HORIZONTAL_ALIGNMENT_CENTER, 130, 28, Color(1, 1, 1, hover))

func _on_wear() -> void:
	Profile.equip(prize["kind"], prize["id"])
	wear_btn.text = "Đã mặc ✓" if prize["kind"] == "outfit" else "Đã dùng ✓"
	wear_btn.disabled = true

func _on_continue() -> void:
	AudioManager.play_sfx("click")
	Transition.go("res://scenes/game_world.tscn")
