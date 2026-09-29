extends CanvasLayer
## In-round HUD: timer dial, the ten-heart love meter, score, current floor, arrows to off-screen
## staircases, level banners, wardrobe dock, toasts, vignette and the heart cursor.
## Everything is drawn by small Controls so it stays crisp and animates freely.

const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const Kit := preload("res://scripts/art/soft_draw.gd")
const PINK := Color("ff5f8f")
const PLUM := Color("6b3558")
const BIG_FONT := preload("res://assets/fonts/title_font.tres")

var time_left: float = 100.0
var hearts: int = 3
var _heart_kick: Array = []
var _cracks: Array = []
var _zone: Dictionary = {}
var _zone_anim: float = 0.0
var _banner_title: String = ""
var _banner_sub: String = ""
var _banner_color: Color = PINK
var _banner_age: float = 99.0
var _banner_hold: float = 1.8
var score_shown: float = 0.0
var score: int = 0
var charmed: int = 0
var _t: float = 0.0
var _timer_kick: float = 0.0
var _score_kick: float = 0.0
var _last_second: int = 60

var overlay: Control
var toast: Label
var dock: HBoxContainer
var outfit_label: Label
var cursor: Control
var buttons: Dictionary = {}

func _ready() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(180, 84)
	toast.size = Vector2(600, 40)
	toast.pivot_offset = Vector2(300, 20)
	toast.add_theme_font_size_override("font_size", 26)
	toast.add_theme_color_override("font_color", Color("ff4f82"))
	toast.add_theme_color_override("font_outline_color", Color.WHITE)
	toast.add_theme_constant_override("outline_size", 10)
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	_build_dock()
	cursor = Control.new()
	cursor.set_anchors_preset(Control.PRESET_FULL_RECT)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.draw.connect(_draw_cursor)
	add_child(cursor)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.hearts_changed.connect(_on_hearts_changed)
	Profile.leveled_up.connect(_on_level_up)
	for i in range(GameManager.MAX_HEARTS):
		_heart_kick.append(0.0)
	GameManager.boy_charmed.connect(_on_boy_charmed)
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.outfit_changed.connect(_show_outfit)
		_show_outfit.call_deferred(player.rig.outfit, false)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ---------------------------------------------------------------- wardrobe dock

