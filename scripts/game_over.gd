extends Control
## Results: Minh Hân with every boy she won floating behind her, and a card that counts up the score.

const Fx := preload("res://scripts/vfx/fx.gd")
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const RIG := preload("res://scripts/entities/character_rig.gd")

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var desc_label: Label = $Panel/VBoxContainer/DescLabel
@onready var rank_label: Label = $Panel/VBoxContainer/RankLabel
@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var restart_btn: Button = $Panel/VBoxContainer/HBoxContainer/RestartBtn
@onready var menu_btn: Button = $Panel/VBoxContainer/HBoxContainer/MenuBtn
@onready var panel: Control = $Panel

var _t: float = 0.0
var _floaters: Array = []
var _shown_score: float = 0.0

func _ready() -> void:
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	for b: Button in [restart_btn, menu_btn]:
		b.mouse_entered.connect(_hover.bind(b, 1.07))
		b.mouse_exited.connect(_hover.bind(b, 1.0))
	_display_ending()
	_spawn_floaters()
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2.ONE * 0.7
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.55).set_delay(0.25)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3).set_delay(0.25)
	if GameManager.get_ending() != "bad":
		get_tree().create_timer(0.6).timeout.connect(func() -> void: Fx.hearts(Vector2(300, 330), 30, Color("ff5f8f"), 1.4))

func _spawn_floaters() -> void:
	var ids: Array = Wardrobe.ids_for("nam_anh")
	var count := mini(GameManager.total_charmed, 7)
	for i in range(count):
		var r: Node2D = RIG.new()
		r.character = "nam_anh"
		r.position = Vector2(220 - i * 32 - (i % 2) * 10, 470 + (i % 2) * 18)
		r.scale = Vector2.ONE * 0.9
		$Floaters.add_child(r)
		r.set_outfit(ids[i % ids.size()])
		r.set_charmed(true)
		r.set_motion("float")
		_floaters.append(r)

func _process(delta: float) -> void:
	_t += delta
	for i in range(_floaters.size()):
		_floaters[i].float_height = 40.0 + (i % 3) * 22.0 + sin(_t * 2.1 + i * 1.3) * 7.0
	_shown_score = move_toward(_shown_score, GameManager.score, maxf(1.0, GameManager.score * 1.2) * delta)
	stats_label.text = "♥ %d chàng   ·   %d điểm" % [GameManager.total_charmed, int(_shown_score)]

func _display_ending() -> void:
	var ending: String = GameManager.get_ending()
	var rig: Node2D = $PlayerRig
	Profile.dress(rig)
	if ending == "bad":
		title_label.text = "Hôm nay hơi ế…"
		rank_label.text = "Tập sự tình trường"
		desc_label.text = "Lễ hội tàn mà mới đổ được vài chàng. Không sao, sinh nhật vẫn là của Minh Hân — thử lại nhé!"
		rig.set_motion("stun")
	elif ending == "normal":
		title_label.text = "Được rước kiệu hoa!"
		rank_label.text = "Cao thủ thả thính"
		desc_label.text = "Cả dàn Nam Anh mê mẩn, khiêng kiệu hoa rước Minh Hân đi ngắm pháo hoa."
		rig.set_motion("beam")
	else:
		title_label.text = "Nữ hoàng lễ hội!"
		rank_label.text = "Đệ nhất sát thủ tình trường"
		desc_label.text = "Toàn bộ Nam Anh của lễ hội đều thuộc về Minh Hân. Chúc mừng sinh nhật, nữ hoàng!"
		rig.set_motion("beam")

func _hover(b: Button, s: float) -> void:
	b.pivot_offset = b.size / 2
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "scale", Vector2.ONE * s, 0.18)

func _on_restart_pressed() -> void:
	AudioManager.play_sfx("click")
	GameManager.new_game()
	Transition.go("res://scenes/game_world.tscn")

func _on_menu_pressed() -> void:
	AudioManager.play_sfx("click")
	Transition.go("res://scenes/main_menu.tscn")
