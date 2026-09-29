extends "res://scripts/art/soft_draw.gd"
## Chibi character drawn from a smoothed pose every frame.
## Local space: feet on y = 0, facing +x. `turn` mirrors the whole drawing with a quick flip.
## `look` is the head yaw (-1..1): features slide round a sphere, so a walking character shows a real
## three-quarter face toward where it goes, and `look_goal` can still glance back without flipping.

signal stepped(at: Vector2)

const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const Acc := preload("res://scripts/art/accessories.gd")
const UI_FONT := preload("res://assets/fonts/ui_font.tres")
const PROPS := ["parcel", "clipboard", "books", "knife", "mic", "wand"]
## Near-arm pose (shoulder, elbow) used to present each held prop clearly beside the body.
const HOLD := {"parcel": [0.55, 1.25], "clipboard": [0.55, 1.25], "books": [0.3, 1.55], "knife": [0.3, 0.25], "mic": [1.3, 1.75]}
const THIGH := 22.0
const SHIN := 21.0
const UPPER_ARM := 15.5
const FOREARM := 14.0

@export var character: String = "minh_han"
@export var outfit: String = ""

var motion: String = "idle"
var facing: float = 1.0
var turn: float = 1.0
var look: float = 0.0
var look_goal: float = 0.0
var view: float = 0.5
var charmed: bool = false
const PINK_HEART := Color("ff5a84")
var heart_color: Color = PINK_HEART
## Equipped extras; an empty slot falls back to the outfit's own set piece.
var gear: Dictionary = {"hat": "", "wings": "", "aura": ""}
var charm_level: float = 0.0
var float_height: float = 0.0
var walk_speed: float = 0.0
var eye: Marker2D
var pose: Dictionary = {}
var style: Dictionary
var fit: Dictionary

var _t: float = 0.0
var _phase: float = 0.0
var _step: int = 0
var _blink: float = 0.0
var _next_blink: float = 2.0
var _sq: float = 0.0
var _sq_vel: float = 0.0
var _hair: float = 0.0
var _hair_vel: float = 0.0
var _seed: float = 0.0
var _R := Transform2D.IDENTITY
var _torso := Transform2D.IDENTITY
var _pelvis := Transform2D.IDENTITY
var _head := Transform2D.IDENTITY
var _j: Dictionary = {}
var _warp: float = 0.0

func _ready() -> void:
	_seed = randf() * 10.0
	_next_blink = randf_range(1.0, 3.0)
	style = Wardrobe.LOOKS[character].duplicate()
	if outfit == "" or not Wardrobe.OUTFITS.has(outfit):
		outfit = Wardrobe.default_for(character)
	fit = Wardrobe.OUTFITS[outfit]
	eye = Marker2D.new()
	eye.name = "Eye"
	add_child(eye)
	turn = facing
	pose = _target_pose()
	_solve()

# ---------------------------------------------------------------- public API

func set_outfit(next_outfit: String) -> void:
	if not Wardrobe.OUTFITS.has(next_outfit) or Wardrobe.OUTFITS[next_outfit]["owner"] != character:
		return
	outfit = next_outfit
	fit = Wardrobe.OUTFITS[outfit]
	pop(0.14)
	queue_redraw()

## Minh Hân's customisable look: any of hair (style id), hair_color and skin (see Wardrobe).
func apply_look(look: Dictionary) -> void:
	if Wardrobe.HAIRS.has(look.get("hair", "")):
		style["hair_style"] = Wardrobe.HAIRS[look["hair"]]["style"]
	if Wardrobe.HAIR_COLORS.has(look.get("hair_color", "")):
		style["hair"] = Wardrobe.HAIR_COLORS[look["hair_color"]]["color"]
	if Wardrobe.SKINS.has(look.get("skin", "")):
		style["skin"] = Wardrobe.SKINS[look["skin"]]["color"]
	queue_redraw()

func set_gear(slot: String, id: String) -> void:
	gear[slot] = "" if id == "none" else id
	queue_redraw()

func gear_in(slot: String) -> String:
	var g: String = gear.get(slot, "")
	return g if g != "" else fit.get("set", {}).get(slot, "")

func set_charmed(value: bool) -> void:
	if value and not charmed:
		pop(0.22)
	charmed = value

func set_motion(next_motion: String, speed: float = 0.0) -> void:
	motion = next_motion
	walk_speed = absf(speed)

func set_facing(direction: float) -> void:
	if absf(direction) < 0.5:
		return
	var next := signf(direction)
	if next != facing:
		facing = next
		_hair_vel += 3.0

func pop(amount: float) -> void:
	_sq_vel -= amount * 16.0

func _process(delta: float) -> void:
	advance_pose(delta)

func advance_pose(delta: float) -> void:
	# Springs are integrated explicitly; a long hitch (scene loads) must not blow them up.
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	_blink -= delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(2.0, 4.5)
	turn = move_toward(turn, facing, delta * 13.0)
	var view_goal: float = {"walk": 0.95, "beam": 0.8, "float": 0.75, "stun": 0.2}.get(motion, 0.55)
	view = lerpf(view, view_goal, 1.0 - exp(-10.0 * delta))
	look = lerpf(look, clampf(view_goal + look_goal, -1.0, 1.0), 1.0 - exp(-10.0 * delta))
	if motion == "walk":
		_phase += delta * TAU * clampf(walk_speed / 115.0, 1.0, 2.3)
		var step := int(floor(_phase / PI))
		if step != _step:
			_step = step
			stepped.emit(global_position)
	var goal := _target_pose()
	var rate := 20.0 if motion == "walk" else 11.0
	var k := 1.0 - exp(-rate * delta)
	for key: String in goal:
		pose[key] = lerpf(pose.get(key, goal[key]), goal[key], k)
	_hair_vel += ((pose["hair"] - _hair) * 80.0 - _hair_vel * 8.0) * delta
	_hair += _hair_vel * delta
	_sq_vel += (-_sq * 330.0 - _sq_vel * 13.0) * delta
	_sq += _sq_vel * delta
	_solve()
	queue_redraw()

# ---------------------------------------------------------------- posing

func held_prop() -> String:
	for prop: String in PROPS:
		if _has(prop):
			return prop
	return ""

func _has(extra: String) -> bool:
	return extra in fit["extras"]

## Outfit headwear gives way to an equipped hat.
func _has_head(extra: String) -> bool:
	return _has(extra) and gear_in("hat") == ""

func _target_pose() -> Dictionary:
	var b := sin(_t * 2.3 + _seed)
	var p := {"bob": b * 0.5, "lean": 0.0, "head": sin(_t * 1.1 + _seed) * 0.03, "hair": sin(_t * 1.7) * 0.03,
		"na": -0.22 - b * 0.02, "ne": 0.38, "fa": 0.3 + b * 0.02, "fe": 0.3,
		"nl": -0.07, "nk": 0.04, "fl": 0.1, "fk": 0.03, "nf": 0.0, "ff": 0.0}
	match motion:
		"walk":
			var amp := clampf(walk_speed / 150.0, 0.45, 1.0)
			var s := sin(_phase)
			var c := cos(_phase)
			p["nl"] = 0.5 * amp * s
			p["nk"] = 0.08 + 0.85 * amp * maxf(0.0, c)
			p["fl"] = -0.5 * amp * s
			p["fk"] = 0.08 + 0.85 * amp * maxf(0.0, -c)
			p["nf"] = 0.35 * maxf(0.0, c) - 0.15 * maxf(0.0, s)
			p["ff"] = 0.35 * maxf(0.0, -c) - 0.15 * maxf(0.0, -s)
			p["na"] = -0.5 * amp * s + 0.05
			p["ne"] = 0.45 + 0.25 * maxf(0.0, -s)
			p["fa"] = 0.5 * amp * s - 0.1
			p["fe"] = 0.45 + 0.25 * maxf(0.0, s)
			p["lean"] = 0.07 * amp
			p["head"] = -0.03 + sin(_phase * 2.0) * 0.025
			p["bob"] = -1.6 * absf(c) * amp
			p["hair"] = -0.28 * amp + sin(_phase * 2.0) * 0.05
		"beam":
			p["na"] = 1.5 + sin(_t * 16.0) * 0.03
			p["ne"] = 0.25
			p["fa"] = 0.5
			p["fe"] = -1.35
			p["lean"] = -0.05
			p["head"] = 0.13
			p["nl"] = -0.12
			p["nk"] = 0.12
			p["fl"] = 0.18
			p["fk"] = 0.0
			p["hair"] = 0.08 + sin(_t * 9.0) * 0.04
		"stun":
			var w := sin(_t * 9.0)
			p["lean"] = w * 0.1
			p["head"] = -w * 0.14
			p["na"] = 0.7 + w * 0.3
			p["ne"] = 0.9
			p["fa"] = -0.7 - w * 0.3
			p["fe"] = 0.9
			p["nl"] = -0.06
			p["nk"] = 0.3
			p["fl"] = 0.06
			p["fk"] = 0.3
			p["bob"] = 2.0
		"float":
			var f := sin(_t * 2.4 + _seed)
			p["lean"] = 0.1 + f * 0.04
			p["head"] = 0.14 + f * 0.04
			p["nl"] = -0.2 + f * 0.1
			p["nk"] = 0.75
			p["fl"] = -0.42 - f * 0.1
			p["fk"] = 0.95
			p["nf"] = 0.55
			p["ff"] = 0.55
			p["na"] = 1.15 + f * 0.12
			p["ne"] = 0.55
			p["fa"] = 0.85 - f * 0.1
			p["fe"] = 0.45
			p["hair"] = -0.1 + f * 0.08
	if charm_level > 0.0 and motion != "float":
		p["head"] += 0.1 * charm_level
		p["na"] = lerpf(p["na"], 0.9, charm_level * 0.6)
		p["ne"] = lerpf(p["ne"], 1.9, charm_level * 0.6)
	var prop := held_prop()
	if prop != "" and HOLD.has(prop) and motion in ["idle", "walk"]:
		p["na"] = HOLD[prop][0]
		p["ne"] = HOLD[prop][1]
	return p

func _leg_height(a: float, k: float) -> float:
	return THIGH * cos(a) + SHIN * cos(a - k) + 5.5

