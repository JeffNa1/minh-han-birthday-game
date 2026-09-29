extends CharacterBody2D
## A Nam Anh strolling around his zone. Whoever charms him becomes his `lover`:
## Minh Hân's boys float in a trail behind her, a rival's boys walk behind the rival.

const Fx := preload("res://scripts/vfx/fx.gd")
const ShakeCamera := preload("res://scripts/vfx/shake_camera.gd")
const Wardrobe := preload("res://scripts/art/wardrobe.gd")
const Zones := preload("res://scripts/world/zones.gd")
const RIVAL_HEART := Color("b77dff")

@export var tier: int = 1

@onready var rig: Node2D = $Rig
@onready var gauge: Node2D = $Gauge

var lover: Node2D = null
var is_charmed: bool:
	get:
		return lover != null
var charm_progress: float = 0.0
var charm_grace: float = 0.0
var bounds := Vector2(40, 920)
var walk_speed: float = 42.0
var points: int = 100
var charm_resistance: float = 1.0
var evasive: bool = false
var _goal: Vector2
var _pause: float = 0.0
var _t: float = 0.0
var _sparkle_timer: float = 0.0

func _ready() -> void:
	if tier == 2:
		points = 300
		charm_resistance = 1.4
	elif tier == 3:
		points = 800
		charm_resistance = 2.0
	charm_resistance *= GameManager.config()["boy_resist"]
	evasive = GameManager.config()["boy_evasive"]
	gauge.tier = tier
	rig.set_outfit(_pick_outfit())
	var start := 1.0 if randf() > 0.5 else -1.0
	rig.set_facing(start)
	rig.turn = start
	_goal = global_position
	_pause = randf_range(0.2, 1.5)

func _pick_outfit() -> String:
	var taken: Array = []
	for other: Node in get_tree().get_nodes_in_group("boys"):
		if other != self and other.has_node("Rig"):
			taken.append(other.get_node("Rig").outfit)
	var choices: Array = Wardrobe.ids_for("nam_anh").filter(func(id: String) -> bool: return id not in taken)
	if choices.is_empty():
		choices = Wardrobe.ids_for("nam_anh")
	return choices.pick_random()

func is_player_boy() -> bool:
	return lover != null and lover.is_in_group("player")

func _physics_process(delta: float) -> void:
	_t += delta
	if is_instance_valid(lover):
		if is_player_boy():
			_float_behind(delta)
		else:
			_walk_behind(delta)
		return
	elif lover != null:
		set_lover(null)
	if not GameManager.game_active:
		rig.set_motion("idle")
		return
	charm_grace = maxf(0.0, charm_grace - delta)
	if charm_grace > 0.0:
		# Flustered while a beam is on him: frozen early on, still drifting away on later levels.
		if evasive:
			_wander(delta, 0.5)
		else:
			rig.set_motion("idle")
		rig.look_goal = 0.0
		return
	charm_progress = maxf(0.0, charm_progress - delta * (18.0 + GameManager.level * 4.0))
	_sync_charm()
	_wander(delta)
	if tier == 3:
		_sparkle_timer -= delta
		if _sparkle_timer <= 0.0:
			_sparkle_timer = 0.5
			Fx.sparkles(global_position + Vector2(randf_range(-20, 20), randf_range(-50, 10)), 1, Color("ffe07a"), 6.0)

func _wander(delta: float, pace: float = 1.0) -> void:
	if _pause > 0.0:
		_pause -= delta
		rig.set_motion("idle")
		rig.look_goal = sin(_t * 0.9) * 0.8 - 0.3
		if _pause <= 0.0:
			_goal = Vector2(clampf(global_position.x + randf_range(-320, 320), bounds.x, bounds.y), randf_range(Zones.GROUND_TOP, Zones.GROUND_BOTTOM))
		return
	var to := _goal - global_position
	if to.length() < 6.0:
		_pause = randf_range(0.8, 2.6)
		return
	velocity = to.normalized() * walk_speed * pace
	move_and_slide()
	rig.set_facing(velocity.x)
	rig.set_motion("walk", walk_speed * pace)
	rig.look_goal = 0.0

