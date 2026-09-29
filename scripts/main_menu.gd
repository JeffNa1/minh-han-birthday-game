extends Control
## Title screen: the courtyard, Minh Hân with a few already-smitten Nam Anh floating behind her.

const Fx := preload("res://scripts/vfx/fx.gd")

@onready var start_btn: Button = $MenuBox/StartBtn
@onready var guide_btn: Button = $MenuBox/GuideBtn
@onready var closet_btn: Button = $MenuBox/ClosetBtn
@onready var quit_btn: Button = $MenuBox/QuitBtn
@onready var guide_panel: PanelContainer = $GuidePanel
@onready var close_guide_btn: Button = $GuidePanel/Box/CloseGuideBtn
@onready var title: Control = $TitleBox
@onready var player_rig: Node2D = $PlayerRig

var _t: float = 0.0
var _floaters: Array = []

func _ready() -> void:
	guide_panel.visible = false
	start_btn.pressed.connect(_on_start_pressed)
	guide_btn.pressed.connect(_on_guide_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	closet_btn.pressed.connect(func() -> void: Transition.go("res://scenes/closet.tscn"))
	start_btn.text = "Vào lễ hội · Màn %d" % (mini(Profile.best_level, 9) + 1)
	close_guide_btn.pressed.connect(_on_close_guide_pressed)
	for b: Button in [start_btn, closet_btn, guide_btn, quit_btn, close_guide_btn]:
		b.pivot_offset = b.size / 2
		b.mouse_entered.connect(_hover.bind(b, 1.07))
		b.mouse_exited.connect(_hover.bind(b, 1.0))
		b.resized.connect(func() -> void: b.pivot_offset = b.size / 2)
	player_rig.set_facing(1.0)
	Profile.dress(player_rig)
	if Profile.equipped["pet"] != "none":
		var pet: Node2D = preload("res://scripts/entities/pet.gd").new()
		pet.kind = Profile.equipped["pet"]
		pet.position = player_rig.position + Vector2(62, -2)
		pet.scale = Vector2.ONE * 1.3
		add_child(pet)
	for id: String in ["polo", "pink_hoodie", "ghtk"]:
		_floaters.append(get_node("Floaters/" + id))
	for i in range(_floaters.size()):
		var r: Node2D = _floaters[i]
		r.set_outfit(r.name)
		r.set_charmed(true)
		r.set_motion("float")
		r.set_facing(1.0)
	# Entrance: title drops in, buttons slide up.
	title.pivot_offset = title.size / 2
	title.scale = Vector2.ONE * 0.6
	title.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "scale", Vector2.ONE, 0.6)
	tw.tween_property(title, "modulate:a", 1.0, 0.3)
	var box: Control = $MenuBox
	var home := box.position
	box.position.y += 60
	box.modulate.a = 0.0
	tw.tween_property(box, "position", home, 0.55).set_delay(0.2)
	tw.tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	AudioManager.play_bgm()

func _process(delta: float) -> void:
	_t += delta
	title.rotation = sin(_t * 1.3) * 0.015
	for i in range(_floaters.size()):
		var r: Node2D = _floaters[i]
		r.float_height = 36.0 + i * 16.0 + sin(_t * 2.0 + i * 1.7) * 7.0
	player_rig.look_goal = sin(_t * 0.7) * 0.5 - 0.4

func _hover(b: Button, s: float) -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "scale", Vector2.ONE * s, 0.18)
	if s > 1.0:
		AudioManager.play_sfx("click")

func _on_start_pressed() -> void:
	AudioManager.play_sfx("pop")
	Fx.hearts(start_btn.global_position + start_btn.size / 2, 16)
	GameManager.new_game()
	Transition.go("res://scenes/game_world.tscn")

func _on_guide_pressed() -> void:
	AudioManager.play_sfx("click")
	guide_panel.visible = true
	guide_panel.pivot_offset = guide_panel.size / 2
	guide_panel.scale = Vector2.ONE * 0.8
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(guide_panel, "scale", Vector2.ONE, 0.3)

func _on_close_guide_pressed() -> void:
	AudioManager.play_sfx("click")
	guide_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()
