extends Control
## Player level (with XP ring), coins and diamonds pills that count up when the save changes.
## A level-up pops a celebration card under the bar.

const Kit := preload("res://scripts/art/soft_draw.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")

var _coins: float = 0.0
var _gems: float = 0.0
var _xp: float = 0.0
var _kick: float = 0.0
var _level_kick: float = 0.0
var _banner: String = ""
var _banner_age: float = 99.0

func _ready() -> void:
	custom_minimum_size = Vector2(380, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins = Profile.coins
	_gems = Profile.gems
	_xp = float(Profile.xp) / Profile.xp_needed()
	Profile.changed.connect(func() -> void: _kick = 0.3)
	Profile.leveled_up.connect(_on_level_up)

func _on_level_up(level: int, coins: int, gems: int) -> void:
	_level_kick = 0.6
	_banner = "Lên cấp %d!  +%d xu  +%d kim cương" % [level, coins, gems]
	_banner_age = 0.0
	AudioManager.play_sfx("beauty")

func _process(delta: float) -> void:
	_coins = move_toward(_coins, Profile.coins, maxf(4.0, absf(Profile.coins - _coins) * 6.0) * delta)
	_gems = move_toward(_gems, Profile.gems, maxf(2.0, absf(Profile.gems - _gems) * 6.0) * delta)
	_xp = lerpf(_xp, float(Profile.xp) / Profile.xp_needed(), 1.0 - exp(-6.0 * delta))
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-8.0 * delta))
	_level_kick = lerpf(_level_kick, 0.0, 1.0 - exp(-5.0 * delta))
	_banner_age += delta
	queue_redraw()

func _pill(r: Rect2) -> void:
	draw_colored_polygon(Kit.rrect_pts(Rect2(r.position + Vector2(0, 3), r.size), 20), Color(0.45, 0.16, 0.35, 0.14))
	draw_colored_polygon(Kit.rrect_pts(r, 20), Color(1, 0.985, 0.975, 0.95))

func _draw() -> void:
	var font := get_theme_default_font()
	# Level badge with an XP ring.
	var lr := Rect2(0, 0, 118, 40)
	_pill(lr)
	var c := Vector2(20, 20)
	draw_arc(c, 13.0, 0.0, TAU, 32, Color("f6dde6"), 4.0, true)
	draw_arc(c, 13.0, -PI / 2, -PI / 2 + TAU * clampf(_xp, 0.0, 1.0), 32, Color("ff5f8f"), 4.0, true)
	draw_string(font, c + Vector2(-12, 5), str(Profile.player_level), HORIZONTAL_ALIGNMENT_CENTER, 24, int(13 * (1.0 + _level_kick)), Color("ff4f82"))
	draw_string(font, Vector2(40, 18), "Cấp %d" % Profile.player_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6b3558"))
	draw_string(font, Vector2(40, 32), "%d/%d XP" % [Profile.xp, Profile.xp_needed()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b58aa3"))
	for i in range(2):
		var r := Rect2(128 + i * 128, 0, 120, 40)
		_pill(r)
		var icon_at := r.position + Vector2(22, 20)
		if i == 0:
			ItemIcon.draw_coin(self, icon_at, 11.0 * (1.0 + _kick))
		else:
			ItemIcon.draw_gem(self, icon_at, 11.0 * (1.0 + _kick))
		draw_string(font, r.position + Vector2(40, 27), str(int(round(_coins if i == 0 else _gems))), HORIZONTAL_ALIGNMENT_LEFT, 74, 18, Color("6b3558"))
	if _banner_age < 2.6:
		var a := clampf(minf(_banner_age * 5.0, (2.6 - _banner_age) * 3.0), 0.0, 1.0)
		var s := 1.0 + 0.25 * exp(-_banner_age * 8.0)
		draw_set_transform(Vector2(190, 66), 0.0, Vector2.ONE * s)
		draw_colored_polygon(Kit.rrect_pts(Rect2(-190, -16, 380, 34), 17), Color(1.0, 0.36, 0.56, 0.95 * a))
		draw_string(font, Vector2(-190, 6), _banner, HORIZONTAL_ALIGNMENT_CENTER, 380, 14, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)
