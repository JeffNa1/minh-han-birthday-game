extends Control
## Tug-of-war when the rival beams the same boy: click fast to push the heart to Minh Hân's side.

const Kit := preload("res://scripts/art/soft_draw.gd")
const ShakeCamera := preload("res://scripts/vfx/shake_camera.gd")

var current_val: float = 0.0 # -100 (rival) to +100 (player)
var pointer_x: float = 0.0
var is_active: bool = false
var current_boy: Node2D = null
var current_rival: Node2D = null
var rival_strength: float = 40.0 # Rival push rate per second
var _t: float = 0.0
var _kick: float = 0.0
var _appear: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	GameManager.clash_requested.connect(_on_clash_requested)

func _process(delta: float) -> void:
	_t += delta
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-12.0 * delta))
	_appear = minf(1.0, _appear + delta * 5.0)
	if not is_active:
		return
	current_val -= rival_strength * delta
	pointer_x = lerpf(pointer_x, (current_val / 100.0) * 150.0, 1.0 - exp(-20.0 * delta)) if delta > 0.0 else (current_val / 100.0) * 150.0
	queue_redraw()
	if current_val >= 100.0:
		_finish_clash(true)
	elif current_val <= -100.0:
		_finish_clash(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		current_val = min(105.0, current_val + 14.0)
		_kick = 0.35
		AudioManager.play_sfx("click")
		ShakeCamera.shake(0.08)

func _on_clash_requested(rival: Node2D, boy: Node2D) -> void:
	current_rival = rival
	current_boy = boy
	current_val = 0.0
	pointer_x = 0.0
	_appear = 0.0
	rival_strength = GameManager.config()["clash_push"]
	is_active = true
	visible = true
	AudioManager.play_sfx("clash")
	ShakeCamera.shake(0.4, 0.05)

func _finish_clash(player_won: bool) -> void:
	is_active = false
	visible = false
	GameManager.resolve_clash(player_won, current_boy)
	current_boy = null
	current_rival = null

func _draw() -> void:
	var e := 1.0 - pow(1.0 - _appear, 3.0)
	draw_rect(Rect2(0, 0, 960, 540), Color(0.3, 0.1, 0.25, 0.28 * e))
	var font := get_theme_default_font()
	var c := Vector2(480, 150)
	draw_set_transform(c, sin(_t * 40.0) * 0.01, Vector2.ONE * (0.7 + 0.3 * e))
	var card := Rect2(-230, -62, 460, 124)
	draw_colored_polygon(Kit.rrect_pts(Rect2(card.position + Vector2(0, 6), card.size), 28), Color(0.4, 0.1, 0.3, 0.2))
	draw_colored_polygon(Kit.rrect_pts(card, 28), Color(1, 0.98, 0.97, 0.97))
	draw_string_outline(font, Vector2(-230, -24), "TRANH GIÀNH!", HORIZONTAL_ALIGNMENT_CENTER, 460, 26, 8, Color.WHITE)
	draw_string(font, Vector2(-230, -24), "TRANH GIÀNH!", HORIZONTAL_ALIGNMENT_CENTER, 460, 26, Color("ff4f82"))
	var bar := Rect2(-160, 2, 320, 16)
	draw_colored_polygon(Kit.rrect_pts(Rect2(bar.position, Vector2(maxf(16.0, bar.size.x / 2 + pointer_x), bar.size.y)), 8), Color("b98cff"))
	draw_colored_polygon(Kit.rrect_pts(Rect2(bar.position + Vector2(bar.size.x / 2 + pointer_x, 0), Vector2(maxf(16.0, bar.size.x / 2 - pointer_x), bar.size.y)), 8), Color("ff7fa2"))
	draw_line(bar.position + Vector2(8, 4), bar.end - Vector2(8, 12), Color(1, 1, 1, 0.4), 2.0, true)
	var hp := Vector2(clampf(pointer_x, -150.0, 150.0), 10)
	var s := 17.0 * (1.0 + _kick)
	draw_colored_polygon(Kit.heart_pts(hp, s + 3.0), Color.WHITE)
	draw_colored_polygon(Kit.heart_pts(hp, s), Color("ff4f82"))
	draw_circle(hp + Vector2(-5, -5), 2.6, Color(1, 1, 1, 0.8), true, -1.0, true)
	draw_string(font, Vector2(-160, 36), "Đối thủ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8f5bd6"))
	draw_string(font, Vector2(60, 36), "Minh Hân", HORIZONTAL_ALIGNMENT_RIGHT, 100, 12, Color("ff4f82"))
	var a := 0.6 + 0.4 * sin(_t * 10.0)
	draw_string(font, Vector2(-230, 54), "BẤM CHUỘT LIÊN TỤC!", HORIZONTAL_ALIGNMENT_CENTER, 460, 15, Color(0.55, 0.27, 0.43, a))
	draw_set_transform(Vector2.ZERO)