func _solve() -> void:
	var tx := turn if absf(turn) > 0.06 else 0.06 * signf(turn + 0.0001)
	_R = Transform2D(Vector2(tx * (1.0 + _sq), 0.0), Vector2(0.0, 1.0 - _sq), Vector2.ZERO)
	var ground := -maxf(_leg_height(pose["nl"], pose["nk"]), _leg_height(pose["fl"], pose["fk"]))
	if motion == "float":
		ground = -44.0
	var pel := Vector2(sin(_t * 47.0) * charm_level * 0.9, ground + pose["bob"] - float_height)
	_pelvis = Transform2D(0.0, pel)
	_torso = Transform2D(pose["lean"], pel)
	_head = _torso * Transform2D(pose["head"], Vector2(0, -36)) * Transform2D(0.0, Vector2(0, -27))
	for side: String in ["n", "f"]:
		var turned := 6.5 * view
		var hip := pel + _turned(Vector2(-6.5 if side == "n" else 6.5, 1.0), turned)
		var a: float = pose[side + "l"]
		var knee := hip + dir(a) * THIGH
		var ankle := knee + dir(a - pose[side + "k"]) * SHIN
		_j[side + "hip"] = hip
		_j[side + "knee"] = knee
		_j[side + "ankle"] = ankle
		var sh := _turned(Vector2(-11.5 if side == "n" else 11.5, -31.0), turned)
		var arm: float = pose[side + "a"]
		var el := sh + dir(arm) * UPPER_ARM
		var wr := el + dir(arm + pose[side + "e"]) * FOREARM
		_j[side + "sh"] = _torso * sh
		_j[side + "el"] = _torso * el
		_j[side + "wr"] = _torso * wr
	eye.position = _R * (_head * _eye_center(true))

func _yaw() -> float:
	return look * 0.62

## Horizontal position of a feature sitting at `theta` on the head sphere.
func _fx(theta: float, r: float) -> float:
	return r * sin(theta + _yaw())

## Foreshortening of a feature as it rotates toward the silhouette.
func _fs(theta: float) -> float:
	return clampf(lerpf(1.0, cos(theta + _yaw()) / cos(theta), 0.8), 0.45, 1.0)

## Three-quarter body: the front centre line slides toward the facing side while the silhouette holds.
func _turned(p: Vector2, amount: float) -> Vector2:
	var k := clampf(p.x / 14.5, -1.0, 1.0)
	return Vector2(p.x + amount * (1.0 - k * k), p.y)

func map_pt(p: Vector2) -> Vector2:
	return _turned(p, _warp) if _warp != 0.0 else p

func map_pts(points: PackedVector2Array) -> PackedVector2Array:
	if _warp == 0.0:
		return points
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(_turned(p, _warp))
	return out