func _build_dock() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 462)
	panel.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.97, 0.92), 30))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	outfit_label = Label.new()
	outfit_label.add_theme_font_size_override("font_size", 12)
	outfit_label.add_theme_color_override("font_color", Color("b0587f"))
	outfit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(outfit_label)
	dock = HBoxContainer.new()
	dock.add_theme_constant_override("separation", 5)
	col.add_child(dock)
	var ids: Array = Profile.owned["outfit"]
	for i in range(ids.size()):
		var id: String = ids[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pivot_offset = Vector2(20, 20)
		for style in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		b.tooltip_text = Wardrobe.OUTFITS[id]["name"]
		b.draw.connect(_draw_swatch.bind(b, id, i + 1))
		b.pressed.connect(_change_outfit.bind(id))
		b.mouse_entered.connect(_bounce.bind(b, 1.15))
		b.mouse_exited.connect(_bounce.bind(b, 1.0))
		dock.add_child(b)
		buttons[id] = b

func _pill(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	s.shadow_color = Color(0.45, 0.16, 0.35, 0.18)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing_size = 1.0
	return s

func _bounce(node: Control, target: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE * target, 0.18)

func _draw_swatch(b: Button, id: String, key: int) -> void:
	var colors: Array = Wardrobe.swatch(id)
	var c := Vector2(20, 20)
	var on := b.button_pressed
	if on:
		b.draw_circle(c, 20.0, PINK, true, -1.0, true)
	b.draw_circle(c, 17.5, Color.WHITE, true, -1.0, true)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for i in range(17):
		var a := PI + PI * i / 16.0
		top.append(c + Vector2.from_angle(a) * 14.5)
		bottom.append(c + Vector2.from_angle(a - PI) * 14.5)
	b.draw_colored_polygon(top, colors[0])
	b.draw_colored_polygon(bottom, colors[1])
	b.draw_arc(c, 14.5, 0.0, TAU, 32, Color(0, 0, 0, 0.12), 1.2, true)
	if key <= 9:
		b.draw_circle(Vector2(34, 34), 7.5, PLUM if not on else PINK, true, -1.0, true)
		var font := b.get_theme_default_font()
		b.draw_string(font, Vector2(30.5, 38), str(key), HORIZONTAL_ALIGNMENT_CENTER, 7, 10, Color.WHITE)

func _change_outfit(outfit_name: String) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.change_outfit(outfit_name)
	_show_outfit(outfit_name)

func _show_outfit(outfit_name: String, announce: bool = true) -> void:
	for id: String in buttons:
		buttons[id].set_pressed_no_signal(id == outfit_name)
		buttons[id].queue_redraw()
	outfit_label.text = Wardrobe.OUTFITS[outfit_name]["name"]
	if announce and buttons.has(outfit_name):
		var b: Control = buttons[outfit_name]
		b.scale = Vector2.ONE * 1.35
		_bounce(b, 1.0)

# ---------------------------------------------------------------- game signals

func _on_time_changed(t: float) -> void:
	time_left = t
	var sec := int(ceil(t))
	if sec != _last_second:
		_last_second = sec
		if sec <= 10 and sec > 0:
			_timer_kick = 0.25
			AudioManager.play_sfx("click")
			if sec == 10:
				show_toast("10 giây cuối!", Color("ff4f5f"))

func _on_score_changed(s: int) -> void:
	score = s

func _on_boy_charmed(_boy: Node2D, _pts: int) -> void:
	charmed = GameManager.charmed_count
	_score_kick = 0.4
	if GameManager.combo >= 2:
		show_toast("Combo x%d!" % GameManager.combo, Color("ff9d2e"))
		return
	var lines := ["Đổ rồi!", "Tim rụng rồi!", "Thêm một chàng!", "Quá đỉnh!", "Không lối thoát!"]
	show_toast(lines[(charmed - 1) % lines.size()], PINK)

func _on_hearts_changed(value: int, delta: int) -> void:
	if delta > 0:
		for i in range(hearts, value):
			_heart_kick[i] = 0.6
	elif delta < 0:
		for i in range(value, hearts):
			_cracks.append({"i": i, "age": 0.0})
		if value <= 2:
			show_toast("Sắp hết tim rồi!", Color("ff4f5f"))
	hearts = value

func _on_level_up(level: int, coins: int, gems: int) -> void:
	show_toast("Lên cấp %d! +%d xu +%d kim cương" % [level, coins, gems], Color("ff9d2e"))
	AudioManager.play_sfx("beauty")

func show_zone(data: Dictionary) -> void:
	_zone = data
	_zone_anim = 0.0

func show_level_intro(_index: int, title: String) -> void:
	_show_banner(title, "Đầy 10 trái tim trước khi hết giờ!", PINK, 1.8)

func show_level_result(won: bool, reason: String, last: bool) -> void:
	if won:
		_show_banner("Chiến thắng!" if last else "Hoàn thành!", "Tất cả Nam Anh đều mê Minh Hân!" if last else "+%d xu · Mở quà thôi!" % GameManager.last_reward, Color("ff9d2e"), 2.3)
	else:
		_show_banner("Hết giờ rồi!" if reason == "time" else "Hết trái tim…", "Thử lại nhé!", Color("8f5bd6"), 2.3)

func _show_banner(title: String, sub: String, color: Color, hold: float) -> void:
	_banner_title = title
	_banner_sub = sub
	_banner_color = color
	_banner_hold = hold
	_banner_age = 0.0

func show_toast(message: String, color: Color) -> void:
	toast.text = message
	toast.add_theme_color_override("font_color", color)
	toast.scale = Vector2.ONE * 0.4
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)

# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	_t += delta
	_zone_anim = minf(1.0, _zone_anim + delta * 3.0)
	_banner_age += delta
	for i in range(_heart_kick.size()):
		_heart_kick[i] = lerpf(_heart_kick[i], 0.0, 1.0 - exp(-8.0 * delta))
	for c: Dictionary in _cracks:
		c["age"] += delta
	_cracks = _cracks.filter(func(c: Dictionary) -> bool: return c["age"] < 0.8)
	score_shown = lerpf(score_shown, float(score), 1.0 - exp(-10.0 * delta))
	if absf(score_shown - score) < 1.0:
		score_shown = score
	_timer_kick = lerpf(_timer_kick, 0.0, 1.0 - exp(-8.0 * delta))
	_score_kick = lerpf(_score_kick, 0.0, 1.0 - exp(-7.0 * delta))
	overlay.queue_redraw()
	cursor.queue_redraw()

func _font() -> Font:
	return overlay.get_theme_default_font()

func _panel(r: Rect2, radius: float) -> void:
	var sh := Kit.rrect_pts(Rect2(r.position + Vector2(0, 4), r.size), radius)
	overlay.draw_colored_polygon(sh, Color(0.45, 0.16, 0.35, 0.12))
	overlay.draw_colored_polygon(Kit.rrect_pts(r, radius), Color(1, 0.985, 0.975, 0.94))

func _text(at: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	overlay.draw_string(_font(), at, s, align, width, size, color)

func _draw_overlay() -> void:
	# Soft vignette frames the scene; it pulses red when the love meter runs low.
	var edge := Color(0.42, 0.14, 0.34, 0.16)
	if hearts <= 2 and GameManager.game_active:
		edge = Color(0.9, 0.2, 0.35, 0.22 + 0.1 * sin(_t * 6.0))
	var clear := Color(edge, 0.0)
	var w := 960.0
	var h := 540.0
	var d := 70.0
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d)]), PackedColorArray([edge, edge, clear, clear]))
	overlay.draw_polygon(PackedVector2Array([Vector2(0, h - d), Vector2(w, h - d), Vector2(w, h), Vector2(0, h)]), PackedColorArray([clear, clear, edge, edge]))
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(d, 0), Vector2(d, h), Vector2(0, h)]), PackedColorArray([edge, clear, clear, edge]))
	overlay.draw_polygon(PackedVector2Array([Vector2(w - d, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - d, h)]), PackedColorArray([clear, edge, edge, clear]))
	_draw_exits()
	_draw_timer()
	_draw_meter()
	_draw_score()
	_draw_zone()
	_draw_banner()