func _float_behind(delta: float) -> void:
	var idx: int = maxi(0, GameManager.charmed_boys_chain.find(self))
	var side: float = -lover.rig.facing
	# A loose ribbon: each boy trails further back and higher, bobbing out of phase.
	var goal := lover.global_position + Vector2(side * (58.0 + idx * 50.0), -4.0 - (idx % 2) * 8.0)
	goal.x = clampf(goal.x, bounds.x, bounds.y)
	var rate := maxf(1.8, 5.5 - idx * 0.5)
	global_position = global_position.lerp(goal, 1.0 - exp(-rate * delta))
	var lift := 34.0 + (idx % 3) * 22.0 + sin(_t * 2.2 + idx * 1.1) * 7.0
	rig.float_height = lerpf(rig.float_height, lift, 1.0 - exp(-4.0 * delta))
	rig.set_facing(lover.global_position.x - global_position.x)
	rig.set_motion("float")
	rig.look_goal = 0.0

func _walk_behind(delta: float) -> void:
	var idx: int = maxi(0, lover.followers.find(self))
	var goal := lover.global_position + Vector2(-lover.rig.facing * (46.0 + idx * 38.0), 6.0 + (idx % 2) * 10.0)
	goal.x = clampf(goal.x, bounds.x, bounds.y)
	var to := goal - global_position
	rig.float_height = lerpf(rig.float_height, 0.0, 1.0 - exp(-6.0 * delta))
	if to.length() > 8.0:
		velocity = to.normalized() * minf(150.0, to.length() * 3.0)
		move_and_slide()
		rig.set_facing(velocity.x)
		rig.set_motion("walk", velocity.length())
	else:
		rig.set_facing(lover.global_position.x - global_position.x)
		rig.set_motion("idle")

## Hand the boy to Minh Hân (the player), a rival, or nobody.
func set_lover(next: Node2D) -> void:
	if lover == next:
		return
	var previous := lover
	if is_instance_valid(previous) and not previous.is_in_group("player"):
		previous.followers.erase(self)
	lover = next
	charm_progress = 0.0
	charm_grace = 0.0
	gauge.set_value(0.0)
	rig.charm_level = 0.0
	rig.set_charmed(next != null)
	z_index = -1 if is_player_boy() else 0
	if next == null:
		return
	rig.heart_color = rig.PINK_HEART if is_player_boy() else RIVAL_HEART
	if not next.is_in_group("player"):
		next.followers.append(self)
		if is_instance_valid(previous) and previous.is_in_group("player"):
			GameManager.lose_follower(self)
			Fx.hearts(get_eye_position(), 12, RIVAL_HEART)
			Fx.text(global_position + Vector2(0, -80), "Bị cướp mất!", Color("8f5bd6"), 20)
		else:
			Fx.hearts(get_eye_position(), 8, RIVAL_HEART, 0.7)

func get_eye_position() -> Vector2:
	return rig.eye.global_position

func apply_charm(amount: float) -> bool:
	if is_player_boy():
		return false
	charm_grace = 0.35
	var resistance := charm_resistance * (1.5 if lover != null else 1.0)
	charm_progress = minf(100.0, charm_progress + amount / resistance)
	_sync_charm()
	if charm_progress >= 100.0:
		become_charmed()
		return true
	return false

## Frozen while a rival beams him, too.
func hold_still() -> void:
	charm_grace = 0.35

func _sync_charm() -> void:
	gauge.set_value(charm_progress)
	rig.charm_level = charm_progress / 100.0

func become_charmed() -> void:
	if is_player_boy():
		return
	var stolen := lover != null
	set_lover(get_tree().get_first_node_in_group("player") as Node2D)
	var burst_at := get_eye_position()
	var colors := [Color("ff5f8f"), Color("b77dff"), Color("ffb938")]
	var col: Color = colors[clampi(tier - 1, 0, 2)]
	Fx.hearts(burst_at, 16 + tier * 4, col, 1.0 + tier * 0.15)
	Fx.sparkles(burst_at, 10, Color("fff4c2"), 40.0)
	if stolen:
		Fx.text(burst_at + Vector2(0, -44), "Giành lại!", Color("ff4f82"), 22)
	ShakeCamera.shake(0.35 + tier * 0.1, 0.03)
	GameManager.hitstop(0.07)
	GameManager.register_charmed_boy(self, points)
	Fx.text(burst_at + Vector2(0, -20), "+%d" % (points * GameManager.combo), col, 24 + tier * 3)

## Scared off by the manager: he drops out of Minh Hân's trail and hurries away.
func scare_off() -> void:
	GameManager.lose_follower(self)
	set_lover(null)
	rig.float_height = 0.0
	Fx.text(global_position + Vector2(0, -80), "Sợ quá!", Color("7a5cff"), 20)
	_pause = 0.0
	_goal = Vector2(bounds.x if global_position.x > (bounds.x + bounds.y) / 2.0 else bounds.y, global_position.y)

func stop_charming() -> void:
	charm_grace = minf(charm_grace, 0.35)