func _eye_center(near: bool) -> Vector2:
	return Vector2(_fx(0.45 if near else -0.45, 26.0), 5.0)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var fk := 1.0 / (1.0 + float_height / 45.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	ellipse(Vector2(0, 0), Vector2(22, 5) * fk, Color(0.32, 0.12, 0.3, 0.18 * fk + 0.05))
	var aura := gear_in("aura")
	if aura != "":
		_use(Transform2D(0.0, Vector2(0, -float_height)))
		Acc.aura_back(self, aura, _t)
	var wings := gear_in("wings")
	if wings != "":
		_use(_torso)
		Acc.wings(self, wings, _t)
	var hat := gear_in("hat")
	if hat != "":
		_use(_head)
		Acc.hat_back(self, hat, _t)
	_draw_back_hair()
	_draw_back_garments()
	_draw_arm("f", 0.1)
	_draw_leg("f", 0.08)
	_draw_leg("n", 0.0)
	_draw_torso()
	_draw_arm("n", 0.0)
	_draw_head()
	_draw_props()
	if hat != "":
		_use(_head)
		Acc.hat(self, hat, _t)
	_draw_overhead()
	if aura != "":
		_use(Transform2D(0.0, Vector2(0, -float_height)))
		Acc.aura_front(self, aura, _t)

func _shade(c: Color, amount: float) -> Color:
	return c.darkened(amount) if amount > 0.0 else c

func _use(xform: Transform2D) -> void:
	draw_set_transform_matrix(_R * xform)

func _draw_leg(side: String, shade: float) -> void:
	_use(Transform2D.IDENTITY)
	var hip: Vector2 = _j[side + "hip"]
	var knee: Vector2 = _j[side + "knee"]
	var ankle: Vector2 = _j[side + "ankle"]
	var skin := _shade(style["skin"], shade)
	var bottom: Dictionary = fit["bottom"]
	var col: Color = _shade(bottom.get("color", Color.WHITE), shade)
	match bottom["type"]:
		"pants":
			chain([hip, knee, ankle.lerp(knee, 0.05)], [7.2, 6.3, 5.9], col)
			if bottom.get("ripped", false):
				for k: float in [0.45, 0.62]:
					var at := hip.lerp(knee, k) if k < 0.5 else knee.lerp(ankle, 0.1)
					poly(ellipse_pts(at, Vector2(3.2, 1.3), 12), skin, 0.0)
					draw_line(at - Vector2(3.4, 0), at + Vector2(3.4, 0), Color(1, 1, 1, 0.8), 1.0, true)
		"wide_pants":
			chain([hip, knee, ankle.lerp(knee, 0.02)], [8.0, 8.0, 8.6], col)
		"capri":
			chain([ankle, knee], [4.1, 4.9], skin)
			chain([hip, knee, knee.lerp(ankle, 0.3)], [7.2, 6.4, 6.1], col)
		"shorts":
			chain([hip, knee, ankle], [5.8, 4.9, 4.2], skin)
			var end := hip.lerp(knee, 0.62)
			chain([hip, end], [7.9, 7.4], col)
			if bottom.has("trim"):
				chain([hip.lerp(knee, 0.54), end], [7.6, 7.5], _shade(bottom["trim"], shade), 1.4)
			if bottom.has("stripe"):
				var side_off := (knee - hip).normalized().orthogonal() * 5.2
				draw_line(hip + side_off, end + side_off, bottom["stripe"], 1.8, true)
		_:
			chain([hip, knee, ankle], [5.8, 4.9, 4.2], skin)
	if bottom.has("socks"):
		var sock: Color = _shade(bottom["socks"], shade)
		chain([knee.lerp(ankle, 0.1), ankle], [4.8, 4.5], sock, 1.5)
		var band := (ankle - knee).normalized().orthogonal() * 4.6
		draw_line(knee.lerp(ankle, 0.16) - band, knee.lerp(ankle, 0.16) + band, sock.lightened(0.35) if sock.v < 0.9 else Color("f3b7c9"), 1.6, true)
	var foot: float = pose[side + "f"]
	_use(Transform2D(foot, ankle))
	if fit.get("shoes", "") == "sandal":
		blob([-4, -2, -4.5, 3, 2, 4.5, 10, 4, 11, 1, 6, -1.5], skin)
		poly(rrect_pts(Rect2(-5, 3.5, 17, 2.6), 1.2), _shade(Color("c98a5a"), shade), 0.8)
		draw_line(Vector2(2, -1), Vector2(7, 3.5), _shade(Color("ff8fab"), shade), 1.6, true)
		return
	blob([-5, -3, -5.5, 3, -2.5, 5.6, 6, 5.8, 11, 4.8, 12, 1.4, 8, -1.8, 2.5, -3.8], _shade(Color("fbf8f4"), shade))
	draw_line(Vector2(-4.6, 3.8), Vector2(11.2, 3.4), _shade(Color("dcd0d8"), shade), 2.0, true)
	line([1, -1.5, 4, 0.5, 7.5, 0.6], _shade(Color("e5909f"), shade), 1.4)

func _draw_arm(side: String, shade: float) -> void:
	_use(Transform2D.IDENTITY)
	var sh: Vector2 = _j[side + "sh"]
	var el: Vector2 = _j[side + "el"]
	var wr: Vector2 = _j[side + "wr"]
	var skin := _shade(style["skin"], shade)
	chain([sh, el, wr], [4.6, 4.0, 3.6], skin)
	var top: Dictionary = fit["top"]
	var sleeve: String = top.get("sleeve", "short")
	var col: Color = top.get("sleeve_color", top["color"])
	var cuff: Color = top.get("trim", col.darkened(0.12))
	var stripe := Color.TRANSPARENT
	if fit.has("outer"):
		var outer: Dictionary = fit["outer"]
		sleeve = "long"
		col = outer.get("sleeve_color", outer["color"])
		cuff = outer.get("cuff", col.darkened(0.15))
		stripe = outer.get("stripe", Color.TRANSPARENT)
	col = _shade(col, shade)
	cuff = _shade(cuff, shade)
	match sleeve:
		"short":
			chain([sh, sh.lerp(el, 0.78)], [6.4, 5.8], col)
		"cap":
			chain([sh, sh.lerp(el, 0.42)], [5.9, 5.4], col)
		"elbow":
			var end := el.lerp(wr, 0.2)
			chain([sh, el, end], [6.1, 5.9, 6.2], col)
			chain([el.lerp(wr, 0.08), end], [6.2, 6.3], cuff, 1.4)
		"puff":
			dot(sh.lerp(el, 0.28), 6.9, col)
			chain([sh.lerp(el, 0.5), sh.lerp(el, 0.62)], [5.4, 5.2], cuff, 1.4)
		"kimono":
			var n := (el - sh).normalized().orthogonal()
			var drop := Vector2(0, 19)
			var sleeve_pts := PackedVector2Array([sh + n * 6.5, sh - n * 6.5, el - n * 8.5, el - n * 8.5 + drop, el + n * 8.5 + drop * 0.85, el + n * 8.5])
			poly(smooth(sleeve_pts, 4), col)
			draw_line(el - n * 8.0 + drop * 0.97, el + n * 8.0 + drop * 0.83, cuff, 2.2, true)
			if top.get("pattern", "") == "sakura":
				_flower(el.lerp(el + drop, 0.55), 2.6, top["pattern_color"])
		"long":
			var end := wr.lerp(el, 0.1)
			chain([sh, el, end], [6.0, 5.5, 5.2], col)
			chain([wr.lerp(el, 0.26), end], [5.4, 5.4], cuff, 1.5)
			if stripe.a > 0.0:
				var off := (el - sh).normalized().orthogonal() * -4.2
				var off2 := (end - el).normalized().orthogonal() * -4.0
				draw_polyline(PackedVector2Array([sh + off, el + off, el + off2, end + off2]), Color("fbf7f2"), 3.4, true)
				draw_polyline(PackedVector2Array([sh + off, el + off, el + off2, end + off2]), _shade(stripe, shade), 1.6, true)
	var hand_col := skin
	if _has("gloves"):
		hand_col = _shade(fit.get("glove_color", Color("ffffff")), shade)
		chain([el.lerp(wr, 0.05), wr], [4.4, 3.9], hand_col, 1.4)
	var hand_at := wr + (wr - el).normalized() * 2.4
	dot(hand_at, 4.4, hand_col, OUTLINE)

## Held props go over everything, face included, with the gripping hand drawn on top.
func _draw_props() -> void:
	var prop := held_prop()
	if prop == "":
		return
	_use(Transform2D.IDENTITY)
	var el: Vector2 = _j["nel"]
	var wr: Vector2 = _j["nwr"]
	var hand := wr + (wr - el).normalized() * 2.4
	match prop:
		"parcel":
			var box := hand + Vector2(7, -4)
			poly(rrect_pts(Rect2(box - Vector2(14, 11), Vector2(28, 22)), 2.5), Color("d9a46c"))
			poly(pts([box.x - 14, box.y - 11, box.x + 14, box.y - 11, box.x + 10, box.y - 16, box.x - 10, box.y - 16]), Color("e8b981"), 1.2)
			draw_line(box + Vector2(-14, -3), box + Vector2(14, -3), Color("f3e1bd"), 4.0, true)
			poly(rrect_pts(Rect2(box + Vector2(-2, 2), Vector2(11, 6)), 1.0), Color("fbf6ec"), 1.0)
			draw_line(box + Vector2(0, 4), box + Vector2(7, 4), Color("1f9a55"), 1.2, true)
		"clipboard":
			var board := hand + Vector2(8, -8)
			poly(rrect_pts(Rect2(board - Vector2(11, 15), Vector2(22, 30)), 2.5), Color("b98555"))
			poly(rrect_pts(Rect2(board - Vector2(8.5, 11), Vector2(17, 24)), 1.0), Color("fbf8f2"), 1.0)
			for i in range(4):
				draw_line(board + Vector2(-5, -6 + i * 5), board + Vector2(6, -6 + i * 5), Color("c9b8c4"), 1.0, true)
				line([board.x - 7.5, board.y - 7 + i * 5, board.x - 6.5, board.y - 5.5 + i * 5, board.x - 4.5, board.y - 9 + i * 5], Color("e0304f"), 1.1)
			poly(rrect_pts(Rect2(board + Vector2(-5, -17), Vector2(10, 5)), 1.5), Color("b7bec9"), 1.0)
		"books":
			var at := hand + Vector2(8, -4)
			var covers := [Color("5fa8d8"), Color("e98aa8"), Color("f2c24a")]
			for i in range(3):
				var r := Rect2(at + Vector2(-14 + i * 1.5, -12 + i * 7.5), Vector2(28 - i * 2.0, 7))
				poly(rrect_pts(r, 1.2), covers[i], 1.3)
				draw_line(r.position + Vector2(3, 4.8), r.end - Vector2(2, 2.2), Color("fffaf0"), 2.0, true)
				draw_line(r.position + Vector2(1.5, 0.8), r.position + Vector2(1.5, 6.2), covers[i].darkened(0.25), 1.6, true)
			line([at.x + 6, at.y - 12, at.x + 7, at.y - 18, at.x + 9, at.y - 16], Color("e0304f"), 1.4)
		"knife":
			# Held low at her side, blade down, so it reads against the skirt.
			var up := Vector2(0.35, 1.0).normalized()
			var side := up.orthogonal()
			chain([hand - up * 5.0, hand + up * 5.0], [2.4, 2.2], Color("8a5a3a"), 1.2)
			dot(hand - up * 2.0, 0.8, Color("e8d2b0"), 0.0)
			dot(hand + up * 2.5, 0.8, Color("e8d2b0"), 0.0)
			poly(rrect_pts(Rect2(hand + up * 5.5 - Vector2(3.4, 1.4), Vector2(6.8, 2.8)), 1.0), Color("c9ced8"), 1.0)
			var blade := PackedVector2Array([hand + up * 7.0 - side * 3.4, hand + up * 26.0 - side * 1.6, hand + up * 33.0, hand + up * 22.0 + side * 3.4, hand + up * 7.0 + side * 3.4])
			var cols := PackedColorArray()
			for v: Vector2 in blade:
				cols.append(Color("f4f7fb").lerp(Color("a9b3c4"), clampf((v - hand).dot(side) / 3.4 * 0.5 + 0.5, 0.0, 1.0)))
			draw_polygon(blade, cols)
			var edge := blade.duplicate()
			edge.append(blade[0])
			draw_polyline(edge, Color("6f7a8c"), 1.2, true)
			draw_line(hand + up * 9.0 - side * 1.6, hand + up * 28.0 - side * 0.6, Color(1, 1, 1, 0.9), 1.0, true)
			var glint := fmod(_t * 0.7, 1.0)
			sparkle(hand + up * lerpf(10.0, 30.0, glint), 4.0 * sin(glint * PI), Color.WHITE, _t)
		"mic":
			var d := (hand - el).normalized().rotated(-1.9)
			chain([hand - d * 4.0, hand + d * 11.0], [2.0, 2.8], Color("2a2530"), 1.2)
			draw_line(hand + d * 10.0 - d.orthogonal() * 3.2, hand + d * 10.0 + d.orthogonal() * 3.2, Color("c9c3cf"), 2.0, true)
			var head := hand + d * 16.0
			dot(head, 6.0, Color("b9bcc6"), 1.4)
			for k in range(-2, 3):
				draw_line(head + Vector2(k * 2.2, -5.2), head + Vector2(k * 2.2, 5.2), Color("8a8f9c"), 0.8, true)
				draw_line(head + Vector2(-5.2, k * 2.2), head + Vector2(5.2, k * 2.2), Color("8a8f9c"), 0.8, true)
			draw_circle(head + Vector2(-2, -2.5), 1.6, Color(1, 1, 1, 0.8), true, -1.0, true)
			var k2 := fmod(_t * 0.8, 1.0)
			var note := head + Vector2(8.0 + k2 * 8.0, -6.0 - k2 * 18.0)
			draw_circle(note, 2.2, Color(1.0, 0.4, 0.8, 1.0 - k2), true, -1.0, true)
			draw_line(note + Vector2(2, 0), note + Vector2(2, -7), Color(1.0, 0.4, 0.8, 1.0 - k2), 1.3, true)
		"wand":
			var d := (hand - el).normalized().rotated(-1.1)
			chain([hand - d * 3.0, hand + d * 20.0], [1.6, 1.3], Color("fdf6ff"), 1.2)
			var tip := hand + d * 25.0
			poly(_star_pts(tip, 7.0, _t * 2.0), Color("ffe36e"), 1.5, Color("c9962e"))
			for i in range(3):
				var k := fmod(_t * 0.9 + i / 3.0, 1.0)
				sparkle(tip + Vector2(-k * 14.0, k * 10.0 - 4.0), 3.0 * (1.0 - k), Color(1.0, 0.95, 0.7, 1.0 - k), _t + i)
	var glove: Color = fit.get("glove_color", style["skin"]) if _has("gloves") else style["skin"]
	dot(hand, 4.4, glove, OUTLINE)

func _top_shape(hem: float, flare: float = 0.0, width: float = 0.0) -> PackedVector2Array:
	var w := width
	var waist := minf(-9.0, hem - 3.0)
	return smooth(pts([-5, -33, -11.5 - w, -32.5, -13.5 - w, -27, -12.5 - w, -19, -11.3 - w, waist, -12.4 - flare - w, hem, 0, hem + 1.6, 12.4 + flare + w, hem, 11.3 + w, waist, 12.5 + w, -19, 13.5 + w, -27, 11.5 + w, -32.5, 5, -33, 0, -30.2]))

func _draw_torso() -> void:
	var skin: Color = style["skin"]
	var top: Dictionary = fit["top"]
	var bottom: Dictionary = fit["bottom"]
	var tcol: Color = top["color"]
	_warp = 6.5 * view
	# Neck and body skin, visible at crop tops and necklines.
	_use(_torso)
	blob([-4.3, -41, 4.3, -41, 4.6, -31, 10.8, -28, 11.4, -15, 10.4, -5, 11, 1, 0, 2.5, -11, 1, -10.4, -5, -11.4, -15, -10.8, -28, -4.6, -31], skin)
	seg(Vector2(-3, -33.5), Vector2(3, -33.5), skin.darkened(0.12), 2.0)
	# Waistband and seat of the bottoms.
	_use(_pelvis)
	if bottom["type"] in ["shorts", "pants", "capri"]:
		var waist: float = bottom.get("waist", -7.0)
		var bcol: Color = bottom["color"]
		blob([-11.6, waist, 11.6, waist, 12.8, -1, 11.4, 5.5, 3, 7.5, 0, 5.5, -3, 7.5, -11.4, 5.5, -12.8, -1], bcol)
		seg(Vector2(-11, waist + 2.5), Vector2(11, waist + 2.5), bcol.darkened(0.14), 1.3)
		if bottom.get("pattern", "") == "hearts":
			for at: Vector2 in [Vector2(-7, -1), Vector2(6, 1.5)]:
				heart(at, 2.3, bottom["pattern_color"])
	elif bottom["type"] == "bikini":
		blob([-11.5, -3, 11.5, -3, 10, 4, 3, 6.5, 0, 5, -3, 6.5, -10, 4], bottom["color"])
	elif bottom["type"] == "wide_pants":
		blob([-12, -7, 12, -7, 13, 2, 3, 8, 0, 6, -3, 8, -13, 2], bottom["color"])
	# Top garment.
	_use(_torso)
	var hem: float = top.get("hem", 1.0)
	if top["type"] == "dress" and bottom["type"] not in ["gown", "tutu"]:
		_draw_skirt({"type": "dress", "color": tcol, "length": 21.0, "pattern": top.get("pattern", ""), "pattern_color": top.get("pattern_color", tcol)})
		_use(_torso)
	if bottom["type"] in ["robe", "gown", "tutu"]:
		_draw_skirt(bottom)
		_use(_torso)
	if top["type"] == "bikini":
		_use(_torso)
		blob([-11, -30, 11, -30, 11.5, -23, 0, -22, -11.5, -23], tcol)
		for x: float in [-6.0, 0.0, 6.0]:
			dot(Vector2(x, -26.5), 0.9, top["pattern_color"], 0.0)
		_bow(Vector2(0, -26), 2.2, tcol.lightened(0.2))
		_draw_torso_extras(top, bottom)
		_warp = 0.0
		return
	var shape := _top_shape(hem, 0.6 if top["type"] in ["hoodie", "sweater"] else 0.0)
	match top["type"]:
		"offshoulder":
			shape = smooth(pts([-14.5, -27, -13.2, -19, -11.3, -9, -12.4, hem, 0, hem + 1.6, 12.4, hem, 11.3, -9, 13.2, -19, 14.5, -27, 7, -25.2, 0, -24.6, -7, -25.2]))
		"cami":
			shape = smooth(pts([-12.6, -26, -12.6, -19, -11.3, -9, -12.4, hem, 0, hem + 1.6, 12.4, hem, 11.3, -9, 12.6, -19, 12.6, -26, 6, -24, 0, -25.5, -6, -24]))
	poly(shape, tcol)
	match top.get("pattern", ""):
		"hearts":
			for at: Vector2 in [Vector2(-6, -24), Vector2(5, -17), Vector2(-4, -8), Vector2(7, -28), Vector2(8, -6)]:
				if at.y < hem - 2.0:
					heart(at, 2.4, top["pattern_color"])
		"knit":
			for y: float in [-26.0, -20.0]:
				for x: float in [-7.0, 0.0, 7.0]:
					line([x - 2, y, x, y + 2, x + 2, y], tcol.lightened(0.28), 1.1)
		"knit_boy":
			for x: float in [-6.0, -2.0, 2.0, 6.0]:
				seg(Vector2(x, -27), Vector2(x, hem - 2), tcol.lightened(0.1), 1.0)
		"sakura":
			for at: Vector2 in [Vector2(-7, -25), Vector2(6, -18), Vector2(-3, -10)]:
				if at.y < hem - 2.0:
					_flower(at, 2.4, top["pattern_color"])
		"flowers":
			for at: Vector2 in [Vector2(-7, -24), Vector2(5, -16), Vector2(-4, -9), Vector2(8, -27)]:
				if at.y < hem - 2.0:
					_flower(at, 2.2, top["pattern_color"])
		"dots", "ditsy":
			for i in range(22):
				var at := Vector2(-11.0 + fmod(i * 5.3, 22.0), -30.0 + fmod(i * 3.7, 30.0))
				if at.y < hem - 1.5 and Geometry2D.is_point_in_polygon(at, shape):
					if top["pattern"] == "dots":
						dot(at, 1.2, top["pattern_color"], 0.5)
					else:
						dot(at, 0.8, top["pattern_color"], 0.0)
						dot(at + Vector2(1.2, 0.8), 0.5, Color("8fae6a"), 0.0)
		"sequin":
			for i in range(9):
				var at := Vector2(-9.0 + fmod(i * 7.3, 18.0), -29.0 + fmod(i * 5.1, 24.0))
				if at.y < hem - 2.0:
					sparkle(at, 1.6 + 0.8 * sin(_t * 4.0 + i), top["pattern_color"], _t + i)
		"stripes":
			for y in range(-28, int(hem), 5):
				var band := pts([-20, y, 20, y, 20, y + 2, -20, y + 2])
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, band):
					draw_colored_polygon(map_pts(piece), top["pattern_color"])
		"cable":
			for x: float in [-6.0, 0.0, 6.0]:
				var cable := PackedVector2Array()
				for i in range(13):
					var y := -28.0 + i * (hem + 26.0) / 12.0
					cable.append(Vector2(x + sin(i * 1.4) * 1.6, y))
				draw_polyline(map_pts(cable), tcol.darkened(0.1), 1.6, true)
	if top.has("trim") and top["type"] not in ["offshoulder", "cami", "lace_square", "shirt"]:
		blob([-12.8, hem - 3.2, 12.8, hem - 3.2, 12.9, hem + 0.2, 0, hem + 1.7, -12.9, hem + 0.2], top["trim"], 1.4)
		blob([-6.2, -33.5, 6.2, -33.5, 4.6, -29.5, 0, -27.8, -4.6, -29.5], top["trim"], 1.4)
	if top.has("collar"):
		for m: float in [-1.0, 1.0]:
			blob([0.5 * m, -31, 6.5 * m, -34, 9.5 * m, -30, 6 * m, -26.5], top["collar"], 1.3)
	match top["type"]:
		"polo":
			blob([-5.5, -33, -0.5, -30, -4, -25.5, -8, -30], tcol.lightened(0.15), 1.4)
			blob([5.5, -33, 0.5, -30, 4, -25.5, 8, -30], tcol.lightened(0.15), 1.4)
			seg(Vector2(0, -30), Vector2(0, -21), ink(tcol), 1.2)
			dot(Vector2(0, -26), 0.9, Color("fbf7f0"), 0.0)
		"hoodie":
			blob([-12.9, hem - 3.4, 12.9, hem - 3.4, 13, hem + 0.4, 0, hem + 1.8, -13, hem + 0.4], tcol.darkened(0.08), 1.4)
			blob([-8, -10, 8, -10, 9.5, -2, 0, -1.2, -9.5, -2], tcol.darkened(0.06), 1.3)
			if not _has("hood_up"):
				blob([-13, -35, -8, -41, 8, -41, 13, -35, 8, -31.5, -8, -31.5], tcol.darkened(0.05), 1.6)
			for x: float in [-3.0, 3.0]:
				seg(Vector2(x, -31), Vector2(x * 1.15, -20), Color("fbf7f2"), 1.5)
				dot(Vector2(x * 1.15, -19.5), 1.2, Color("fbf7f2"), 0.8)
		"dress":
			seg(Vector2(-11.5, hem - 1.5), Vector2(11.5, hem - 1.5), tcol.darkened(0.12) if not top.has("trim") else top["trim"], 2.4)
		"offshoulder":
			for i in range(12):
				var x := lerpf(-13.5, 13.5, i / 11.0)
				var y := -26.4 + absf(x) * -0.05 + (1.2 if absf(x) < 8.0 else 0.0)
				dot(Vector2(x, y), 1.7, top["trim"], 0.8)
			for x: float in [-8.0, -3.0, 2.0, 7.0]:
				line([x, -23, x + 0.5, -14, x, hem - 1], tcol.darkened(0.08), 1.0)
		"cami":
			seg(Vector2(-8, -25.5), Vector2(-9.5, -33.5), tcol.darkened(0.15), 1.4)
			seg(Vector2(8, -25.5), Vector2(9.5, -33.5), tcol.darkened(0.15), 1.4)
			if top.has("trim"):
				for i in range(9):
					dot(Vector2(lerpf(-12, 12, i / 8.0), -25.2 + (1.0 if i % 2 == 0 else 0.0)), 1.3, top["trim"], 0.6)
		"lace_square":
			var lace: Color = top["trim"]
			poly(rrect_pts(Rect2(-7.5, -34, 15, 12), 1.5), lace, 1.2)
			for i in range(6):
				dot(Vector2(-6.2 + i * 2.5, -22.2), 1.2, lace, 0.6)
			for i in range(5):
				draw_arc(map_pt(Vector2(-5 + i * 2.5, -29)), 1.1, 0.0, TAU, 8, lace.darkened(0.15), 0.8, true)
			seg(Vector2(-11.5, -20.5), Vector2(11.5, -20.5), Color("f4a3bd"), 1.1)
			line([-0.5, -22, -3, -14, -2, -7], top["pattern_color"], 1.1)
			line([0.5, -22, 2.5, -15, 3.5, -9], top["pattern_color"], 1.1)
			_bow(Vector2(0, -22.5), 2.4, top["pattern_color"])
		"shirt":
			var tie: Color = top["trim"]
			blob([-0.8, -31.5, -6.5, -34, -9, -28, -4, -27], Color("ffffff"), 1.3, Color("c9c2cc"))
			blob([0.8, -31.5, 6.5, -34, 9, -28, 4, -27], Color("ffffff"), 1.3, Color("c9c2cc"))
			poly(pts([-1.8, -31.5, 1.8, -31.5, 1.2, -28.5, -1.2, -28.5]), tie, 1.0)
			poly(pts([-1.2, -28.5, 1.2, -28.5, 2.8, -10, 0, -7.5, -2.8, -10]), tie, 1.0)
			for y: float in [-18.0, -9.0, -1.0]:
				dot(Vector2(-4.5, y), 0.7, Color("d8d2da"), 0.0)
		"sweater":
			blob([-13, hem - 3.6, 13, hem - 3.6, 13.2, hem + 0.4, 0, hem + 1.8, -13.2, hem + 0.4], tcol.darkened(0.07), 1.4)
			blob([-5.8, -34, 5.8, -34, 5, -30, 0, -29, -5, -30], tcol.darkened(0.07), 1.3)
		"sailor":
			var navy: Color = top["trim"]
			blob([-11.8, -32.5, -5.5, -33.5, 0.5, -20, -1.5, -18, -13, -26], navy, 1.5)
			blob([11.8, -32.5, 5.5, -33.5, -0.5, -20, 1.5, -18, 13, -26], navy, 1.5)
			line([-10.5, -30, -4.8, -31, 0, -21], Color(1, 1, 1, 0.9), 1.1)
			line([10.5, -30, 4.8, -31, 0, -21], Color(1, 1, 1, 0.9), 1.1)
			_bow(Vector2(0, -19), 4.5, top["pattern_color"])
		"aodai":
			blob([-5, -38, 5, -38, 5.2, -32.5, 0, -31.5, -5.2, -32.5], top["trim"], 1.4)
			line([4, -32, 8, -27, 12, -26], top["trim"], 1.3)
		"yukata":
			var accent: Color = top["trim"]
			line([5.5, -33, 1.5, -24, -3, -14], accent, 3.2)
			line([-5.5, -33, -1, -24, 3.5, -14], accent.darkened(0.05), 3.2)
			blob([-12.6, -15, 12.6, -15, 12.8, -4, 0, -3.2, -12.8, -4], accent, 1.5)
			seg(Vector2(-12, -9.5), Vector2(12, -9.5), Color("fff3c4"), 1.3)
	if top["type"] == "aodai":
		_use(_pelvis)
		var sw: float = (pose["nl"] + pose["fl"]) * 10.0 + _hair * 6.0
		blob([-10.5, -6, 10.5, -6, 11 + sw * 0.5, 16, 9.5 + sw, 34, sw, 36, -9.5 + sw, 34, -11 + sw * 0.5, 16], tcol)
		for at: Vector2 in [Vector2(-4 + sw * 0.8, 27), Vector2(4 + sw * 0.9, 30), Vector2(sw * 0.6, 20)]:
			_flower(at, 2.6, top["pattern_color"])
		_use(_torso)
	if bottom["type"] == "skirt":
		_draw_skirt(bottom)
	if _has("bib"):
		_use(_torso)
		var denim: Color = bottom["color"]
		poly(rrect_pts(Rect2(-7.5, -24, 15, 16), 3.0), denim)
		seg(Vector2(-6, -23), Vector2(-10, -32.5), denim.darkened(0.1), 2.6)
		seg(Vector2(6, -23), Vector2(10, -32.5), denim.darkened(0.1), 2.6)
		dot(Vector2(-5, -21.5), 1.1, Color("f6d27a"), 0.6)
		dot(Vector2(5, -21.5), 1.1, Color("f6d27a"), 0.6)
		heart(Vector2(0, -15), 2.6, Color("ffe1ea"))
	_draw_torso_extras(top, bottom)
	if _has("necklace_thin"):
		_use(_torso)
		var chain_pts := PackedVector2Array()
		for i in range(11):
			var a := PI * 0.12 + PI * 0.76 * i / 10.0
			chain_pts.append(map_pt(Vector2(cos(a) * 6.5, -34.0 + sin(a) * 8.0)))
		draw_polyline(chain_pts, Color("e8c872"), 0.8, true)
		dot(Vector2(0, -26.2), 0.9, Color("f6e3a4"), 0.4)
	if _has("necklace"):
		_use(_torso)
		for i in range(9):
			var a := PI * 0.15 + PI * 0.7 * i / 8.0
			dot(Vector2(cos(a) * 7.0, -34.5 + sin(a) * 6.0), 0.95, Color("fffaf2"), 0.5)
		heart(Vector2(0, -27), 2.2, Color("ff7fa2"))
	if fit.has("outer"):
		_draw_outer(fit["outer"])
	if _has("scarf"):
		_use(_torso)
		var sc := Color("e6d2ab")
		chain([Vector2(-10, -32), Vector2(10, -32)], [5.2, 5.2], sc)
		chain([Vector2(5, -30), Vector2(6.5, -14)], [4.4, 3.8], sc.darkened(0.04))
		for x: float in [4.0, 6.0, 8.5]:
			seg(Vector2(x, -12.5), Vector2(x + 0.4, -9.5), sc.darkened(0.25), 1.2)
	_warp = 0.0

