extends Control
## Wardrobe and shop in one: browse outfits, hairstyles and beams, try them on Minh Hân,
## buy what is locked with coins or diamonds, and wear what is owned. The "Màu sắc" tab picks
## hair colour and skin tone for free.

const Catalog := preload("res://scripts/data/catalog.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")
const Fx := preload("res://scripts/vfx/fx.gd")
const Kit := preload("res://scripts/art/soft_draw.gd")
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const TABS := ["outfit", "hair", "look", "hat", "wings", "aura", "pet", "beam"]
const PET := preload("res://scripts/entities/pet.gd")

@onready var model: Node2D = $Model
@onready var beam: Node2D = $Beam
@onready var grid: GridContainer = $Panel/Box/Scroll/Grid
@onready var tabs: HFlowContainer = $Panel/Box/Tabs
@onready var name_label: Label = $ItemName
@onready var action_btn: Button = $ActionBtn
@onready var back_btn: Button = $BackBtn

var kind: String = "outfit"
var selected: String = ""
var _t: float = 0.0
var pet_preview: Node2D

func _ready() -> void:
	back_btn.pressed.connect(func() -> void: Transition.go("res://scenes/main_menu.tscn"))
	action_btn.pressed.connect(_on_action)
	for k: String in TABS:
		var b := Button.new()
		b.text = "Màu sắc" if k == "look" else Catalog.kind_label(k)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.theme_type_variation = &"SecondaryButton"
		b.custom_minimum_size = Vector2(118, 36)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_show_kind.bind(k))
		tabs.add_child(b)
	Profile.changed.connect(_refresh)
	pet_preview = PET.new()
	pet_preview.position = model.position + Vector2(92, 0)
	pet_preview.scale = Vector2.ONE * 1.6
	add_child(pet_preview)
	_apply_equipped()
	_show_kind("outfit")

func _apply_equipped() -> void:
	Profile.dress(model)
	beam.set_style(Profile.equipped["beam"])
	_show_pet(Profile.equipped["pet"])

func _show_pet(id: String) -> void:
	pet_preview.kind = id
	pet_preview.visible = id != "none"

func _show_kind(k: String) -> void:
	kind = k
	_apply_equipped()
	for i in range(tabs.get_child_count()):
		tabs.get_child(i).set_pressed_no_signal(TABS[i] == k)
	if k == "look":
		_build_look_grid()
		_refresh()
		return
	_select(Profile.equipped[k])
	_build_grid()

func _build_grid() -> void:
	_clear_grid()
	for id: String in Catalog.ids(kind):
		var card := Button.new()
		card.custom_minimum_size = Vector2(142, 170)
		card.focus_mode = Control.FOCUS_NONE
		card.toggle_mode = true
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		card.draw.connect(_draw_card.bind(card, kind, id))
		card.pressed.connect(_select.bind(id))
		card.mouse_entered.connect(func() -> void: card.queue_redraw())
		card.mouse_exited.connect(func() -> void: card.queue_redraw())
		var icon: Control = ItemIcon.new()
		icon.position = Vector2(16, 8)
		icon.size = Vector2(110, 112)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		icon.show_item(kind, id)
		# Badges sit on their own layer above the preview so the character never covers them.
		var badge := Control.new()
		badge.set_anchors_preset(Control.PRESET_FULL_RECT)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.draw.connect(_draw_badge.bind(badge, kind, id))
		card.add_child(badge)
		grid.add_child(card)
		card.set_meta("id", id)
	_refresh()

func _clear_grid() -> void:
	for c: Node in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

## Colour swatches: hair colours then skin tones, applied and saved on click.
func _build_look_grid() -> void:
	_clear_grid()
	for key: String in ["hair_color", "skin"]:
		var table: Dictionary = Wardrobe.HAIR_COLORS if key == "hair_color" else Wardrobe.SKINS
		for id: String in table:
			var card := Button.new()
			card.custom_minimum_size = Vector2(142, 88)
			card.focus_mode = Control.FOCUS_NONE
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			card.draw.connect(_draw_swatch.bind(card, key, id, table[id]))
			card.pressed.connect(_pick_look.bind(key, id))
			grid.add_child(card)

func _draw_swatch(card: Button, key: String, id: String, entry: Dictionary) -> void:
	var r := Rect2(Vector2(4, 4), card.size - Vector2(8, 8))
	var picked: bool = Profile.look_choice[key] == id
	if picked:
		card.draw_colored_polygon(Kit.rrect_pts(r.grow(3), 20), Color("ff6f97"))
	card.draw_colored_polygon(Kit.rrect_pts(r, 18), Color("fffaf8") if not card.is_hovered() else Color("fff0f5"))
	var c := Vector2(r.size.x / 2.0 + 4, 30)
	card.draw_circle(c, 17.0, Color(0.3, 0.1, 0.25, 0.25), true, -1.0, true)
	card.draw_circle(c, 15.5, entry["color"], true, -1.0, true)
	card.draw_circle(c + Vector2(-5, -5), 3.5, Color(1, 1, 1, 0.5), true, -1.0, true)
	var font := card.get_theme_default_font()
	var label: String = ("Tóc · " if key == "hair_color" else "Da · ") + entry["name"]
	card.draw_string(font, Vector2(r.position.x, r.end.y - 10), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color("6b3558") if not picked else Color("ff4f82"))