func _draw_timer() -> void:
	var urgent := time_left <= 10.0
	var k := 1.0 + _timer_kick
	overlay.draw_set_transform(Vector2(82, 40), sin(_t * 30.0) * _timer_kick * 0.2, Vector2.ONE * k)
	_panel(Rect2(-66, -26, 132, 52), 26)
	var c := Vector2(-38, 0)
	overlay.draw_arc(c, 16.0, 0.0, TAU, 40, Color("f6dbe5"), 5.0, true)
	var col := Color("ff4f5f") if urgent else PINK
	overlay.draw_arc(c, 16.0, -PI / 2, -PI / 2 + TAU * clampf(time_left / GameManager.config()["time"], 0.0, 1.0), 40, col, 5.0, true)
	overlay.draw_circle(c, 3.0, col, true, -1.0, true)
	var secs := "%d" % int(ceil(time_left))
	var size := 28 if secs.length() < 3 else 24
	_text(Vector2(-14, 10), secs, size, col if urgent else PLUM)
	var w := _font().get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(-10 + w, 9), "giây", 12, Color("b58aa3"))
	overlay.draw_set_transform(Vector2.ZERO)

func _draw_meter() -> void:
	var r := Rect2(290, 14, 380, 56)
	_panel(r, 28)
	_text(Vector2(r.position.x, 31), "THƯỚC TÌNH CẢM", 11, Color("b0587f"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var drain: float = GameManager.drain_progress() if GameManager.game_active else 0.0
	for i in range(GameManager.MAX_HEARTS):
		var c := Vector2(r.position.x + 30 + i * 35.5, 50)
		var s: float = 11.0 * (1.0 + _heart_kick[i])
		overlay.draw_colored_polygon(Kit.heart_pts(c, 11.5), Color("f6dde6"))
		if i < hearts:
			var col := PINK
			# The heart about to drain fades and trembles.
			if i == hearts - 1 and drain > 0.6:
				col = PINK.lerp(Color("f6c2d2"), (drain - 0.6) / 0.4)
				c.x += sin(_t * 40.0) * (drain - 0.6) * 3.0
			overlay.draw_colored_polygon(Kit.heart_pts(c, s), col)
			overlay.draw_circle(c + Vector2(-3.5, -3.5), 1.8, Color(1, 1, 1, 0.75), true, -1.0, true)
	for cr: Dictionary in _cracks:
		var k: float = cr["age"] / 0.8
		var c := Vector2(r.position.x + 30 + cr["i"] * 35.5, 50)
		for side: float in [-1.0, 1.0]:
			var off := Vector2(side * (4.0 + k * 14.0), k * k * 30.0)
			overlay.draw_set_transform(c + off, side * k * 1.2, Vector2.ONE)
			var half := PackedVector2Array()
			for p: Vector2 in Kit.heart_pts(Vector2.ZERO, 11.0):
				if p.x * side >= -0.001:
					half.append(p)
			overlay.draw_colored_polygon(half, Color(0.55, 0.35, 0.8, 1.0 - k))
		overlay.draw_set_transform(Vector2.ZERO)

func _draw_zone() -> void:
	if _zone.is_empty():
		return
	var e := 1.0 - pow(1.0 - _zone_anim, 3.0)
	var label := "%s · %s" % [_zone["floor"], _zone["name"]]
	var w := _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 30
	var r := Rect2(16 - (1.0 - e) * 60.0, 74, w, 28)
	overlay.draw_colored_polygon(Kit.rrect_pts(r, 14), Color(1, 0.985, 0.975, 0.9 * e))
	_text(r.position + Vector2(15, 19), label, 13, Color(PLUM, e))

func _draw_exits() -> void:
	var world := get_parent()
	if world == null or not "zone" in world or world.zone == null:
		return
	var xf := overlay.get_viewport().get_canvas_transform()
	for exit: Dictionary in world.zone.data["exits"]:
		var sx: float = (xf * Vector2(exit["x"], 300)).x
		if sx > -10.0 and sx < 970.0:
			continue
		var right := sx > 480.0
		var d := 1.0 if right else -1.0
		var tip := Vector2(944.0 if right else 16.0, 300) + Vector2(d * sin(_t * 5.0) * 4.0, 0)
		var box := Rect2(tip.x - 132.0 if right else tip.x + 10.0, 284, 122, 32)
		overlay.draw_colored_polygon(Kit.rrect_pts(box, 16), Color(1, 0.985, 0.975, 0.9))
		overlay.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-d * 16, -11), tip + Vector2(-d * 16, 11)]), PINK)
		_text(Vector2(box.position.x, 305), exit["label"], 11, PLUM, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)