## Every skirt-like garment: pleated skirts, dress skirts, long robes, ball gowns and tutus.
func _draw_torso_extras(_top: Dictionary, _bottom: Dictionary) -> void:
	if _has("mandarin"):
		_use(_torso)
		var gold: Color = fit["top"].get("trim", Color("f6cf5a"))
		blob([-5, -38, 5, -38, 5.2, -32.5, 0, -31.5, -5.2, -32.5], gold, 1.3)
		line([3, -32, 7, -28, 11, -27], gold, 1.4)
	if _has("chain_belt"):
		_use(_pelvis)
		var links := PackedVector2Array()
		for i in range(13):
			var x := lerpf(-12.5, 12.5, i / 12.0)
			links.append(map_pt(Vector2(x, -4.0 + sin(i / 12.0 * PI) * 5.0)))
		draw_polyline(links, Color("c9c3cf"), 1.6, true)
		for i in range(0, 13, 2):
			draw_circle(links[i], 1.3, Color("eef0f6"), true, -1.0, true)
	if _has("choker"):
		_use(_torso)
		seg(Vector2(-4.4, -37.5), Vector2(4.4, -37.5), Color("2a2530"), 2.2)
		heart(Vector2(0, -35.5), 1.8, Color("ff4f82"))

func _draw_skirt(g: Dictionary) -> void:
	_use(_pelvis)
	var col: Color = g["color"]
	var kind: String = g.get("type", "skirt")
	var length: float = g.get("length", 24.0)
	var sw: float = (pose["nl"] + pose["fl"]) * 10.0 + _hair * 6.0
	var top: float = {"dress": -10.0, "robe": -6.0, "gown": -9.0, "tutu": -8.0}.get(kind, -8.0)
	var w: float = g.get("flare", {"dress": 19.0, "robe": 14.0, "tutu": 24.0}.get(kind, 16.5))
	if g.has("layer"):
		# A lighter petticoat peeks out under the hem as a row of scallops.
		var lw := w + 2.0
		var under := smooth(pts([-11.6, top + 3, 11.6, top + 3, 14.5 + sw * 0.4, length * 0.45, lw + sw, length + 2.5, -lw + sw, length + 2.5, -14.5 + sw * 0.4, length * 0.45]))
		poly(under, g["layer"], 1.4)
		for i in range(9):
			var x := lerpf(-lw + 3.0, lw - 3.0, i / 8.0) + sw
			draw_circle(map_pt(Vector2(x, length + 3.0)), 3.2, g["layer"], true, -1.0, true)
			draw_arc(map_pt(Vector2(x, length + 3.0)), 3.2, 0.1, PI - 0.1, 8, ink(g["layer"]), 1.2, true)
	var shape := _skirt_shape(top, length, w, sw, kind == "gown" and w > 26.0)
	_shaded(shape, col, w, sw, top, length)
	match g.get("pattern", ""):
		"plaid":
			var pc: Color = g["pattern_color"]
			for y in range(int(top) + 5, int(length), 6):
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, pts([-40, y, 40, y, 40, y + 1.4, -40, y + 1.4])):
					draw_colored_polygon(map_pts(piece), Color(pc, 0.8))
			for x in range(-24, 25, 7):
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, pts([x + sw * 0.5, top, x + 1.4 + sw * 0.5, top, x + 1.4 + sw, length + 3, x + sw, length + 3])):
					draw_colored_polygon(map_pts(piece), Color(g.get("pattern_color2", col.darkened(0.3)), 0.7))
		"sakura", "flowers", "hearts", "sequin", "dots", "ditsy":
			for i in range(int(length / 4.0)):
				var at := Vector2(-w * 0.8 + fmod(i * 11.7, w * 1.6) + sw * 0.6, top + 6.0 + fmod(i * 7.3, length - top - 6.0))
				if Geometry2D.is_point_in_polygon(at, shape):
					match g["pattern"]:
						"hearts": heart(at, 2.2, g["pattern_color"])
						"sequin": sparkle(at, 1.8 + 0.8 * sin(_t * 4.0 + i), g["pattern_color"], _t + i)
						"dots": dot(at, 1.0, g["pattern_color"], 0.0)
						"ditsy":
							dot(at, 0.8, g["pattern_color"], 0.0)
							dot(at + Vector2(1.2, 0.8), 0.5, Color("8fae6a"), 0.0)
						_: _flower(at, 2.5, g["pattern_color"])
	if g.get("pattern", "") == "satin":
		for x: float in [-6.0, 3.0]:
			line([x, top + 4, x + sw * 0.4 + 2.0, length * 0.5, x * 1.4 + sw, length - 2], Color(1, 1, 1, 0.35), 2.6)
	if g.has("tiers"):
		# Gathered ruffle bands; each follows the skirt's width and ends in a scalloped edge.
		var tiers: int = g["tiers"]
		var ruffle: Color = g.get("layer", col.lightened(0.3))
		for k in range(1, tiers + 1):
			var y := lerpf(top, length, float(k) / (tiers + 1)) + 3.0
			var f := (y - top) / (length - top)
			var half := lerpf(13.0, w, pow(f, 0.8)) - 1.5
			var shift := sw * f
			var band := PackedVector2Array()
			var bumps := 10
			for i in range(bumps + 1):
				var x := lerpf(-half, half, float(i) / bumps) + shift
				band.append(Vector2(x, y - 2.6 + sin(_t * 2.0 + i) * 0.4))
			for i in range(bumps * 2, -1, -1):
				var x := lerpf(-half, half, float(i) / (bumps * 2)) + shift
				var bump := 3.4 if i % 2 == 1 else 1.4
				band.append(Vector2(x, y + bump + sin(_t * 2.2 + i * 0.7) * 0.5))
			poly(band, ruffle, 1.2, ink(ruffle))
			for i in range(1, bumps):
				var x := lerpf(-half, half, float(i) / bumps) + shift
				seg(Vector2(x, y - 2.0), Vector2(x, y + 1.6), ruffle.darkened(0.1), 0.8)
	if kind == "tutu":
		for i in range(7):
			var x := lerpf(-w + 3.0, w - 3.0, i / 6.0) + sw
			draw_arc(Vector2(x, length - 1.0), 3.4, 0.2, PI - 0.2, 8, col.lightened(0.25), 1.4, true)
	elif kind == "robe":
		line([4, top + 2, 6 + sw * 0.6, length * 0.6, 7 + sw, length + 1], col.darkened(0.14), 1.4)
	else:
		for x: float in [-7.0, 0.0, 7.0]:
			line([x * 0.6, top + 5, x * 0.9 + sw * 0.5, length * 0.6, x * 1.2 + sw, length], col.darkened(0.12), 1.1)

