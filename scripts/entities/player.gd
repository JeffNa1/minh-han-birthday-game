extends CharacterBody2D
## Minh Hân: walks toward the pointer across the scrolling zone, beams love from her eye
## while the mouse is held on a boy, and changes outfits on 1–5.

signal outfit_changed(outfit_name: String)

const Fx := preload("res://scripts/vfx/fx.gd")
const ShakeCamera := preload("res://scripts/vfx/shake_camera.gd")
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const Zones := preload("res://scripts/world/zones.gd")
const PET := preload("res://scripts/entities/pet.gd")

enum State { IDLE, WALK, BEAMING, CLASHING, STUNNED }

@export var move_speed: float = 240.0

@onready var rig: Node2D = $Rig
@onready var beam: Node2D = $LoveBeam
@onready var stun_timer: Timer = $StunTimer

var state: State = State.IDLE
var current_target: Node2D = null
var is_mouse_down: bool = false
var charm_rate: float = 48.0
var pointer_world: Vector2
var pointer_screen: Vector2
var bounds := Vector2(30, 930)
var _lost_aim: float = 0.0
var pet: Node2D = null

func _ready() -> void:
	pointer_world = global_position
	pointer_screen = get_global_transform_with_canvas().origin
	stun_timer.timeout.connect(_on_stun_timeout)
	rig.stepped.connect(_on_step)
	Profile.dress(rig)
	beam.set_style(Profile.equipped["beam"])
	if Profile.equipped["pet"] != "none":
		pet = PET.new()
		pet.kind = Profile.equipped["pet"]
		pet.owner_body = self
		add_child(pet)
	GameManager.boy_charmed.connect(_on_boy_charmed)
	GameManager.clash_requested.connect(_on_clash_requested)
	GameManager.clash_resolved.connect(_on_clash_resolved)

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_screen = event.position
		pointer_world = get_canvas_transform().affine_inverse() * pointer_screen
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# Releases must reach the player even when a UI control consumes them.
		is_mouse_down = false
		set_beaming(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		var outfits: Array = Profile.owned["outfit"]
		if index >= 0 and index < mini(outfits.size(), 9):
			change_outfit(outfits[index])
	if not GameManager.game_active or state in [State.STUNNED, State.CLASHING]:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_mouse_down = true
		current_target = find_boy_at(pointer_world)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_node_ready():
		is_mouse_down = false
		set_beaming(false)

func change_outfit(outfit_name: String) -> void:
	if outfit_name == rig.outfit or not Profile.owns("outfit", outfit_name):
		return
	Profile.equip("outfit", outfit_name)
	rig.set_outfit(outfit_name)
	if rig.outfit == outfit_name:
		var chest: Vector2 = global_position + Vector2(0, 10)
		Fx.sparkles(chest, 14, Color("fff4c2"), 48.0)
		Fx.hearts(chest, 6, Color("ff8fb0"), 0.6)
		Fx.ring(chest, Color("ffffff"), 55.0)
		AudioManager.play_sfx("pop")
	outfit_changed.emit(rig.outfit)

func _physics_process(delta: float) -> void:
	# The camera scrolls under a still mouse, so the pointed-at world spot keeps moving too.
	pointer_world = get_canvas_transform().affine_inverse() * pointer_screen
	if not GameManager.game_active:
		set_beaming(false)
		velocity = Vector2.ZERO
		if state != State.STUNNED:
			rig.set_motion("idle")
		return
	if state in [State.STUNNED, State.CLASHING]:
		velocity = Vector2.ZERO
		rig.set_motion("stun" if state == State.STUNNED else "beam")
		return
	if is_mouse_down:
		if not is_instance_valid(current_target) or current_target.is_player_boy():
			current_target = find_boy_at(pointer_world)
		if is_instance_valid(current_target):
			_beam_at(current_target, delta)
			return
	if beam.is_active:
		set_beaming(false)
	var goal := Vector2(clampf(pointer_world.x, bounds.x, bounds.y), clampf(pointer_world.y - 40.0, Zones.GROUND_TOP, Zones.GROUND_BOTTOM))
	var to := goal - global_position
	var desired := Vector2.ZERO
	if to.length() > 10.0:
		desired = to.normalized() * minf(move_speed, to.length() * 5.0)
	velocity = velocity.move_toward(desired, 1500.0 * delta)
	if velocity.length() > 14.0:
		state = State.WALK
		if absf(velocity.x) > 8.0:
			rig.set_facing(velocity.x)
		rig.set_motion("walk", velocity.length())
		rig.look_goal = 0.0
	else:
		state = State.IDLE
		rig.set_motion("idle")
		# Idle glances follow the pointer, even behind her, without turning the body.
		rig.look_goal = clampf((pointer_world.x - global_position.x) / 180.0, -1.0, 1.0) * rig.facing * 0.9 - 0.3
	move_and_slide()
	global_position.x = clampf(global_position.x, bounds.x, bounds.y)

func _beam_at(boy: Node2D, delta: float) -> void:
	# The pointer has to stay on him; boys on later levels keep walking, so track them.
	if _hit_rect(boy).has_point(pointer_world):
		_lost_aim = 0.0
	else:
		_lost_aim += delta
		if _lost_aim > 0.3:
			set_beaming(false)
			current_target = null
			return
	state = State.BEAMING
	velocity = Vector2.ZERO
	rig.set_facing(boy.global_position.x - global_position.x)
	rig.set_motion("beam")
	rig.look_goal = 0.0
	beam.from_marker = rig.eye
	beam.to_marker = boy.rig.eye
	if not beam.is_active:
		beam.activate(rig.eye.global_position, boy.get_eye_position())
		AudioManager.set_beam_loop(true)
		ShakeCamera.shake(0.12)
	if boy.apply_charm(charm_rate * delta):
		set_beaming(false)

func _on_boy_charmed(_boy: Node2D, _points: int) -> void:
	if is_instance_valid(pet):
		pet.cheer()

func _on_step(_at: Vector2) -> void:
	if state == State.WALK and velocity.length() > 120.0:
		Fx.dust(global_position + Vector2(0, 54), rig.facing)

## Boys in this zone under the pointer that Minh Hân does not already have.
func find_boy_at(point: Vector2) -> Node2D:
	var best: Node2D = null
	var nearest: float = INF
	for boy: Node in get_parent().get_children():
		if not boy.is_in_group("boys") or boy.is_player_boy():
			continue
		var area := _hit_rect(boy)
		var distance: float = point.distance_squared_to(boy.global_position)
		if area.has_point(point) and distance < nearest:
			nearest = distance
			best = boy
	return best

func _hit_rect(boy: Node2D) -> Rect2:
	return Rect2(boy.global_position + Vector2(-38, -80), Vector2(76, 145))

func set_beaming(active: bool) -> void:
	if active:
		return
	beam.deactivate()
	AudioManager.set_beam_loop(false)
	if is_instance_valid(current_target):
		current_target.stop_charming()
	current_target = null
	if state == State.BEAMING:
		state = State.IDLE
		rig.set_motion("idle")

func apply_stun(duration: float = 2.0) -> void:
	is_mouse_down = false
	set_beaming(false)
	state = State.STUNNED
	velocity = Vector2.ZERO
	rig.set_motion("stun")
	rig.pop(0.25)
	ShakeCamera.shake(0.6, 0.04)
	AudioManager.play_sfx("stun")
	stun_timer.start(duration)

func caught_by_manager() -> void:
	apply_stun(3.0)
	Fx.text(global_position + Vector2(0, -70), "Bị bắt quả tang!", Color("7a5cff"), 22)
	# One of her boys panics and runs off; with nobody following her it costs two hearts outright.
	var followers: Array = GameManager.charmed_boys_chain.filter(func(b: Node2D) -> bool: return is_instance_valid(b))
	GameManager.change_hearts(-1)
	if followers.is_empty():
		GameManager.change_hearts(-1)
	else:
		followers.back().scare_off()

func _on_stun_timeout() -> void:
	if state == State.STUNNED:
		state = State.IDLE
		rig.set_motion("idle")

func _on_clash_requested(_rival: Node2D, boy: Node2D) -> void:
	if current_target == boy or (is_instance_valid(boy) and boy.is_player_boy()):
		set_beaming(false)
		state = State.CLASHING
		if is_instance_valid(boy):
			rig.set_facing(boy.global_position.x - global_position.x)

func _on_clash_resolved(player_won: bool, boy: Node2D) -> void:
	if state != State.CLASHING:
		return
	state = State.IDLE
	if player_won:
		Profile.add_xp(8)
		if is_instance_valid(boy) and not boy.is_player_boy():
			boy.become_charmed()
		elif is_instance_valid(boy):
			Fx.hearts(boy.get_eye_position(), 10)
			Fx.text(boy.global_position + Vector2(0, -80), "Giữ được rồi!", Color("ff4f82"), 20)
	else:
		apply_stun(1.5)