func _draw_banner() -> void:
	if _banner_age > _banner_hold + 0.6:
		return
	var inn := clampf(_banner_age / 0.35, 0.0, 1.0)
	var out := clampf((_banner_age - _banner_hold - 0.25) / 0.35, 0.0, 1.0)
	var s := (1.0 - pow(1.0 - inn, 3.0)) * (1.0 - out * out)
	if s <= 0.01:
		return
	overlay.draw_rect(Rect2(0, 0, 960, 540), Color(0.35, 0.1, 0.3, 0.22 * s))
	overlay.draw_set_transform(Vector2(480, 250), 0.0, Vector2(1.0, s))
	overlay.draw_colored_polygon(Kit.rrect_pts(Rect2(-260, -58, 520, 116), 30), Color(1, 0.985, 0.975, 0.97))
	overlay.draw_string(BIG_FONT, Vector2(-260, -2), _banner_title, HORIZONTAL_ALIGNMENT_CENTER, 520, 34, _banner_color)
	_text(Vector2(-260, 34), _banner_sub, 16, Color("9a6a88"), HORIZONTAL_ALIGNMENT_CENTER, 520)
	overlay.draw_set_transform(Vector2.ZERO)

func _draw_score() -> void:
	var k := 1.0 + _score_kick
	overlay.draw_set_transform(Vector2(878, 40), 0.0, Vector2.ONE * k)
	_panel(Rect2(-66, -26, 132, 52), 26)
	overlay.draw_colored_polygon(Kit.heart_pts(Vector2(-40, -1), 14.0), PINK)
	overlay.draw_circle(Vector2(-45, -6), 2.4, Color(1, 1, 1, 0.8), true, -1.0, true)
	_text(Vector2(-20, 4), "%d" % charmed, 24, PLUM)
	_text(Vector2(-20, 19), "%d điểm" % int(score_shown), 11, Color("b58aa3"))
	overlay.draw_set_transform(Vector2.ZERO)

func _draw_cursor() -> void:
	var m := cursor.get_local_mouse_position()
	var hot := false
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		hot = player.find_boy_at(player.pointer_world) != null
	var s := 1.35 if hot else 1.0
	var rot := _t * 2.0 if hot else 0.0
	cursor.draw_set_transform(m, 0.0, Vector2.ONE * s)
	if hot:
		for i in range(4):
			var a := rot + TAU * i / 4.0
			cursor.draw_colored_polygon(Kit.sparkle_pts(Vector2.from_angle(a) * 17.0, 4.0, a), Color("fff1b8"))
	cursor.draw_colored_polygon(Kit.heart_pts(Vector2(0, 0), 10.0), Color.WHITE)
	cursor.draw_colored_polygon(Kit.heart_pts(Vector2(0, 0), 7.5), PINK if hot else Color("ff8fb0"))
	cursor.draw_set_transform(Vector2.ZERO)