## Skirt outline: straight A-line for everyday skirts, a swelling bell for ball gowns; the hem waves.
func _skirt_shape(top: float, length: float, w: float, sw: float, bell: bool) -> PackedVector2Array:
	var ctrl := PackedVector2Array([Vector2(-11.6, top), Vector2(11.6, top)])
	if bell:
		ctrl.append(Vector2(17.0 + sw * 0.2, lerpf(top, length, 0.2)))
		ctrl.append(Vector2(w * 0.86 + sw * 0.6, lerpf(top, length, 0.62)))
	else:
		ctrl.append(Vector2(13.5 + sw * 0.4, length * 0.4))
	var hem := PackedVector2Array()
	for i in range(7):
		var k := float(i) / 6.0
		var x := lerpf(w, -w, k) + sw
		hem.append(Vector2(x, length + 1.2 + sin(k * PI) * 0.8 + sin(_t * 2.2 + k * 6.0) * (1.2 if bell else 0.5)))
	ctrl.append_array(hem)
	if bell:
		ctrl.append(Vector2(-w * 0.86 + sw * 0.6, lerpf(top, length, 0.62)))
		ctrl.append(Vector2(-17.0 + sw * 0.2, lerpf(top, length, 0.2)))
	else:
		ctrl.append(Vector2(-13.5 + sw * 0.4, length * 0.4))
	return smooth(ctrl, 4)

