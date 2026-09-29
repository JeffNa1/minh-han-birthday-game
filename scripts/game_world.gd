extends Node2D
## Runs a level: builds the three zones, places the cast for the current level, keeps the boy
## population topped up, moves Minh Hân (and her floating boys) through the staircases,
## and advances or ends the game when the love meter fills or empties.

const Zones := preload("res://scripts/world/zones.gd")
const ZoneScript := preload("res://scripts/world/zone.gd")
const Fx := preload("res://scripts/vfx/fx.gd")

const BOY_SCENE := preload("res://scenes/entities/boy.tscn")
const RIVAL_SCENE := preload("res://scenes/entities/rival_girl.tscn")
const MANAGER_SCENE := preload("res://scenes/entities/manager.tscn")

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD

var zones: Dictionary = {}
var zone: Node2D
var _exit_cooldown: float = 0.0
var _refill: float = 4.0
var _moving: bool = false

func _ready() -> void:
	randomize()
	for id: String in Zones.ORDER:
		var z: Node2D = ZoneScript.new()
		z.setup(id)
		add_child(z)
		move_child(z, 0)
		zones[id] = z
	camera.target = player
	GameManager.level_finished.connect(_on_level_finished)
	_start_level()

func _start_level() -> void:
	for z: Node2D in zones.values():
		z.clear_cast([player])
	GameManager.begin_level()
	var cfg: Dictionary = GameManager.config()
	for id: String in cfg["boys"]:
		for i in range(cfg["boys"][id]):
			spawn_boy(id, randf_range(120.0, zones[id].width - 160.0))
	for r: Array in cfg["rivals"]:
		_spawn(RIVAL_SCENE, r[1], r[0])
	for id: String in cfg["managers"]:
		_spawn(MANAGER_SCENE, id, "")
	_enter_zone("courtyard", 320.0, 420.0)
	hud.show_level_intro(GameManager.level, cfg["title"])
	await get_tree().create_timer(2.2).timeout
	if is_inside_tree():
		GameManager.start_play()

func _spawn(scene: PackedScene, zone_id: String, character: String) -> Node2D:
	var z: Node2D = zones[zone_id]
	var n: Node2D = scene.instantiate()
	if character != "":
		n.get_node("Rig").character = character
	var x := randf_range(200.0, z.width - 200.0)
	# Keep newcomers off Minh Hân's arrival spot.
	if zone_id == "courtyard" and absf(x - 320.0) < 260.0:
		x += 520.0
	n.position = Vector2(x, randf_range(Zones.GROUND_TOP, Zones.GROUND_BOTTOM))
	n.bounds = Vector2(40.0, z.width - 40.0)
	z.entities.add_child(n)
	return n

func spawn_boy(zone_id: String, x: float) -> Node2D:
	var z: Node2D = zones[zone_id]
	var b: Node2D = BOY_SCENE.instantiate()
	var roll := randf()
	var t3: float = GameManager.config()["tier3"]
	b.tier = 3 if roll < t3 else (2 if roll < t3 + 0.3 else 1)
	b.position = Vector2(x, randf_range(Zones.GROUND_TOP, Zones.GROUND_BOTTOM))
	b.bounds = Vector2(40.0, z.width - 40.0)
	z.entities.add_child(b)
	return b

func _physics_process(delta: float) -> void:
	_exit_cooldown = maxf(0.0, _exit_cooldown - delta)
	if not GameManager.game_active or _moving:
		return
	for i in range(zone.data["exits"].size()):
		var exit: Dictionary = zone.data["exits"][i]
		var d := absf(player.global_position.x - exit["x"])
		zone.signs[i].near = clampf(1.0 - (d - 40.0) / 160.0, 0.0, 1.0)
		if d < 40.0 and _exit_cooldown <= 0.0 and player.state in [player.State.WALK, player.State.IDLE]:
			_take_stairs(exit)
			return
	_refill -= delta
	if _refill <= 0.0:
		_refill = 5.0
		_top_up_boys()

func _top_up_boys() -> void:
	var cfg: Dictionary = GameManager.config()
	for id: String in cfg["boys"]:
		var free := 0
		for n: Node in zones[id].entities.get_children():
			if n.is_in_group("boys") and n.lover == null:
				free += 1
		if free < cfg["boys"][id]:
			var z: Node2D = zones[id]
			# Newcomers stroll in from whichever end is off-screen.
			var x: float = 60.0 if player.global_position.x > z.width / 2.0 or zone != z else z.width - 60.0
			spawn_boy(id, x)

func _take_stairs(exit: Dictionary) -> void:
	_moving = true
	player.set_beaming(false)
	AudioManager.play_sfx("click")
	await Transition.swap(func() -> void: _enter_zone(exit["to"], exit["arrive_x"], player.global_position.y))
	_exit_cooldown = 0.8
	_moving = false

func _enter_zone(id: String, x: float, y: float) -> void:
	if zone != null:
		zone.set_active(false)
	zone = zones[id]
	zone.set_active(true)
	var followers: Array = GameManager.charmed_boys_chain.filter(func(b: Node2D) -> bool: return is_instance_valid(b))
	for n: Node2D in [player] + followers:
		if n.get_parent() != zone.entities:
			n.reparent(zone.entities)
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	player.bounds = Vector2(30.0, zone.width - 30.0)
	player.pointer_screen = player.get_global_transform_with_canvas().origin
	for i in range(followers.size()):
		var b: Node2D = followers[i]
		b.bounds = player.bounds
		b.global_position = player.global_position + Vector2(-player.rig.facing * (50.0 + i * 40.0), 0)
	camera.set_zone(zone.width)
	hud.show_zone(zone.data)

## A won level pays coins and leads to the gift boxes; losing (or winning the last level) ends the run.
func _on_level_finished(won: bool, reason: String) -> void:
	player.set_beaming(false)
	var final: bool = GameManager.is_final_level()
	GameManager.last_reward = 0
	if won:
		GameManager.last_reward = 40 + GameManager.level * 15 + GameManager.charmed_count * 5
		Profile.add_coins(GameManager.last_reward)
		Profile.add_xp(60 + GameManager.level * 10)
		AudioManager.play_sfx("beauty")
	hud.show_level_result(won, reason, final)
	await get_tree().create_timer(2.6).timeout
	if not is_inside_tree():
		return
	if won and not final:
		GameManager.level += 1
		Profile.reach_level(GameManager.level)
		Transition.go("res://scenes/gift.tscn")
	else:
		GameManager.won_game = won
		GameManager.end_game()