func _pick_look(key: String, id: String) -> void:
	Profile.set_look(key, id)
	model.apply_look(Profile.look())
	model.pop(0.12)
	AudioManager.play_sfx("pop")

func _draw_badge(badge: Control, card_kind: String, id: String) -> void:
	var font := badge.get_theme_default_font()
	if Catalog.is_special(card_kind, id):
		var pill := Rect2(Vector2(10, 10), Vector2(70, 20))
		badge.draw_colored_polygon(Kit.rrect_pts(Rect2(pill.position + Vector2(0, 2), pill.size), 10), Color(0.5, 0.3, 0.05, 0.25))
		badge.draw_colored_polygon(Kit.rrect_pts(pill, 10), Color("ffcf4a"))
		badge.draw_string(font, pill.position + Vector2(0, 14.5), "✦ Đặc biệt", HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 11, Color("6a3a08"))
	elif card_kind == "outfit" and Wardrobe.OUTFITS[id].has("theme"):
		var text: String = Wardrobe.OUTFITS[id]["theme"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14.0
		var pill := Rect2(Vector2(10, 10), Vector2(w, 18))
		badge.draw_colored_polygon(Kit.rrect_pts(pill, 9), Color(1, 0.94, 0.97, 0.95))
		badge.draw_string(font, pill.position + Vector2(0, 13), text, HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, 10, Color("c05a88"))

func _draw_card(card: Button, card_kind: String, id: String) -> void:
	var r := Rect2(Vector2(4, 4), card.size - Vector2(8, 8))
	var picked := id == selected and card_kind == kind
	var hovered := card.is_hovered()
	if picked:
		card.draw_colored_polygon(Kit.rrect_pts(r.grow(3), 20), Color("ff6f97"))
	card.draw_colored_polygon(Kit.rrect_pts(r, 18), Color("fffaf8") if not hovered else Color("fff0f5"))
	var font := card.get_theme_default_font()
	card.draw_string(font, Vector2(r.position.x, r.end.y - 30), Catalog.item_name(card_kind, id), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color("6b3558"))
	var status := ""
	var col := Color("b58aa3")
	if Profile.equipped[card_kind] == id:
		status = "Đang dùng"
		col = Color("ff4f82")
	elif Profile.owns(card_kind, id):
		status = "Đã có"
	else:
		var cost: Dictionary = Catalog.price(card_kind, id)
		var coin: bool = cost.has("coin")
		var value: int = cost.get("coin", cost.get("gem", 0))
		var tw := font.get_string_size(str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var start := r.position.x + (r.size.x - tw - 20) / 2.0
		if coin:
			ItemIcon.draw_coin(card, Vector2(start + 7, r.end.y - 14), 7.0)
		else:
			ItemIcon.draw_gem(card, Vector2(start + 7, r.end.y - 14), 7.0)
		card.draw_string(font, Vector2(start + 18, r.end.y - 9), str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("6b3558") if Profile.can_afford(cost) else Color("d98a9a"))
		return
	card.draw_string(font, Vector2(r.position.x, r.end.y - 9), status, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, col)

func _select(id: String) -> void:
	selected = id
	match kind:
		"outfit": model.set_outfit(id)
		"hair": model.apply_look({"hair": id})
		"beam": beam.set_style(id)
		"pet": _show_pet(id)
		"hat", "wings", "aura": model.set_gear(kind, id)
	model.pop(0.12)
	_refresh()

func _refresh() -> void:
	for c: Node in grid.get_children():
		c.queue_redraw()
	action_btn.visible = kind != "look"
	if kind == "look":
		name_label.text = "Màu tóc & màu da"
		return
	name_label.text = Catalog.item_name(kind, selected)
	action_btn.disabled = false
	if Profile.equipped[kind] == selected:
		action_btn.text = "Đang dùng"
		action_btn.disabled = true
	elif Profile.owns(kind, selected):
		action_btn.text = "Mặc ngay" if kind == "outfit" else "Dùng ngay"
	else:
		var cost: Dictionary = Catalog.price(kind, selected)
		var coin: bool = cost.has("coin")
		action_btn.text = "Mua · %d %s" % [cost.get("coin", cost.get("gem", 0)), "xu" if coin else "kim cương"]
		action_btn.disabled = not Profile.can_afford(cost)

func _on_action() -> void:
	if not Profile.owns(kind, selected):
		if not Profile.buy(kind, selected):
			return
		Fx.hearts(model.global_position + Vector2(0, -90), 18)
		Fx.sparkles(model.global_position + Vector2(0, -90), 14, Color("fff4c2"), 60.0)
		AudioManager.play_sfx("beauty")
	Profile.equip(kind, selected)
	AudioManager.play_sfx("pop")
	model.pop(0.2)
	_refresh()

func _process(delta: float) -> void:
	_t += delta
	var show_beam := kind == "beam"
	if show_beam:
		beam.activate(model.eye.global_position, Vector2(330, 190 + sin(_t * 2.0) * 12.0))
		beam.from_marker = model.eye
	elif beam.is_active:
		beam.deactivate()
	model.set_motion("beam" if show_beam else "idle")
	model.look_goal = sin(_t * 0.7) * 0.5 - 0.3