## Fills a skirt with soft light from the upper left and shade toward the sides and hem.
func _shaded(shape: PackedVector2Array, col: Color, w: float, sw: float, top: float, length: float) -> void:
	var cols := PackedColorArray()
	var light := col.lightened(0.14)
	var dark := col.darkened(0.16)
	for v: Vector2 in shape:
		var across := clampf(absf(v.x - (sw - w * 0.25)) / maxf(w, 1.0), 0.0, 1.0)
		var down := clampf((v.y - top) / maxf(length - top, 1.0), 0.0, 1.0)
		cols.append(light.lerp(dark, clampf(across * 0.8 + down * 0.35, 0.0, 1.0)))
	var mapped := map_pts(shape)
	draw_polygon(mapped, cols)
	mapped.append(mapped[0])
	draw_polyline(mapped, ink(col), OUTLINE, true)

func _flower(at: Vector2, r: float, col: Color) -> void:
	for i in range(5):
		draw_circle(map_pt(at + Vector2.from_angle(TAU * i / 5.0 - PI / 2) * r * 0.75), r * 0.62, col, true, -1.0, true)
	draw_circle(map_pt(at), r * 0.45, Color("ffd66e"), true, -1.0, true)

func _star_pts(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(10):
		out.append(c + Vector2.from_angle(rot - PI / 2 + TAU * i / 10.0) * (r if i % 2 == 0 else r * 0.45))
	return out

func _bow(at: Vector2, s: float, col: Color) -> void:
	blob([at.x, at.y, at.x - s * 2.2, at.y - s * 1.3, at.x - s * 2.3, at.y + s * 1.1], col, 1.3)
	blob([at.x, at.y, at.x + s * 2.2, at.y - s * 1.3, at.x + s * 2.3, at.y + s * 1.1], col, 1.3)
	line([at.x - 1, at.y, at.x - s * 1.2, at.y + s * 2.4], col.darkened(0.1), 1.8)
	line([at.x + 1, at.y, at.x + s * 1.2, at.y + s * 2.4], col.darkened(0.1), 1.8)
	dot(at, s * 0.55, col.lightened(0.15), 1.2)

## Garments that hang behind the body: the áo dài back panel and big back bows.
func _draw_back_garments() -> void:
	var top: Dictionary = fit["top"]
	if top["type"] == "aodai":
		_use(_pelvis)
		var sw: float = (pose["nl"] + pose["fl"]) * 12.0 + _hair * 8.0
		blob([-11.5, -6, 11.5, -6, 12.5, 16, 7 + sw, 35, -4 + sw, 37, -13 + sw, 34, -12.5, 16], top["color"].darkened(0.08))
	if _has("cape"):
		_use(_torso)
		var cape: Color = fit.get("cape_color", Color("c9253f"))
		var sway: float = _hair * 18.0
		var ctrl := PackedVector2Array([Vector2(-12, -34), Vector2(12, -34), Vector2(21 + sway * 0.4, 12)])
		for i in range(7):
			var k := float(i) / 6.0
			ctrl.append(Vector2(lerpf(27.0, -30.0, k) + sway, 60.0 + sin(k * PI) * 3.0 + sin(_t * 2.4 + k * 7.0) * 2.2))
		ctrl.append(Vector2(-23 + sway * 0.4, 12))
		var cape_shape := smooth(ctrl, 4)
		var cols := PackedColorArray()
		for v: Vector2 in cape_shape:
			cols.append(cape.lerp(cape.darkened(0.3), clampf((v.y + 34.0) / 94.0, 0.0, 1.0)))
		draw_polygon(cape_shape, cols)
		var rim := cape_shape.duplicate()
		rim.append(cape_shape[0])
		draw_polyline(rim, ink(cape), OUTLINE, true)
		draw_polyline(rim.slice(3, rim.size() - 2), Color("fff3c4"), 1.2, true)
	if _has("cat_tail"):
		_use(_pelvis)
		var tail := PackedVector2Array()
		for i in range(10):
			var k := i / 9.0
			tail.append(Vector2(-6.0 - k * 20.0, 2.0 - sin(k * PI) * 18.0 - k * 10.0 + sin(_t * 3.0 + k * 3.0) * 3.0 * k))
		draw_polyline(tail, ink(Color("2a2530")), 6.0, true)
		draw_polyline(tail, Color("2a2530"), 4.0, true)
	if _has("obi_bow") or _has("back_bow"):
		_use(_torso)
		var col: Color = top.get("trim", Color("ffffff")) if _has("obi_bow") else Color("ffffff")
		var big := 1.6 if _has("back_bow") else 1.2
		var at := Vector2(-12, -9)
		blob([at.x, at.y, at.x - 12 * big, at.y - 9 * big, at.x - 13 * big, at.y + 5 * big], col, 1.6)
		blob([at.x, at.y, at.x + 4 * big, at.y - 11 * big, at.x + 8 * big, at.y + 2 * big], col, 1.6)
		line([at.x, at.y, at.x - 6 * big, at.y + 16 * big], col.darkened(0.08), 3.0)
		line([at.x, at.y, at.x - 11 * big, at.y + 13 * big], col.darkened(0.08), 3.0)

func _draw_outer(outer: Dictionary) -> void:
	_use(_torso)
	var col: Color = outer["color"]
	var hem: float = outer.get("hem", 2.0)
	if outer["style"] == "open":
		# Cropped jackets pull the waist points up so the panel never folds over itself.
		var left := pts([-5.8, -33.5, -12, -32.8, -14.2, -26, -13.4, minf(-16.0, hem - 7.0), -12.6, minf(-8.0, hem - 3.0), -14.2 - maxf(0.0, hem - 6.0) * 0.3, hem, -3.8, hem + 1.2, -3.6, minf(-14.0, hem - 5.0), -4.6, minf(-26.0, hem - 12.0)])
		for mirror: float in [1.0, -1.0]:
			var panel := PackedVector2Array()
			for p: Vector2 in left:
				panel.append(Vector2(p.x * mirror, p.y))
			poly(smooth(panel), col)
		if outer.get("pattern", "") == "tweed":
			for i in range(26):
				var at := Vector2(fmod(i * 4.7, 9.0) + 4.5, -31.0 + fmod(i * 3.3, 30.0))
				for mirror: float in [1.0, -1.0]:
					dot(Vector2(at.x * mirror, at.y), 0.55, [Color("d98aa8"), Color("b8a58a"), Color("fffaf2")][i % 3], 0.0)
			for x: float in [-9.0, 9.0]:
				dot(Vector2(x, -12), 1.1, Color("f6cf5a"), 0.5)
		line([-5.8, -33.5, -8.6, -27, -5.5, -21], ink(col), 1.2)
		line([5.8, -33.5, 8.6, -27, 5.5, -21], ink(col), 1.2)
		if outer.has("trim"):
			for x: float in [-4.3, 4.3]:
				seg(Vector2(x, -30), Vector2(x * 0.95, hem), outer["trim"], 1.8)
		if outer["type"] in ["bomber", "varsity"]:
			var band: Color = outer.get("cuff", col.darkened(0.15))
			for mirror: float in [1.0, -1.0]:
				blob([-14.2 * mirror, hem - 3.3, -3.9 * mirror, hem - 3.3, -3.9 * mirror, hem + 1.2, -14.3 * mirror, hem + 0.2], band, 1.3)
			if outer.has("trim"):
				seg(Vector2(-13.5, hem - 1.2), Vector2(-4, hem - 1.2), outer["trim"], 1.0)
				seg(Vector2(13.5, hem - 1.2), Vector2(4, hem - 1.2), outer["trim"], 1.0)
		return
	var shape := _top_shape(hem, maxf(0.0, hem - 4.0) * 0.35, 0.8)
	if outer["type"] == "windbreaker":
		poly(shape, col)
		for band: Array in [[-21.0, 13.0, Color("f39b4a")], [-8.0, 30.0, Color("7b6ac6")]]:
			var rect := pts([-20, band[0], 20, band[0], 20, band[0] + band[1], -20, band[0] + band[1]])
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, rect):
				draw_colored_polygon(map_pts(piece), band[2])
		var closed := map_pts(shape)
		closed.append(closed[0])
		draw_polyline(closed, ink(col), OUTLINE, true)
		seg(Vector2(-13, -21), Vector2(13, -21), ink(col), 1.1)
		seg(Vector2(-13, -8), Vector2(13, -8), ink(col), 1.1)
	else:
		poly(shape, col)
	if outer["type"] == "coat":
		line([-5.5, -33, -1.5, -22, 0, -12], ink(col), 1.3)
		line([5.5, -33, 1.5, -22, 0, -12], ink(col), 1.3)
		for y: float in [-8.0, 0.0]:
			dot(Vector2(2.5, y), 1.1, col.lightened(0.35), 0.6)
	else:
		seg(Vector2(0, -31), Vector2(0, hem), ink(col), 1.3)
		blob([-6.5, -35, 6.5, -35, 6, -30.5, 0, -29.5, -6, -30.5], col.darkened(0.08), 1.4)
	if outer["type"] == "track":
		dot(Vector2(-6.5, -24), 1.6, outer["stripe"], 0.8)
	if outer.get("logo", "") == "ghtk":
		# Text keeps reading left-to-right whichever way the character faces.
		var flip := signf(turn + 0.0001)
		draw_set_transform_matrix(_R * _torso * Transform2D(0.0, Vector2(flip, 1.0), 0.0, _turned(Vector2(-5.5, -22), _warp)))
		draw_string(_font(), Vector2(-10, 3), "ghtk", HORIZONTAL_ALIGNMENT_CENTER, 20, 6, Color("fbfbf5"))

func _draw_back_hair() -> void:
	var hair: Color = style["hair"]
	_use(_head * Transform2D(0.0, Vector2(-view * 4.0, 0.0)))
	if _has("hood_up"):
		blob([-37, 4, -38, -20, -26, -38, 0, -44, 26, -38, 38, -20, 37, 4, 30, 26, 0, 32, -30, 26], fit["top"]["color"])
		return
	match style["hair_style"]:
		"long", "emo":
			var s := _hair * 0.5
			blob([-29, -18, -32, 8, -31 + 20 * s, 32, -27 + 42 * s, 50, -18 + 55 * s, 60, -6 + 60 * s, 63, 6 + 60 * s, 63, 18 + 55 * s, 60, 27 + 42 * s, 50, 31 + 20 * s, 32, 32, 8, 29, -18, 0, -34], hair)
		"twin":
			for m: float in [-1.0, 1.0]:
				var s := _hair * 14.0
				blob([33 * m, -18, 47 * m, -8, 52 * m + s, 16, 46 * m + s * 1.6, 40, 38 * m + s * 1.2, 33, 36 * m, 6], hair)
			blob([-33, 8, -35, -14, -24, -33, 0, -38, 24, -33, 35, -14, 33, 8, 0, 14], hair)
		"boy":
			blob([-34, 14, -38, -6, -33, -27, -16, -40, 6, -42, 26, -35, 37, -18, 37, 4, 32, 18, 0, 12], hair)
		"neat":
			blob([-33, 12, -35, -10, -26, -32, 0, -38, 26, -32, 35, -10, 33, 12, 0, 10], hair)
		"layered":
			var s := _hair * 0.5
			var shag := PackedVector2Array()
			for p: Vector2 in pts([-29, -18, -35, 2, -30, 12, -38, 24, -31, 32, -36, 46, -24, 52, -12, 46, 0, 54, 12, 46, 24, 52, 36, 46, 31, 32, 38, 24, 30, 12, 35, 2, 29, -18, 0, -34]):
				shag.append(Vector2(p.x + (p.y * 0.9 * s if p.y > 0 else 0.0), p.y))
			poly(smooth(shag, 3), hair)
		"wavy":
			var s := _hair * 0.5
			var wave := PackedVector2Array()
			for p: Vector2 in pts([-29, -18, -34, 6, -30, 20, -35, 34, -30, 48, -33, 60, -20, 70, -6, 72, 6, 72, 20, 70, 33, 60, 30, 48, 35, 34, 30, 20, 34, 6, 29, -18, 0, -34]):
				wave.append(Vector2(p.x + (p.y * 0.9 * s if p.y > 0 else 0.0), p.y))
			poly(smooth(wave), hair)
		"spacebuns":
			for m: float in [-1.0, 1.0]:
				dot(Vector2(19 * m, -36), 11.5, hair)
				draw_arc(Vector2(19 * m, -36), 7.0, 3.4, 5.4, 10, hair.lightened(0.25), 1.8, true)
			blob([-31, -20, -35, 4, -33, 18, 0, 20, 33, 18, 35, 4, 31, -20, 0, -35], hair)
		"bob":
			var s := _hair * 6.0
			blob([-31, -20, -36, 4, -36 + s, 22, -28 + s, 30, 0, 26, 28 + s, 30, 36 + s, 22, 36, 4, 31, -20, 0, -35], hair)
		"ponytail":
			var s := _hair * 18.0
			blob([-30, 6, -33, -16, -24, -33, 0, -37, 24, -33, 33, -16, 30, 6, 0, 10], hair)
			blob([-24, -26, -40, -22, -48 + s * 0.4, 0, -46 + s, 30, -40 + s * 1.2, 48, -34 + s, 36, -32, 8, -26, -8], hair)
			dot(Vector2(-27, -24), 3.4, style["clip"], 1.3)
		"bun":
			dot(Vector2(-4, -38), 13.0, hair)
			draw_arc(Vector2(-4, -38), 8.0, 3.6, 5.6, 10, hair.lightened(0.25), 2.0, true)
			blob([-32, 10, -34, -12, -24, -32, 0, -37, 24, -32, 34, -12, 32, 10, 0, 8], hair)

func _font() -> Font:
	return UI_FONT

func _draw_head() -> void:
	var skin: Color = style["skin"]
	var hair: Color = style["hair"]
	var yaw := _yaw()
	var lk := sin(yaw) * 1.8
	var ears: bool = style["hair_style"] in ["boy", "neat", "bun"] and not _has("hood_up")
	_use(_head)
	# Ears ride the head sphere: the one turning away hides behind the face.
	if ears:
		for th: float in [-1.5, 1.5]:
			if cos(th + yaw) <= 0.05:
				dot(Vector2(_fx(th, 30.0), 5), 5.2, skin)
	var face := PackedVector2Array()
	for i in range(48):
		var a := TAU * i / 48.0
		var c := cos(a)
		var s := sin(a)
		var y := (28.5 if s > 0 else 27.5) * signf(s) * pow(absf(s), 0.85)
		face.append(Vector2(31.0 * signf(c) * pow(absf(c), 0.82) + sin(yaw) * 6.0 * clampf(y / 28.0, 0.0, 1.0), y))
	poly(face, skin)
	if ears:
		for th: float in [-1.5, 1.5]:
			if cos(th + yaw) > 0.05:
				dot(Vector2(_fx(th, 30.0), 5), 5.2, skin)
				draw_arc(Vector2(_fx(th, 30.0), 5), 2.4, 0.0, TAU, 16, skin.darkened(0.2), 1.1, true)
	# Blush.
	var blush_a := 0.38 + charm_level * 0.35 + (0.3 if charmed else 0.0)
	for th: float in [-0.72, 0.72]:
		var x := _fx(th, 27.0)
		ellipse(Vector2(x, 13), Vector2(5.2 * _fs(th), 2.9), Color(1.0, 0.52, 0.6, blush_a))
		if charmed or charm_level > 0.5:
			for i in range(3):
				var bx := x - 3.0 + i * 3.0
				draw_line(Vector2(bx + 1, 11), Vector2(bx - 1, 15), Color(0.9, 0.35, 0.45, 0.6), 1.0, true)
	# Eyes.
	for near: bool in [false, true]:
		var c := _eye_center(near)
		draw_set_transform_matrix(_R * _head * Transform2D(0.0, Vector2(_fs(0.45 if near else -0.45), 1.0), 0.0, c))
		_draw_eye(_eye_state(near))
	_use(_head)
	# Nose and mouth.
	dot(Vector2(_fx(0.0, 30.0), 10.5), 1.0, skin.darkened(0.22), 0.0)
	var m := Vector2(_fx(0.0, 27.0), 16.0)
	match _mouth_state():
		"open":
			poly(smooth(pts([m.x - 3.8, m.y - 0.8, m.x + 3.8, m.y - 0.8, m.x + 2.4, m.y + 3.0, m.x, m.y + 4.0, m.x - 2.4, m.y + 3.0]), 3), Color("c2415a"), 1.3, Color("7a2a3c"))
			ellipse(Vector2(m.x, m.y + 2.6), Vector2(1.8, 1.0), Color("f28b9b"))
		"wave":
			line([m.x - 4, m.y, m.x - 2, m.y - 1.4, m.x, m.y, m.x + 2, m.y - 1.4, m.x + 4, m.y], Color("8a3a4a"), 1.4)
		_:
			line([m.x - 3, m.y - 0.3, m.x, m.y + 1.8, m.x + 3, m.y - 0.3], Color("8a3a4a"), 1.6)
	# Front hair.
	_draw_front_hair(hair, lk)
	if _has("glasses"):
		var frame: Color = fit.get("glasses_color", Color("5d3f4e"))
		for near: bool in [false, true]:
			var c := _eye_center(near)
			draw_set_transform_matrix(_R * _head * Transform2D(0.0, Vector2(_fs(0.45 if near else -0.45), 1.0), 0.0, c))
			ellipse(Vector2.ZERO, Vector2(8.6, 8.2), Color(1, 1, 1, 0.14))
			draw_arc(Vector2.ZERO, 8.6, 0.0, TAU, 40, frame, 1.6, true)
		_use(_head)
		var mid := (_eye_center(true).x + _eye_center(false).x) * 0.5
		line([mid - 3.0, 4.0, mid, 2.6, mid + 3.0, 4.0], frame, 1.5)
	if _has("bow"):
		var bc: Color = Color("d9475e") if character == "minh_han" else style["clip"]
		var at := Vector2(-22 + lk * 2.0, -24)
		blob([at.x, at.y, at.x - 10, at.y - 7, at.x - 11, at.y + 5], bc, 1.5)
		blob([at.x, at.y, at.x + 10, at.y - 8, at.x + 10, at.y + 5], bc, 1.5)
		dot(at, 2.6, bc.lightened(0.15), 1.4)
	elif style.has("clip"):
		heart(Vector2(-23 + lk * 2.0, -17), 4.6, style["clip"], 1.3, -0.3)
	if _has("flower_clip"):
		_flower(Vector2(-23 + lk * 2.0, -19), 4.4, fit.get("clip_color", Color("fff4f8")))
		_flower(Vector2(-16 + lk * 2.0, -25), 3.0, Color("ff9dbb") if not fit.has("clip_color") else fit["clip_color"].lightened(0.3))
	if _has("sunglasses_head"):
		for lens: float in [-1.0, 1.0]:
			poly(rrect_pts(Rect2(lens * 10.5 - 7.0 + lk * 2.0, -38, 14, 9), 4.0), Color("2a2528"), 1.2)
			draw_line(Vector2(lens * 10.5 - 4.0 + lk * 2.0, -36), Vector2(lens * 10.5 - 1.0 + lk * 2.0, -33), Color(1, 1, 1, 0.5), 1.4, true)
		draw_line(Vector2(-3.5 + lk * 2.0, -34), Vector2(3.5 + lk * 2.0, -34), Color("2a2528"), 1.6, true)
	if _has("star_clip"):
		poly(_star_pts(Vector2(-22 + lk * 2.0, -21), 6.0, 0.2), Color("ffe36e"), 1.4, Color("c9962e"))
	if _has_head("tiara"):
		var gold := Color("f6cf5a")
		poly(smooth(pts([-16, -32, -10, -40, -5, -35, 0, -46, 5, -35, 10, -40, 16, -32, 0, -30]), 3), gold, 1.4, Color("b8862a"))
		dot(Vector2(0, -38), 2.0, Color("ff7fa2"), 0.8)
		dot(Vector2(-9, -35), 1.4, Color("8fd8ff"), 0.6)
		dot(Vector2(9, -35), 1.4, Color("8fd8ff"), 0.6)
		sparkle(Vector2(4, -46), 3.0 + sin(_t * 5.0), Color(1, 1, 1, 0.9), _t)
	if _has_head("beret"):
		var bc: Color = fit.get("hat_color", fit["bottom"].get("color", Color("b8474a")))
		draw_set_transform_matrix(_R * _head * Transform2D(-0.18, Vector2(-4, -31)))
		ellipse(Vector2.ZERO, Vector2(31, 11), bc, OUTLINE, ink(bc))
		dot(Vector2(0, -10), 2.0, bc.darkened(0.1), 1.2)
		draw_arc(Vector2(-8, -3), 14.0, 3.5, 4.6, 8, bc.lightened(0.3), 2.0, true)
		_use(_head)
		if _has("plumeria"):
			for i in range(5):
				var a := TAU * i / 5.0 + 0.3
				blob([22, -33, 22 + cos(a - 0.35) * 7.0, -33 + sin(a - 0.35) * 7.0, 22 + cos(a) * 9.0, -33 + sin(a) * 9.0, 22 + cos(a + 0.35) * 7.0, -33 + sin(a + 0.35) * 7.0], Color("fff8e8"), 1.0, Color("e2c89a"))
			dot(Vector2(22, -33), 2.6, Color("ffcf4a"), 0.0)
	if _has_head("sunhat"):
		var straw := Color("f3d9a0")
		ellipse(Vector2(0, -24), Vector2(50, 11), straw, OUTLINE, ink(straw))
		blob([-24, -24, -22, -44, 0, -52, 22, -44, 24, -24], straw)
		poly(smooth(pts([-23.5, -30, 23.5, -30, 24, -25, -24, -25]), 3), Color("ff9dbb"), 1.2)
		_flower(Vector2(16, -29), 4.0, Color("fffaf6"))
	if _has("helmet"):
		var hc := Color("20a05a")
		blob([-35, -6, -36, -24, -24, -39, 0, -44, 24, -39, 36, -24, 36, -6, 30, -10, 0, -12, -30, -10], hc)
		blob([24, -12, 40, -12, 44, -8, 30, -6], hc.darkened(0.12), 1.5)
		line([-20, -34, -4, -40, 12, -39], hc.lightened(0.35), 2.2)
		var flip := signf(turn + 0.0001)
		draw_set_transform_matrix(_R * _head * Transform2D(0.0, Vector2(flip, 1.0), 0.0, Vector2(0, -23)))
		draw_string(_font(), Vector2(-12, 4), "ghtk", HORIZONTAL_ALIGNMENT_CENTER, 24, 10, Color("fbfbf5"))
		_use(_head)
		line([-30, -8, -26, 14, -14, 26, 0, 29, 14, 26, 26, 14, 30, -8], Color("2a2a2a"), 1.1)
	if _has("hood_up"):
		var hc2: Color = fit["top"]["color"]
		var rim := PackedVector2Array()
		for i in range(25):
			var a := deg_to_rad(150.0 + 240.0 * i / 24.0)
			rim.append(Vector2(cos(a) * 34.0, sin(a) * 33.0 - 2.0))
		draw_polyline(rim, ink(hc2), 9.5, true)
		draw_polyline(rim, hc2, 6.5, true)

func _draw_front_hair(hair: Color, lk: float) -> void:
	var o := lk * 5.0
	var q := o * 0.5
	var shine := hair.lightened(0.28)
	match style["hair_style"]:
		"emo":
			blob([-33, 14, -35, -6, -30 + q, -24, -17 + q, -34, q, -37, 17 + q, -34, 30 + q, -24, 35 + q, -6, 33 + q, 26, 27 + o, 20, 22 + o, 12, 15 + o, 9, 8 + o, 3, 1 + o, -3, -6 + o, -6, -14 + o, -7, -22 + o, -4, -29, 2], hair)
			var s := _hair * 8.0
			chain([Vector2(-31, -2), Vector2(-32 + s * 0.5, 20), Vector2(-28 + s, 36)], [5.0, 4.6, 1.2], hair)
			draw_arc(Vector2(o * 0.5, -6), 26.0, deg_to_rad(205), deg_to_rad(250), 12, Color(shine, 0.8), 2.6, true)
		"long", "twin", "bob", "ponytail", "wavy", "spacebuns", "layered":
			blob([-33, 14, -35, -6, -30 + q, -24, -17 + q, -34, q, -37, 17 + q, -34, 30 + q, -24, 35 + q, -6, 33 + q, 14, 29 + o, 6, 27 + o, -6, 22 + o, -12, 17 + o, -4, 12 + o, -13, 5 + o, -6, -1 + o, -14, -7 + o, -5, -13 + o, -13, -19 + o, -4, -24 + o, -11, -28 + o, -3, -30, 8], hair)
			var s := _hair * 8.0
			var lock_len: float = {"long": 40.0, "twin": 40.0, "wavy": 40.0, "layered": 34.0}.get(style["hair_style"], 22.0)
			chain([Vector2(-31, -2), Vector2(-32 + s * 0.5, lock_len * 0.55), Vector2(-28 + s, lock_len)], [5.0, 4.6, 1.2], hair)
			chain([Vector2(31, -2), Vector2(32 + s * 0.5, lock_len * 0.55), Vector2(28 + s, lock_len)], [5.0, 4.6, 1.2], hair)
			draw_arc(Vector2(0 + o * 0.5, -6), 26.0, deg_to_rad(205), deg_to_rad(250), 12, Color(shine, 0.8), 2.6, true)
			draw_arc(Vector2(0 + o * 0.5, -6), 26.0, deg_to_rad(262), deg_to_rad(285), 8, Color(shine, 0.8), 2.6, true)
			if style["hair_style"] == "twin" and style.has("clip"):
				for m: float in [-1.0, 1.0]:
					dot(Vector2(33 * m, -18), 3.6, style["clip"], 1.4)
		"boy":
			if _has("hood_up") or _has("helmet"):
				blob([-30, 4, -31, -16, -18 + q, -26, q, -28, 18 + q, -26, 31 + q, -16, 30 + q, 4, 25 + o, -4, 18 + o, -12, 12 + o, -3, 4 + o, -13, -4 + o, -4, -11 + o, -12, -19 + o, -3, -25 + o, -9], hair)
				return
			blob([-33, 10, -37, -6, -35, -19, -30 + q, -29, -21 + q, -37, -11 + q, -40, -2 + q, -44, 9 + q, -41, 19 + q, -40, 28 + q, -33, 35 + q, -22, 38 + q, -8, 34 + q, 10, 30 + o, 1, 28 + o, -7, 23 + o, -2, 20 + o, -12, 14 + o, -3, 10 + o, -14, 3 + o, -4, -3 + o, -15, -9 + o, -5, -14 + o, -14, -20 + o, -3, -25 + o, -10, -29, 0], hair)
			chain([Vector2(4 + q, -38), Vector2(9 + q, -49), Vector2(15 + q, -47)], [2.2, 1.6, 0.6], hair)
			draw_arc(Vector2(o * 0.5, -8), 26.0, deg_to_rad(215), deg_to_rad(262), 12, Color(shine, 0.7), 2.4, true)
		"neat", "bun":
			blob([-32, 10, -34, -10, -28 + q, -28, -12 + q, -37, 6 + q, -38, 24 + q, -32, 33 + q, -18, 33 + q, 8, 29 + o, -2, 26 + o, -10, 14 + o, -13, 0 + o, -11, -14 + o, -10, -24 + o, -6, -28, 2], hair)
			draw_arc(Vector2(o * 0.5, -8), 25.0, deg_to_rad(220), deg_to_rad(260), 10, Color(shine, 0.7), 2.2, true)

func _eye_state(near: bool) -> String:
	if motion == "stun":
		return "spiral"
	if charmed:
		return "heart"
	if motion == "beam" and near:
		return "wink"
	if _blink > 0.0:
		return "closed"
	return "open"

func _mouth_state() -> String:
	if motion == "stun":
		return "wave"
	if charmed or motion == "beam" or charm_level > 0.35:
		return "open"
	return "smile"

func _draw_eye(state: String) -> void:
	var lash := Color("2f1a29")
	var female: bool = style["female"]
	match state:
		"closed":
			line([-5.8, -0.4, 0, 2.2, 5.8, -0.4], lash, 2.2)
		"wink":
			line([-5.8, 1.5, 0, -3.5, 5.8, 1.5], lash, 2.4)
		"heart":
			var beat := 1.0 + sin(_t * 9.0) * 0.1
			heart(Vector2(0, 0), 8.2 * beat, heart_color, 1.4)
			dot(Vector2(-2.6, -2.8), 1.5, Color(1, 1, 1, 0.9), 0.0)
		"spiral":
			var sp := PackedVector2Array()
			for i in range(30):
				var a := i * 0.55 + _t * 8.0
				sp.append(Vector2.from_angle(a) * (0.4 + i * 0.2))
			draw_polyline(sp, lash, 1.5, true)
		_:
			var ry := 7.0 if female else 6.4
			var rx := 5.4 if female else 4.9
			var iris: Color = style["iris"]
			ellipse(Vector2.ZERO, Vector2(rx, ry), iris.darkened(0.25), 1.2, lash)
			ellipse(Vector2(0, ry * 0.3), Vector2(rx * 0.78, ry * 0.55), iris.lightened(0.25))
			ellipse(Vector2(0, 0.4), Vector2(rx * 0.48, ry * 0.52), Color("241320"))
			var glint := 2.1 + charm_level * 0.8
			dot(Vector2(-rx * 0.35, -ry * 0.4), glint, Color.WHITE, 0.0)
			dot(Vector2(rx * 0.4, ry * 0.42), 1.0, Color(1, 1, 1, 0.85), 0.0)
			if charm_level > 0.2:
				sparkle(Vector2(rx * 0.3, -ry * 0.1), 2.6 * charm_level, Color.WHITE, _t * 3.0)
			line([-rx - 0.8, -ry * 0.35, -rx * 0.5, -ry - 0.6, rx * 0.5, -ry - 0.8, rx + 0.8, -ry * 0.45], lash, 2.5 if female else 2.1)
			if female:
				draw_line(Vector2(rx + 0.5, -ry * 0.45), Vector2(rx + 2.8, -ry * 0.85), lash, 1.7, true)

func _draw_overhead() -> void:
	_use(_head)
	if charmed:
		for i in range(2):
			var ph := fmod(_t * 0.55 + i * 0.5 + _seed, 1.0)
			var at := Vector2(20.0 - i * 38.0, -44.0 - ph * 26.0)
			var col := Color(heart_color.lightened(0.1), sin(ph * PI))
			heart(at, 5.0 + ph * 2.0, col, 0.0, sin(_t * 3.0 + i) * 0.2)
	if motion == "stun":
		for i in range(3):
			var a := _t * 5.0 + TAU * i / 3.0
			sparkle(Vector2(cos(a) * 26.0, -42.0 + sin(a) * 6.0), 5.5, Color("ffd65c"), a)
